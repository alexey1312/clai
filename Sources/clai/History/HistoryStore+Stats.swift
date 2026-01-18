import Foundation

// MARK: - Statistics & Maintenance

extension HistoryStore {
    /// Get index statistics
    func stats() throws -> HistoryStats {
        let count = try database.scalar(commands.count)

        // Get unique commands count
        let uniqueCount = try database.scalar(
            "SELECT COUNT(DISTINCT command) FROM commands"
        ) as? Int64 ?? 0

        // Get shell breakdown
        var shellBreakdown: [String: Int] = [:]
        let shellQuery = "SELECT shell, COUNT(*) FROM commands GROUP BY shell"
        for row in try database.prepare(shellQuery) {
            if let shellName = row[0] as? String,
               let shellCount = row[1] as? Int64
            {
                shellBreakdown[shellName] = Int(shellCount)
            }
        }

        // Get date range
        let oldest = try getOldestTimestamp()
        let newest = try getNewestTimestamp()

        // Get database file size
        var sizeBytes: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: Self.databasePath.path) {
            sizeBytes = attrs[.size] as? Int64 ?? 0
        }

        return HistoryStats(
            totalEntries: count,
            uniqueCommands: Int(uniqueCount),
            shellBreakdown: shellBreakdown,
            oldestEntry: oldest,
            newestEntry: newest,
            sizeBytes: sizeBytes
        )
    }

    private func getOldestTimestamp() throws -> Date? {
        let oldestQuery = commands.order(timestamp.asc).limit(1)
        guard let row = try database.pluck(oldestQuery),
              let oldestTimestamp = row[timestamp]
        else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(oldestTimestamp))
    }

    private func getNewestTimestamp() throws -> Date? {
        let newestQuery = commands.order(timestamp.desc).limit(1)
        guard let row = try database.pluck(newestQuery),
              let newestTimestamp = row[timestamp]
        else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(newestTimestamp))
    }

    /// Clear all indexed history
    func clearAll() throws {
        try database.run(commands.delete())
        try database.run(patterns.delete())
        // Rebuild FTS index
        try database.run("INSERT INTO \(commandsFTS)(\(commandsFTS)) VALUES('rebuild');")
    }

    /// Get most frequent commands for pattern analysis
    func mostFrequent(limit: Int = 50) throws -> [SearchResult] {
        let query = commands
            .order(frequency.desc)
            .limit(limit)

        var results: [SearchResult] = []

        for row in try database.prepare(query) {
            results.append(SearchResult(
                id: row[id],
                command: row[command],
                timestamp: row[timestamp].map { Date(timeIntervalSince1970: TimeInterval($0)) },
                workingDirectory: row[workingDir],
                shell: HistoryEntry.Shell(rawValue: row[shell]) ?? .bash,
                frequency: row[frequency],
                score: Double(row[frequency])
            ))
        }

        return results
    }
}
