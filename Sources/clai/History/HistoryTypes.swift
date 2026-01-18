import Foundation

/// Result of an indexing operation
struct IndexResult: Sendable {
    let inserted: Int
    let updated: Int

    var total: Int { inserted + updated }
}

/// A search result from the history store
struct SearchResult: Sendable {
    let id: Int64
    let command: String
    let timestamp: Date?
    let workingDirectory: String?
    let shell: HistoryEntry.Shell
    let frequency: Int
    let score: Double
}

/// Statistics about the history index
struct HistoryStats: Sendable {
    let totalEntries: Int
    let uniqueCommands: Int
    let shellBreakdown: [String: Int]
    let oldestEntry: Date?
    let newestEntry: Date?
    let sizeBytes: Int64

    var sizeFormatted: String {
        ByteFormatter.format(sizeBytes)
    }
}
