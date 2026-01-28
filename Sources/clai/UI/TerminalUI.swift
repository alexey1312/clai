import Foundation

#if canImport(Glibc)
    import Glibc
#elseif canImport(Darwin)
    import Darwin
#endif

import Noora

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

/// Terminal UI wrapper using Noora components
final class TerminalUI: @unchecked Sendable {
    private let noora: Noora
    private let verbose: Bool

    init(verbose: Bool = false) {
        noora = Noora()
        self.verbose = verbose
    }

    // MARK: - Progress Indicators

    /// Execute an operation with an animated spinner
    func withSpinner<T>(_ message: String, operation: () async throws -> T) async throws -> T {
        // If not a TTY or in verbose mode, fall back to simple logging
        guard isatty(FileHandle.standardOutput.fileDescriptor) != 0, !verbose else {
            showProgress(message)
            return try await operation()
        }

        let spinner = Spinner(message: message)

        do {
            let result = try await operation()
            await spinner.stop()
            print("\r\(Theme.success)✔\(Theme.reset) \(message)")
            flushStdout()
            return result
        } catch {
            await spinner.stop()
            print("\r\(Theme.error)✖\(Theme.reset) \(message)")
            flushStdout()
            throw error
        }
    }

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
            // Reserve space for " [] 100%" (approx 8 chars) and keep min width
            let width = self.terminalWidth
            let barWidth = max(10, width - 8)
            let filledCount = Int(Double(barWidth) * progress)
            let emptyCount = max(0, barWidth - filledCount)

            let filled = String(repeating: "█", count: filledCount)
            let empty = String(repeating: "░", count: emptyCount)
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
        noora.success(.alert(TerminalText(stringLiteral: message)))
    }

    func showWarning(_ message: String) {
        noora.warning(.alert(TerminalText(stringLiteral: message)))
    }

    func showError(_ message: String) {
        noora.error(.alert(TerminalText(stringLiteral: message)))
    }

    func showInfo(_ message: String) {
        print(message)
    }

    func showHeader(_ text: String) {
        print(Theme.applyBold(text))
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
            var renderer = MarkdownRenderer(terminalWidth: terminalWidth) { [noora] headers, rows in
                noora.table(headers: headers, rows: rows)
            }
            renderer.render(response)
        case .json:
            print(formatAsJSON(response))
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

    func showProviderAttribution(_ providerName: String) {
        print()
        print("\(Theme.muted)— by \(providerName)\(Theme.reset)")
    }

    // MARK: - Prompts

    func promptYesNo(_ question: String) async -> Bool {
        noora.yesOrNoChoicePrompt(
            question: TerminalText(stringLiteral: question),
            defaultAnswer: false
        )
    }

    func promptChoice<T: CaseIterable & RawRepresentable>(
        _ question: String,
        options _: T.Type
    ) async -> T? where T.RawValue == String {
        guard !T.allCases.isEmpty else { return nil }

        let options = T.allCases.map(\.rawValue)
        let selected = noora.singleChoicePrompt(
            question: TerminalText(stringLiteral: question),
            options: options
        )
        return T.allCases.first { $0.rawValue == selected }
    }

    /// Prompt for MLX model download consent
    func promptMLXDownload() async -> ModelDownloadChoice? {
        print()
        print(Theme.applyBold("No local LLM provider found."))
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
        return noora.singleChoicePrompt(
            question: TerminalText(stringLiteral: "Multiple providers available:"),
            options: available
        )
    }

    // MARK: - Private

    private var terminalWidth: Int {
        var winSize = winsize()
        #if os(Linux)
            let result = ioctl(FileHandle.standardOutput.fileDescriptor, UInt(TIOCGWINSZ), &winSize)
        #else
            let result = ioctl(FileHandle.standardOutput.fileDescriptor, TIOCGWINSZ, &winSize)
        #endif

        if result == 0, winSize.ws_col > 0 {
            return Int(winSize.ws_col)
        }
        return 80
    }

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
