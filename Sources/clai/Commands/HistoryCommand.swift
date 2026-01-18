import ArgumentParser
import Foundation

struct HistoryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "history",
        abstract: "Manage command history index",
        discussion: """
        Manage the local history index used for semantic search.
        All data stays local - nothing is sent to cloud providers.

        Examples:
          clai history index     Build or update the history index
          clai history stats     Show index statistics
          clai history clear     Delete the history index
        """,
        subcommands: [
            IndexSubcommand.self,
            StatsSubcommand.self,
            ClearSubcommand.self,
        ],
        defaultSubcommand: StatsSubcommand.self
    )
}

// MARK: - Index Subcommand

extension HistoryCommand {
    struct IndexSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "index",
            abstract: "Build or update the history index"
        )

        @Flag(name: .long, help: "Rebuild index from scratch (ignore incremental)")
        var full = false

        @Flag(name: .long, help: "Show verbose output")
        var verbose = false

        mutating func run() async throws {
            let terminal = TerminalUI(verbose: verbose)
            let store: HistoryStore

            do {
                store = try HistoryStore()
            } catch {
                throw ClaiError.historyError("Failed to open history store: \(error.localizedDescription)")
            }

            // Check/set consent
            let hasConsent = try store.hasConsent()
            if !hasConsent {
                print()
                print("History indexing enables natural language search over your shell history.")
                print("All data stays local - nothing is sent to cloud providers.")
                print()

                let consented = await terminal.promptYesNo("Enable history indexing?")
                if !consented {
                    print("History indexing cancelled.")
                    return
                }

                try store.setConsent(true)
            }

            // Run indexing
            print()
            let indexer = HistoryIndexer(store: store)

            let startTime = Date()
            let result = try await indexer.indexAll(incremental: !full) { progress, message in
                print("\r\u{001B}[K\(message) (\(Int(progress * 100))%)", terminator: "")
                try? FileHandle.standardOutput.synchronize()
            }
            let elapsed = Date().timeIntervalSince(startTime)

            print()
            print()

            // Show results
            if result.totalInserted == 0, result.totalUpdated == 0 {
                terminal.showInfo("History is already up to date.")
            } else {
                terminal.showSuccess("Indexing complete in \(String(format: "%.1f", elapsed))s")
                print()
                print("  New commands:     \(result.totalInserted)")
                print("  Updated entries:  \(result.totalUpdated)")
                print("  Shells indexed:   \(result.shellsIndexed.map(\.rawValue).joined(separator: ", "))")
            }

            if result.hasErrors {
                print()
                terminal.showWarning("Some errors occurred:")
                for error in result.errors {
                    print("  - \(error)")
                }
            }

            // Show quick stats
            let stats = try store.stats()
            print()
            print("Total indexed: \(stats.totalEntries) commands (\(stats.uniqueCommands) unique)")
        }
    }
}

// MARK: - Stats Subcommand

extension HistoryCommand {
    struct StatsSubcommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stats",
            abstract: "Show history index statistics"
        )

        @Flag(name: .long, help: "Output as JSON")
        var json = false

        mutating func run() throws {
            let store: HistoryStore

            do {
                store = try HistoryStore()
            } catch {
                throw ClaiError.historyError("Failed to open history store: \(error.localizedDescription)")
            }

            let stats = try store.stats()
            let hasConsent = try store.hasConsent()

            if json {
                printJSONStats(stats, hasConsent: hasConsent)
            } else {
                printStats(stats, hasConsent: hasConsent)
            }
        }

        private func printStats(_ stats: HistoryStats, hasConsent: Bool) {
            print()
            print(Theme.applyBold("History Index Statistics"))
            print()

            if !hasConsent {
                print("  Status:     \(Theme.warning)Not enabled\(Theme.reset)")
                print()
                print("Run 'clai history index' to enable history indexing.")
                return
            }

            print("  Status:     \(Theme.success)Enabled\(Theme.reset)")
            print("  Entries:    \(stats.totalEntries)")
            print("  Unique:     \(stats.uniqueCommands)")
            print("  Size:       \(stats.sizeFormatted)")
            print("  Path:       \(HistoryStore.storeDirectory.path)")

            if !stats.shellBreakdown.isEmpty {
                print()
                print("  By shell:")
                for (shell, count) in stats.shellBreakdown.sorted(by: { $0.value > $1.value }) {
                    print("    \(shell): \(count)")
                }
            }

            if let oldest = stats.oldestEntry, let newest = stats.newestEntry {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium

                print()
                print("  Date range:")
                print("    Oldest: \(formatter.string(from: oldest))")
                print("    Newest: \(formatter.string(from: newest))")
            }
        }

        private func printJSONStats(_ stats: HistoryStats, hasConsent: Bool) {
            var output: [String: Any] = [
                "enabled": hasConsent,
                "total_entries": stats.totalEntries,
                "unique_commands": stats.uniqueCommands,
                "size_bytes": stats.sizeBytes,
                "path": HistoryStore.storeDirectory.path,
                "shell_breakdown": stats.shellBreakdown,
            ]

            if let oldest = stats.oldestEntry {
                output["oldest_entry"] = ISO8601DateFormatter().string(from: oldest)
            }
            if let newest = stats.newestEntry {
                output["newest_entry"] = ISO8601DateFormatter().string(from: newest)
            }

            if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
               let jsonString = String(data: data, encoding: .utf8)
            {
                print(jsonString)
            }
        }
    }
}

// MARK: - Clear Subcommand

extension HistoryCommand {
    struct ClearSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "clear",
            abstract: "Delete the history index"
        )

        @Flag(name: .long, help: "Skip confirmation prompt")
        var force = false

        mutating func run() async throws {
            let terminal = TerminalUI()
            let store: HistoryStore

            do {
                store = try HistoryStore()
            } catch {
                throw ClaiError.historyError("Failed to open history store: \(error.localizedDescription)")
            }

            let stats = try store.stats()

            if stats.totalEntries == 0 {
                print("History index is already empty.")
                return
            }

            if !force {
                print()
                print("This will delete \(stats.totalEntries) indexed commands (\(stats.sizeFormatted)).")
                print("Your actual shell history files will NOT be affected.")
                print()

                let confirmed = await terminal.promptYesNo("Delete history index?")
                if !confirmed {
                    print("Cancelled.")
                    return
                }
            }

            try store.clearAll()
            terminal.showSuccess("History index cleared")
        }
    }
}
