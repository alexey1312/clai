import Foundation

/// Core engine for clai - handles context gathering, prompt construction, and LLM interaction
final class ClaiEngine: Sendable {
    private let options: GlobalOptions
    private let providerManager: ProviderManager
    private let contextGatherer: ContextGatherer
    private let terminal: TerminalUI
    private let cache: ResponseCache?

    init(options: GlobalOptions) {
        // Disable stdout buffering for immediate output in non-TTY environments
        setbuf(stdout, nil)

        self.options = options
        providerManager = ProviderManager(preferredProvider: options.provider)
        contextGatherer = ContextGatherer()
        terminal = TerminalUI(verbose: options.verbose)

        // Initialize cache (optional, fails gracefully)
        cache = try? ResponseCache()
    }

    /// Explain a CLI command in plain language
    func explain(command: String) async throws {
        terminal.showProgress("Analyzing command...")

        let context = try await contextGatherer.gather(for: command)
        let prompt = PromptBuilder.buildExplainPrompt(command: command, context: context)

        let (response, wasStreamed) = try await generateResponse(
            prompt: prompt,
            cacheKey: makeCacheKey(command: command, mode: "explain")
        )
        if !wasStreamed {
            terminal.showResponse(response, format: options.json ? .json : .plain)
        }
    }

    /// Suggest commands for a natural language task
    func suggest(task: String) async throws {
        terminal.showProgress("Finding commands...")

        let prompt = PromptBuilder.buildSuggestPrompt(task: task)

        let (response, wasStreamed) = try await generateResponse(
            prompt: prompt,
            cacheKey: makeCacheKey(command: task, mode: "suggest")
        )
        if !wasStreamed {
            terminal.showResponse(response, format: options.json ? .json : .plain)
        }
    }

    /// Show practical examples for a command
    func examples(command: String) async throws {
        terminal.showProgress("Generating examples...")

        let context = try await contextGatherer.gather(for: command)
        let prompt = PromptBuilder.buildExamplesPrompt(command: command, context: context)

        let (response, wasStreamed) = try await generateResponse(
            prompt: prompt,
            cacheKey: makeCacheKey(command: command, mode: "examples")
        )
        if !wasStreamed {
            terminal.showResponse(response, format: options.json ? .json : .plain)
        }
    }

    /// Summarize a man page
    func summarizeMan(command: String) async throws {
        terminal.showProgress("Reading man page...")

        let manContent = try await contextGatherer.getManPage(for: command)
        let prompt = PromptBuilder.buildManSummaryPrompt(command: command, manContent: manContent)

        let (response, wasStreamed) = try await generateResponse(
            prompt: prompt,
            cacheKey: makeCacheKey(command: command, mode: "man")
        )
        if !wasStreamed {
            terminal.showResponse(response, format: options.json ? .json : .plain)
        }
    }

    private func makeCacheKey(command: String, mode: String) -> String? {
        guard !options.noCache, cache != nil else {
            return nil
        }
        let providerName = options.provider?.rawValue ?? "auto"
        return ResponseCache.generateKey(command: command, mode: mode, provider: providerName)
    }

    private func generateResponse(prompt: String, cacheKey: String?) async throws -> (String, Bool) {
        // Check cache first (if not disabled)
        if let cacheKey, let cache, let cached = try? cache.get(key: cacheKey) {
            if options.verbose {
                terminal.showInfo("Using cached response from \(cached.provider)")
            }
            return (cached.response, false)
        }

        let provider = try await providerManager.getAvailableProvider()

        if options.verbose {
            terminal.showInfo("Using provider: \(provider.name)")
        }

        var response: String
        let wasStreamed: Bool

        // Use streaming only if requested AND provider supports it
        let useStreaming = options.stream && provider.supportsStreaming

        if useStreaming {
            terminal.clearLine()
            let streamFilter = ThinkingTagStreamFilter()
            response = try await provider.generateStreaming(prompt: prompt) { chunk in
                let filtered = streamFilter.process(chunk)
                if !filtered.isEmpty {
                    self.terminal.appendStreamChunk(filtered)
                }
            }
            // Flush any remaining buffered content
            let remaining = streamFilter.flush()
            if !remaining.isEmpty {
                terminal.appendStreamChunk(remaining)
            }
            terminal.endStream()
            wasStreamed = true
        } else {
            terminal.clearLine()
            response = try await provider.generate(prompt: prompt)
            wasStreamed = false
        }

        // Strip any thinking tags from the final response
        response = Self.stripThinkingTags(response)

        // Validate response is not empty
        guard !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClaiError.emptyResponse(provider.name)
        }

        // Cache the response (if not disabled)
        if let cacheKey, let cache {
            try? cache.set(key: cacheKey, response: response, provider: provider.name)
        }

        return (response, wasStreamed)
    }

    /// Remove <think>...</think> tags from model output
    private static func stripThinkingTags(_ text: String) -> String {
        text.replacingOccurrences(
            of: "<think>[\\s\\S]*?</think>",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Filters <think>...</think> tags from streaming output
final class ThinkingTagStreamFilter: @unchecked Sendable {
    private var buffer = ""
    private var insideThinkTag = false

    /// Process a chunk and return the filtered output
    func process(_ chunk: String) -> String {
        buffer += chunk

        // If we're inside a think tag, look for the closing tag
        if insideThinkTag {
            if let endRange = buffer.range(of: "</think>") {
                // Found closing tag, discard everything up to and including it
                buffer = String(buffer[endRange.upperBound...])
                insideThinkTag = false
            } else {
                // Still inside, keep buffering
                return ""
            }
        }

        // Look for opening think tag
        if let startRange = buffer.range(of: "<think>") {
            let beforeTag = String(buffer[..<startRange.lowerBound])

            // Check if there's a closing tag too
            let afterStart = String(buffer[startRange.upperBound...])
            if let endRange = afterStart.range(of: "</think>") {
                // Complete tag found, remove it and continue
                buffer = String(afterStart[endRange.upperBound...])
                return beforeTag + process("") // Recursively process remaining buffer
            } else {
                // Opening tag but no closing tag yet
                buffer = String(buffer[startRange.lowerBound...])
                insideThinkTag = true
                return beforeTag
            }
        }

        // Check for partial opening tag at the end (e.g., "<thi")
        let tagStart = "<think>"
        for prefixLen in 1 ..< tagStart.count {
            let partial = String(tagStart.prefix(prefixLen))
            if buffer.hasSuffix(partial) {
                let output = String(buffer.dropLast(prefixLen))
                buffer = partial
                return output
            }
        }

        // No tags found, output everything
        let output = buffer
        buffer = ""
        return output
    }

    /// Flush any remaining buffered content
    func flush() -> String {
        let output = buffer
        buffer = ""
        insideThinkTag = false
        return output
    }
}
