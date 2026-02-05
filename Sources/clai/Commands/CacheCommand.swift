import ArgumentParser
import Foundation

struct CacheCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cache",
        abstract: "Manage response cache",
        subcommands: [ClearSubcommand.self, StatsSubcommand.self],
        defaultSubcommand: StatsSubcommand.self
    )
}

extension CacheCommand {
    struct ClearSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "clear",
            abstract: "Clear all cached responses"
        )

        mutating func run() async throws {
            let cache = try ResponseCache()
            try await cache.clearAll()
            print("Cache cleared")
        }
    }

    struct StatsSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stats",
            abstract: "Show cache statistics"
        )

        mutating func run() async throws {
            let cache = try ResponseCache()
            let stats = try await cache.stats()

            print("Cache Statistics")
            print("  Entries: \(stats.count)")
            print("  Size:    \(stats.sizeFormatted)")
            print("  Path:    \(ResponseCache.cacheDirectory.path)")
        }
    }
}
