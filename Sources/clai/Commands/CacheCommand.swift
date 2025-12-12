import ArgumentParser
import Foundation

struct CacheCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cache",
        abstract: "Manage response cache",
        subcommands: [ClearSubcommand.self, StatsSubcommand.self],
        defaultSubcommand: StatsSubcommand.self
    )
}

extension CacheCommand {
    struct ClearSubcommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "clear",
            abstract: "Clear all cached responses"
        )

        mutating func run() throws {
            let cache = try ResponseCache()
            try cache.clearAll()
            print("Cache cleared")
        }
    }

    struct StatsSubcommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stats",
            abstract: "Show cache statistics"
        )

        mutating func run() throws {
            let cache = try ResponseCache()
            let stats = try cache.stats()

            print("Cache Statistics")
            print("  Entries: \(stats.count)")
            print("  Size:    \(stats.sizeFormatted)")
            print("  Path:    \(ResponseCache.cacheDirectory.path)")
        }
    }
}
