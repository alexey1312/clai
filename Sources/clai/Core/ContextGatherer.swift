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

        // Run both checks concurrently to reduce latency
        async let helpFuture = runCommand("\(baseCommand) --help")
        async let hFuture = runCommand("\(baseCommand) -h")

        do {
            // Prefer --help output
            return try await helpFuture
        } catch {
            // Fallback to -h if --help fails
            return try await hFuture
        }
    }

    /// Get man page content for a command
    func getManPage(for command: String) async throws -> String {
        let baseCommand = command.split(separator: " ").first.map(String.init) ?? command
        return try await runCommand("set -o pipefail; man \(baseCommand) | col -b")
    }

    /// Get tldr page if available
    func getTldrPage(for command: String) async throws -> String? {
        let baseCommand = command.split(separator: " ").first.map(String.init) ?? command
        return try await runCommand("tldr \(baseCommand)")
    }

    private func runCommand(_ command: String, limit: Int = 100_000) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let data = LockedData()

                // Read continuously to avoid deadlock and enforce limit
                pipe.fileHandleForReading.readabilityHandler = { fh in
                    let chunk = fh.availableData
                    if chunk.isEmpty { return }

                    data.append(chunk)

                    if data.count > limit {
                        // Stop reading and terminate process if limit exceeded
                        pipe.fileHandleForReading.readabilityHandler = nil
                        process.terminate()
                    }
                }

                process.terminationHandler = { process in
                    // Ensure reading is stopped
                    pipe.fileHandleForReading.readabilityHandler = nil

                    // Retrieve collected data
                    let outputData = data.value

                    guard let output = String(data: outputData, encoding: .utf8) else {
                        continuation.resume(throwing: ClaiError.commandFailed(command))
                        return
                    }

                    // If terminated due to limit (SIGTERM/15) or successful but truncated
                    if process.terminationStatus == 0 || outputData.count > limit {
                        continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else {
                        continuation.resume(throwing: ClaiError.commandFailed(command))
                    }
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }
    }

    /// Thread-safe data buffer
    private final class LockedData: @unchecked Sendable {
        private var _data = Data()
        private let lock = NSLock()

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return _data.count
        }

        var value: Data {
            lock.lock()
            defer { lock.unlock() }
            return _data
        }

        func append(_ data: Data) {
            lock.lock()
            defer { lock.unlock() }
            _data.append(data)
        }
    }
}
