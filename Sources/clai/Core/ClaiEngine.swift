import Foundation

/// Disable stdout buffering for immediate output in non-TTY environments
@inline(__always)
private func disableStdoutBuffering() {
    #if os(Linux)
    // On Linux, we use FileHandle.synchronize() for flushing instead of
    // manipulating stdout buffer directly to avoid Swift 6 concurrency warnings
    // The buffering behavior is acceptable since we flush explicitly
    #else
        setbuf(stdout, nil)
    #endif
}

/// Result of generating an LLM response
struct GenerationResult {
    let content: String
    let wasStreamed: Bool
    let providerName: String
}

/// Core engine for clai - handles context gathering, prompt construction, and LLM interaction
final class ClaiEngine: Sendable {
    private let options: GlobalOptions
    private let providerManager: ProviderManager
    private let contextGatherer: ContextGatherer
    private let terminal: TerminalUI
    private let cache: ResponseCache?

    /// Errors specific to ClaiEngine initialization
    enum InitError: Error, LocalizedError {
        case configurationError(Error)

        var errorDescription: String? {
            switch self {
            case let .configurationError(underlying):
                "Configuration error: \(underlying.localizedDescription)"
            }
        }
    }

    init(options: GlobalOptions) throws {
        // Disable stdout buffering for immediate output in non-TTY environments
        disableStdoutBuffering()

        self.options = options

        // Load configuration (throws on errors)
        let config: Config
        do {
            config = try Config.load()
        } catch {
            throw InitError.configurationError(error)
        }

        providerManager = ProviderManager(preferredProvider: options.provider, config: config)
        contextGatherer = ContextGatherer()
        terminal = TerminalUI(verbose: options.verbose)

        // Initialize cache (optional, fails gracefully)
        cache = try? ResponseCache()
    }

    /// Explain a CLI command in plain language
    func explain(command: String) async throws {
        do {
            let result = try await generateResponse(
                cacheKey: makeCacheKey(command: command, mode: "explain"),
                loadingMessage: "Generating explanation..."
            ) {
                let context = try await self.terminal.withSpinner("Analyzing command...") {
                    try await self.contextGatherer.gather(for: command)
                }

                // Smart fallback: If no documentation found, treat as natural language/topic request
                if context.isEmpty {
                    throw ClaiError.contextEmpty
                }

                return PromptBuilder.buildExplainPrompt(command: command, context: context)
            }

            if !result.wasStreamed {
                terminal.showResponse(result.content, format: options.json ? .json : .plain)
            }
            terminal.showProviderAttribution(result.providerName)

        } catch ClaiError.contextEmpty {
            if options.verbose {
                terminal.showInfo("No documentation found for '\(command)', falling back to suggest mode")
            }
            try await suggest(task: command)
        }
    }

    /// Suggest commands for a natural language task
    func suggest(task: String) async throws {
        let result = try await generateResponse(
            cacheKey: makeCacheKey(command: task, mode: "suggest"),
            loadingMessage: "Thinking..."
        ) {
            try await self.terminal.withSpinner("Finding commands...") {
                PromptBuilder.buildSuggestPrompt(task: task)
            }
        }

        if !result.wasStreamed {
            terminal.showResponse(result.content, format: options.json ? .json : .plain)
        }
        terminal.showProviderAttribution(result.providerName)
    }

    /// Show practical examples for a command
    func examples(command: String) async throws {
        let result = try await generateResponse(
            cacheKey: makeCacheKey(command: command, mode: "examples"),
            loadingMessage: "Creating examples..."
        ) {
            let context = try await self.terminal.withSpinner("Generating examples...") {
                try await self.contextGatherer.gather(for: command)
            }
            return PromptBuilder.buildExamplesPrompt(command: command, context: context)
        }

        if !result.wasStreamed {
            terminal.showResponse(result.content, format: options.json ? .json : .plain)
        }
        terminal.showProviderAttribution(result.providerName)
    }

