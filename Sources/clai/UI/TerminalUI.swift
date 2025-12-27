import Foundation

#if !os(Linux)
    import Noora
#endif

/// Flush stdout in a concurrency-safe manner
@inline(__always)
private func flushStdout() {
    // FileHandle.standardOutput is sendable and its synchronize operation
    // ensures data is flushed to the underlying file descriptor
    try? FileHandle.standardOutput.synchronize()
}

/// Output format for responses
enum OutputFormat {
    case plain
    case json
}

/// Model download choice
enum ModelDownloadChoice: String, CaseIterable {
    case downloadStandard = "Download standard model (Qwen3-4B, ~2.5GB)"
    case downloadSmall = "Download smaller model (Qwen3-0.6B, ~400MB)"
    case useCloud = "Use cloud APIs instead (requires API key)"
    case skip = "Skip for now"
}

/// Terminal UI wrapper using Noora components on macOS, plain ANSI on Linux
final class TerminalUI: @unchecked Sendable {
    #if !os(Linux)
        private let noora: Noora
    #endif
    private let verbose: Bool

    init(verbose: Bool = false) {
        #if !os(Linux)
            noora = Noora()
        #endif
        self.verbose = verbose
    }

    // MARK: - Progress Indicators

    func showProgress(_ message: String) {
        print("⏳ \(message)")
    }

    func showProgressBar(
        message: String,
        action: @escaping (@escaping (Double) async -> Void) async throws -> Void
    ) async throws {
        print("⏳ \(message)")
        try await action { progress in
            let percentage = Int(progress * 100)
            let filled = String(repeating: "█", count: percentage / 5)
            let empty = String(repeating: "░", count: 20 - percentage / 5)
            print("\r[\(filled)\(empty)] \(percentage)%", terminator: "")
            flushStdout()
            if progress >= 1.0 {
                print()
            }
        }
    }

    /// Show step indicator for multi-stage operations
    func showStep(_ step: Int, of total: Int, message: String) {
        print("[\(step)/\(total)] \(message)")
    }

    // MARK: - Alerts

    func showSuccess(_ message: String) {
        #if os(Linux)
            print("\u{001B}[32m✓ \(message)\u{001B}[0m")
        #else
            noora.success(.alert(TerminalText(stringLiteral: message)))
        #endif
    }

    func showWarning(_ message: String) {
        #if os(Linux)
            print("\u{001B}[33m⚠ \(message)\u{001B}[0m")
        #else
            noora.warning(.alert(TerminalText(stringLiteral: message)))
        #endif
    }

    func showError(_ message: String) {
        #if os(Linux)
            print("\u{001B}[31m✗ \(message)\u{001B}[0m")
        #else
            noora.error(.alert(TerminalText(stringLiteral: message)))
        #endif
    }

    func showInfo(_ message: String) {
        print(message)
    }

    func showHeader(_ text: String) {
        print("\u{001B}[1m\(text)\u{001B}[0m")
    }

    func printLine(_ text: String = "") {
        print(text)
    }

    func showPrompt(_ text: String) {
        print(text, terminator: "")
        flushStdout()
    }

    // MARK: - Response Output

    func showResponse(_ response: String, format: OutputFormat) {
        switch format {
        case .plain:
            print()
            showStyledResponse(response)
        case .json:
            let json = formatAsJSON(response)
            print(json)
        }
    }

    /// Display styled markdown-like response
    private func showStyledResponse(_ response: String) {
        let lines = response.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let lineStr = String(line)

            // Headers (# ## ###)
            if lineStr.hasPrefix("### ") {
                print("\u{001B}[1;36m\(lineStr.dropFirst(4))\u{001B}[0m")
            } else if lineStr.hasPrefix("## ") {
                print("\u{001B}[1;33m\(lineStr.dropFirst(3))\u{001B}[0m")
            } else if lineStr.hasPrefix("# ") {
                print("\u{001B}[1;32m\(lineStr.dropFirst(2))\u{001B}[0m")
            }
            // Code blocks (```)
            else if lineStr.hasPrefix("```") {
                print("\u{001B}[90m\(lineStr)\u{001B}[0m")
            }
            // Bullet points
            else if lineStr.hasPrefix("- ") || lineStr.hasPrefix("* ") {
                let content = String(lineStr.dropFirst(2))
                print("  • \(TextStyler.apply(content))")
            }
            // Numbered lists
            else if let match = lineStr.range(of: #"^\d+\. "#, options: .regularExpression) {
                let number = lineStr[match].dropLast()
                let rest = String(lineStr[match.upperBound...])
                print("  \(number) \(TextStyler.apply(rest))")
            }
            // Regular text
            else {
                print(TextStyler.apply(lineStr))
            }
        }
    }

    func clearLine() {
        print("\r\u{001B}[K", terminator: "")
        flushStdout()
    }

    func appendStreamChunk(_ chunk: String) {
        print(chunk, terminator: "")
        flushStdout()
    }

    func endStream() {
        print()
    }

    // MARK: - Prompts

    func promptYesNo(_ question: String) async -> Bool {
        print("\(question) [y/N] ", terminator: "")
        flushStdout()

        guard let line = readLine()?.lowercased() else {
            return false
        }

        return line == "y" || line == "yes"
    }

    func promptChoice<T: CaseIterable & RawRepresentable>(
        _ question: String,
        options: T.Type
    ) async -> T? where T.RawValue == String {
        print()
        print("\u{001B}[1m\(question)\u{001B}[0m")
        print()
        for (index, option) in T.allCases.enumerated() {
            print("  [\(index + 1)] \(option.rawValue)")
        }
        print()
        print("Choose [1-\(T.allCases.count)]: ", terminator: "")
        flushStdout()

        guard let line = readLine(),
              let index = Int(line),
              index >= 1,
              index <= T.allCases.count
        else {
            return nil
        }

        return Array(T.allCases)[index - 1]
    }

    /// Prompt for MLX model download consent
    func promptMLXDownload() async -> ModelDownloadChoice? {
        print()
        print("\u{001B}[1mNo local LLM provider found.\u{001B}[0m")
        print()
        print("clai can download a local model for offline use.")
        print("This is free and private - no data leaves your device.")
        print()

        return await promptChoice(
            "What would you like to do?",
            options: ModelDownloadChoice.self
        )
    }

    /// Show provider selection prompt
    func promptProviderSelection(available: [String]) async -> String? {
        guard !available.isEmpty else { return nil }

        print()
        print("\u{001B}[1mMultiple providers available:\u{001B}[0m")
        print()

        for (index, provider) in available.enumerated() {
            print("  [\(index + 1)] \(provider)")
        }
        print()
        print("Choose [1-\(available.count)]: ", terminator: "")
        flushStdout()

        guard let line = readLine(),
              let index = Int(line),
              index >= 1,
              index <= available.count
        else {
            return available.first
        }

        return available[index - 1]
    }

    // MARK: - Private

    private func formatAsJSON(_ response: String) -> String {
        let output: [String: Any] = [
            "response": response,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{\"response\": \"\(response.replacingOccurrences(of: "\"", with: "\\\""))\"}"
        }

        return json
    }
}
