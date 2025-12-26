import Foundation

/// Gathered context about a command from multiple sources
struct CommandContext: Sendable {
    let helpOutput: String?
    let manPageContent: String?
    let tldrContent: String?

    var isEmpty: Bool {
        helpOutput == nil && manPageContent == nil && tldrContent == nil
    }
}

/// Gathers context about commands from help, man pages, and tldr
final class ContextGatherer: Sendable {
    /// Gather all available context for a command
    func gather(for command: String) async throws -> CommandContext {
        async let helpOutput = getHelpOutput(for: command)
        async let manContent = getManPage(for: command)
        async let tldrContent = getTldrPage(for: command)

        return await CommandContext(
            helpOutput: try? helpOutput,
            manPageContent: try? manContent,
            tldrContent: try? tldrContent
        )
    }

    /// Get --help output for a command
    func getHelpOutput(for command: String) async throws -> String {
        let baseCommand = command.split(separator: " ").first.map(String.init) ?? command

        // Try --help first, then -h
        if let output = try? await runCommand("\(baseCommand) --help") {
            return output
        }

        return try await runCommand("\(baseCommand) -h")
    }

    /// Get man page content for a command
    func getManPage(for command: String) async throws -> String {
        let baseCommand = command.split(separator: " ").first.map(String.init) ?? command
        return try await runCommand("set -o pipefail; man \(baseCommand) | col -b")
    }

    /// Get tldr page if available
    func getTldrPage(for command: String) async throws -> String? {
        let baseCommand = command.split(separator: " ").first.map(String.init) ?? command

        // Check if tldr is installed
        guard await (try? runCommand("which tldr")) != nil else {
            return nil
        }

        return try await runCommand("tldr \(baseCommand)")
    }

    private func runCommand(_ command: String) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ClaiError.commandFailed(command)
        }

        if process.terminationStatus != 0 {
            throw ClaiError.commandFailed(command)
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