    /// Summarize a man page
    func summarizeMan(command: String) async throws {
        let result = try await generateResponse(
            cacheKey: makeCacheKey(command: command, mode: "man"),
            loadingMessage: "Summarizing..."
        ) {
            let manContent = try await self.terminal.withSpinner("Reading man page...") {
                try await self.contextGatherer.getManPage(for: command)
            }
            return PromptBuilder.buildManSummaryPrompt(command: command, manContent: manContent)
        }

        if !result.wasStreamed {
            terminal.showResponse(result.content, format: options.json ? .json : .plain)
        }
        terminal.showProviderAttribution(result.providerName)
    }

    /// Process a chat message and return the response
    /// - Parameters:
    ///   - message: The user's message
    ///   - history: Previous messages in the conversation
    /// - Returns: The assistant's response and provider name
    func chat(message: String, history: [ChatMessage]) async throws -> (String, String) {
        // Chat doesn't use caching - each conversation is unique
        let result = try await generateResponse(
            cacheKey: nil,
            loadingMessage: "Thinking..."
        ) {
            PromptBuilder.buildChatPrompt(message: message, history: history)
        }

        return (result.content, result.providerName)
    }

    private func makeCacheKey(command: String, mode: String) -> String? {
        guard !options.noCache, cache != nil else {
            return nil
        }
        let providerName = options.provider?.rawValue ?? "auto"
        return ResponseCache.generateKey(command: command, mode: mode, provider: providerName)
    }

    private func generateResponse(
        cacheKey: String?,
        loadingMessage: String = "Generating response...",
        promptProvider: @Sendable () async throws -> String
    ) async throws -> GenerationResult {
        // Check cache first (if not disabled)
        if let cacheKey, let cache, let cached = try? cache.get(key: cacheKey) {
            if options.verbose {
                terminal.showInfo("Using cached response from \(cached.provider)")
            }
            return GenerationResult(content: cached.response, wasStreamed: false, providerName: cached.provider)
        }

        // Generate prompt and start availability checks concurrently
        // Note: candidateProvidersStream() launches background tasks immediately
        let candidatesStream = providerManager.candidateProvidersStream()

        let prompt = try await promptProvider()

        // Instantiate provider after concurrent phases are done
        // This avoids UI conflicts if instantiation triggers a download (which outputs to terminal)
        var selectedProvider: LLMProvider?
        for await type in candidatesStream {
            if let provider = try await providerManager.instantiateProvider(type) {
                selectedProvider = provider
                break
            }
        }

        guard let provider = selectedProvider else {
            if let preferred = options.provider {
                throw ClaiError.providerUnavailable(preferred.rawValue)
            }
            throw ClaiError.noProviderAvailable
        }

        if options.verbose {
            terminal.showInfo("Using provider: \(provider.name)")
        }

        var (response, wasStreamed) = try await executeGeneration(
            provider: provider,
            prompt: prompt,
            loadingMessage: loadingMessage
        )

        // Strip any thinking tags from the final response
        response = Self.stripThinkingTags(response)

        // Validate response is not empty
        guard !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClaiError.emptyResponse(provider.name)
        }

        // Cache the response if caching is enabled
        if let cacheKey, let cache {
            try? cache.set(key: cacheKey, response: response, provider: provider.name)
        }

        return GenerationResult(content: response, wasStreamed: wasStreamed, providerName: provider.name)
    }

    private func generateWithStreaming(provider: LLMProvider, prompt: String) async throws -> String {
        let streamFilter = ThinkingTagStreamFilter()
        let response = try await provider.generateStreaming(prompt: prompt) { chunk in
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
        return response
    }

    private func executeGeneration(
        provider: LLMProvider,
        prompt: String,
        loadingMessage: String
    ) async throws -> (String, Bool) {
        let useStreaming = options.stream && provider.supportsStreaming

        if useStreaming {
            terminal.clearLine()
            let streamFilter = ThinkingTagStreamFilter()
            let response = try await provider.generateStreaming(prompt: prompt) { chunk in
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
            return (response, true)
        } else {
            terminal.clearLine()
            let response = try await terminal.withSpinner(loadingMessage) {
                try await provider.generate(prompt: prompt)
            }
            return (response, false)
        }
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
