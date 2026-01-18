import ArgumentParser
import Foundation

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    @preconcurrency import Glibc
#endif

// Global shutdown flag for signal handlers to communicate with the accept loop
private nonisolated(unsafe) var shutdownRequested = false

/// Command to manage the clai daemon for shell integration
struct DaemonCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "daemon",
        abstract: "Manage the background daemon for shell integration",
        discussion: """
        The daemon provides low-latency AI completions for shell integration.
        It preloads the LLM provider and listens on a Unix socket for requests.

        Examples:
          clai daemon start     Start the daemon in background
          clai daemon stop      Stop the running daemon
          clai daemon status    Check daemon status
          clai daemon run       Run daemon in foreground (for debugging)
        """,
        subcommands: [
            StartSubcommand.self,
            StopSubcommand.self,
            StatusSubcommand.self,
            RunSubcommand.self,
        ],
        defaultSubcommand: StatusSubcommand.self
    )
}

// MARK: - Start Subcommand

extension DaemonCommand {
    struct StartSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Start the daemon in background"
        )

        @Flag(name: .long, help: "Show verbose output")
        var verbose = false

        mutating func run() async throws {
            let terminal = TerminalUI(verbose: verbose)

            // Check if already running
            let status = DaemonStatus.check()
            if status.isRunning {
                terminal.showInfo("Daemon is already running (PID: \(status.pid ?? 0))")
                return
            }

            // Clean up stale socket/pid files
            if status.socketExists {
                try? FileManager.default.removeItem(at: DaemonPaths.socketPath)
            }
            if status.pid != nil {
                try? FileManager.default.removeItem(at: DaemonPaths.pidFile)
            }

            // Get the path to the current executable
            let executablePath = ProcessInfo.processInfo.arguments[0]

            // Start daemon as a background process
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = ["daemon", "run", "--detached"]

            // Detach from terminal
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                throw ClaiError.daemonError("Failed to start daemon: \(error.localizedDescription)")
            }

            // Wait for daemon to start with exponential backoff polling
            var attempts = 0
            let maxAttempts = 10
            var delay: UInt64 = 100_000_000 // 100ms initial delay

            var newStatus = DaemonStatus.check()
            while !newStatus.isRunning, attempts < maxAttempts {
                try await Task.sleep(nanoseconds: delay)
                newStatus = DaemonStatus.check()
                attempts += 1
                delay = min(delay * 3 / 2, 500_000_000) // Increase by 50%, cap at 500ms
            }

            if newStatus.isRunning {
                terminal.showSuccess("Daemon started (PID: \(newStatus.pid ?? process.processIdentifier))")
                if verbose, let provider = newStatus.provider {
                    print("  Provider: \(provider)")
                }
            } else {
                throw ClaiError.daemonError("Daemon failed to start. Check \(DaemonPaths.logFile.path)")
            }
        }
    }
}

// MARK: - Stop Subcommand

extension DaemonCommand {
    struct StopSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Stop the running daemon"
        )

        @Flag(name: .long, help: "Force kill if graceful shutdown fails")
        var force = false

        mutating func run() async throws {
            let terminal = TerminalUI()

            let status = DaemonStatus.check()

            guard status.isRunning || status.processRunning else {
                terminal.showInfo("Daemon is not running")
                return
            }

            // Try graceful shutdown first
            if status.isRunning {
                let client = DaemonClient(timeoutMs: 1000)
                do {
                    try client.shutdown()
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                    terminal.showSuccess("Daemon stopped gracefully")
                    return
                } catch {
                    if !force {
                        terminal.showWarning("Graceful shutdown failed, use --force to kill")
                        return
                    }
                }
            }

            // Force kill if requested or graceful failed
            if force || !status.isRunning {
                if DaemonStatus.killIfRunning() {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    terminal.showSuccess("Daemon killed")
                } else {
                    terminal.showInfo("No daemon process to kill")
                }
            }

            // Clean up files
            try? FileManager.default.removeItem(at: DaemonPaths.socketPath)
            try? FileManager.default.removeItem(at: DaemonPaths.pidFile)
        }
    }
}

// MARK: - Status Subcommand

extension DaemonCommand {
    struct StatusSubcommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Check daemon status"
        )

        @Flag(name: .long, help: "Output as JSON")
        var json = false

        mutating func run() throws {
            let status = DaemonStatus.check()

            if json {
                printJSONStatus(status)
            } else {
                printStatus(status)
            }
        }

        private func printStatus(_ status: DaemonStatusInfo) {
            print()
            print(Theme.applyBold("Daemon Status"))
            print()

            if status.isRunning {
                print("  Status:     \(Theme.success)Running\(Theme.reset)")
                if let pid = status.pid {
                    print("  PID:        \(pid)")
                }
                if let uptime = status.uptimeFormatted {
                    print("  Uptime:     \(uptime)")
                }
                if let provider = status.provider {
                    print("  Provider:   \(provider)")
                }
                print("  Socket:     \(DaemonPaths.socketPath.path)")
            } else {
                print("  Status:     \(Theme.muted)Not running\(Theme.reset)")

                if status.socketExists || status.pid != nil {
                    print()
                    print(Theme.warning + "  Stale files detected. Run 'clai daemon start' to clean up." + Theme.reset)
                }
            }

            print()
        }

        private func printJSONStatus(_ status: DaemonStatusInfo) {
            var output: [String: Any] = [
                "running": status.isRunning,
                "socket_exists": status.socketExists,
                "socket_path": DaemonPaths.socketPath.path,
            ]

            if let pid = status.pid {
                output["pid"] = pid
            }
            if let uptime = status.uptime {
                output["uptime_seconds"] = uptime
            }
            if let provider = status.provider {
                output["provider"] = provider
            }

            if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
               let jsonString = String(data: data, encoding: .utf8)
            {
                print(jsonString)
            }
        }
    }
}

// MARK: - Run Subcommand (Foreground)

extension DaemonCommand {
    struct RunSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "run",
            abstract: "Run daemon in foreground (for debugging)"
        )

        @Flag(name: .long, help: "Show verbose output")
        var verbose = false

        @Flag(name: .long, help: "Run as detached background process (internal use)")
        var detached = false

        mutating func run() async throws {
            let terminal = TerminalUI(verbose: verbose)

            // Check if already running
            let status = DaemonStatus.check()
            if status.isRunning {
                throw ClaiError.daemonError("Another daemon instance is already running (PID: \(status.pid ?? 0))")
            }

            // Clean up stale files
            if status.socketExists {
                try? FileManager.default.removeItem(at: DaemonPaths.socketPath)
            }
            if status.pid != nil {
                try? FileManager.default.removeItem(at: DaemonPaths.pidFile)
            }

            if !detached {
                terminal.showInfo("Starting daemon in foreground (Ctrl+C to stop)...")
                print("  Socket: \(DaemonPaths.socketPath.path)")
                print()
            }

            // Set up signal handler for graceful shutdown
            let server = DaemonServer()

            // Handle SIGINT and SIGTERM
            shutdownRequested = false
            setupSignalHandlers()

            do {
                try await server.start()
                if !detached {
                    terminal.showSuccess("Daemon ready, listening for connections...")
                    print()
                }
                try await server.runAcceptLoop(checkShutdown: { shutdownRequested })
            } catch {
                throw ClaiError.daemonError("Daemon error: \(error.localizedDescription)")
            }

            // Graceful cleanup
            await server.stop()
        }

        private func setupSignalHandlers() {
            signal(SIGINT) { _ in
                shutdownRequested = true
            }
            signal(SIGTERM) { _ in
                shutdownRequested = true
            }
        }
    }
}
