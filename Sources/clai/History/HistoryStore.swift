import Foundation

@preconcurrency import SQLite

/// SQLite-based history store with FTS5 for full-text search
final class HistoryStore: @unchecked Sendable {
    // Database connection (internal for extension access)
    let database: Connection

    // Column definitions (internal for extension access)
    let commands = Table("commands")
    let id = Expression<Int64>("id")
    let command = Expression<String>("command")
    let timestamp = Expression<Int64?>("timestamp")
    let workingDir = Expression<String?>("working_dir")
    let shell = Expression<String>("shell")
    let frequency = Expression<Int>("frequency")
    private let indexedAt = Expression<Date>("indexed_at")

    // FTS5 virtual table (internal for extension access)
    let commandsFTS = "commands_fts"

    // Patterns table (internal for extension access)
    let patterns = Table("patterns")
    private let patternId = Expression<Int64>("id")
    private let patternType = Expression<String>("pattern_type")
    private let patternData = Expression<String>("data")
    private let detectedAt = Expression<Date>("detected_at")

    // Consent tracking
    private let settings = Table("settings")
    private let settingKey = Expression<String>("key")
    private let settingValue = Expression<String>("value")

    /// History store directory
    static var storeDirectory: URL {
        let appSupport =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport.appendingPathComponent("clai").appendingPathComponent("history")
    }

    /// Database path
    static var databasePath: URL {
        storeDirectory.appendingPathComponent("history.db")
    }

    init() throws {
        // Create store directory if needed
        try FileManager.default.createDirectory(
            at: Self.storeDirectory,
            withIntermediateDirectories: true
        )

        database = try Connection(Self.databasePath.path)

        // Enable WAL mode for better concurrency
        try database.run("PRAGMA journal_mode = WAL;")
        try database.run("PRAGMA synchronous = NORMAL;")

        try createTables()
    }

    private func createTables() throws {
        // Main commands table
        try database.run(
            commands.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(command)
                table.column(timestamp)
                table.column(workingDir)
                table.column(shell)
                table.column(frequency, defaultValue: 1)
                table.column(indexedAt)
            }
        )

        // Create indexes
        try database.run(commands.createIndex(command, ifNotExists: true))
        try database.run(commands.createIndex(timestamp, ifNotExists: true))
        try database.run(commands.createIndex(frequency, ifNotExists: true))

        // FTS5 virtual table for full-text search
        try database.run("""
            CREATE VIRTUAL TABLE IF NOT EXISTS \(commandsFTS) USING fts5(
                command,
                content='commands',
                content_rowid='id',
                tokenize='porter unicode61'
            );
        """)

        // Triggers to keep FTS in sync
        try database.run("""
            CREATE TRIGGER IF NOT EXISTS commands_ai AFTER INSERT ON commands BEGIN
                INSERT INTO \(commandsFTS)(rowid, command) VALUES (new.id, new.command);
            END;
        """)

        try database.run("""
            CREATE TRIGGER IF NOT EXISTS commands_ad AFTER DELETE ON commands BEGIN
                INSERT INTO \(commandsFTS)(\(commandsFTS), rowid, command)
                VALUES('delete', old.id, old.command);
            END;
        """)

        try database.run("""
            CREATE TRIGGER IF NOT EXISTS commands_au AFTER UPDATE ON commands BEGIN
                INSERT INTO \(commandsFTS)(\(commandsFTS), rowid, command)
                VALUES('delete', old.id, old.command);
                INSERT INTO \(commandsFTS)(rowid, command) VALUES (new.id, new.command);
            END;
        """)

        // Patterns table
        try database.run(
            patterns.create(ifNotExists: true) { table in
                table.column(patternId, primaryKey: .autoincrement)
                table.column(patternType)
                table.column(patternData)
                table.column(detectedAt)
            }
        )

        // Settings table (for consent, etc.)
        try database.run(
            settings.create(ifNotExists: true) { table in
                table.column(settingKey, primaryKey: true)
                table.column(settingValue)
            }
        )
    }

    // MARK: - Consent Management

    /// Check if user has consented to history indexing
    func hasConsent() throws -> Bool {
        let query = settings.filter(settingKey == "consent_given")
        guard let row = try database.pluck(query) else {
            return false
        }
        return row[settingValue] == "true"
    }

    /// Record user consent
    func setConsent(_ consented: Bool) throws {
        let insert = settings.insert(
            or: .replace,
            settingKey <- "consent_given",
            settingValue <- (consented ? "true" : "false")
        )
        try database.run(insert)

        if consented {
            let dateInsert = settings.insert(
                or: .replace,
                settingKey <- "consent_date",
                settingValue <- ISO8601DateFormatter().string(from: Date())
            )
            try database.run(dateInsert)
        }
    }

    // MARK: - Indexing

    /// Index history entries, deduplicating and updating frequency
    func index(entries: [HistoryEntry]) throws -> IndexResult {
        var inserted = 0
        var updated = 0

        for entry in entries {
            // Check if command already exists
            let existing = commands.filter(command == entry.command && shell == entry.shell.rawValue)

            if let row = try database.pluck(existing) {
                // Update frequency
                let currentFrequency = row[frequency]
                try database.run(existing.update(frequency <- currentFrequency + 1))
                updated += 1
            } else {
                // Insert new entry
                let insert = commands.insert(
                    command <- entry.command,
                    timestamp <- entry.timestamp.map { Int64($0.timeIntervalSince1970) },
                    workingDir <- entry.workingDirectory,
                    shell <- entry.shell.rawValue,
                    frequency <- entry.frequency,
                    indexedAt <- Date()
                )
                try database.run(insert)
                inserted += 1
            }
        }

        return IndexResult(inserted: inserted, updated: updated)
    }

    /// Get the timestamp of the most recently indexed command for a shell
    func lastIndexedTimestamp(for shell: HistoryEntry.Shell) throws -> Date? {
        let query = commands
            .filter(self.shell == shell.rawValue)
            .filter(timestamp != nil)
            .order(timestamp.desc)
            .limit(1)

        guard let row = try database.pluck(query),
              let timestampValue = row[timestamp]
        else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(timestampValue))
    }

    // MARK: - Search

    /// Search history using full-text search
    func search(query: String, limit: Int = 20) throws -> [SearchResult] {
        // Use FTS5 for search with BM25 ranking
        let sql = """
            SELECT c.id, c.command, c.timestamp, c.working_dir, c.shell, c.frequency,
                   bm25(\(commandsFTS)) as rank
            FROM \(commandsFTS)
            JOIN commands c ON \(commandsFTS).rowid = c.id
            WHERE \(commandsFTS) MATCH ?
            ORDER BY rank, c.frequency DESC, c.timestamp DESC
            LIMIT ?
        """

        // Escape special FTS5 characters and format query
        let ftsQuery = formatFTSQuery(query)

        var results: [SearchResult] = []

        let statement = try database.prepare(sql)
        for row in statement.bind(ftsQuery, limit) {
            guard let cmdId = row[0] as? Int64,
                  let cmdText = row[1] as? String,
                  let shellName = row[4] as? String,
                  let freq = row[5] as? Int64
            else {
                continue
            }

            let rowTimestamp = row[2] as? Int64
            let dir = row[3] as? String
            let rank = row[6] as? Double ?? 0

            results.append(SearchResult(
                id: cmdId,
                command: cmdText,
                timestamp: rowTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                workingDirectory: dir,
                shell: HistoryEntry.Shell(rawValue: shellName) ?? .bash,
                frequency: Int(freq),
                score: -rank // BM25 returns negative scores, lower is better
            ))
        }

        return results
    }

    /// Search with exact match (grep-like)
    func searchExact(pattern: String, limit: Int = 20) throws -> [SearchResult] {
        let query = commands
            .filter(command.like("%\(pattern)%"))
            .order(frequency.desc, timestamp.desc)
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

    /// Search with time filter
    func search(query: String, since: Date, limit: Int = 20) throws -> [SearchResult] {
        let sinceTimestamp = Int64(since.timeIntervalSince1970)

        let sql = """
            SELECT c.id, c.command, c.timestamp, c.working_dir, c.shell, c.frequency,
                   bm25(\(commandsFTS)) as rank
            FROM \(commandsFTS)
            JOIN commands c ON \(commandsFTS).rowid = c.id
            WHERE \(commandsFTS) MATCH ? AND c.timestamp >= ?
            ORDER BY rank, c.frequency DESC, c.timestamp DESC
            LIMIT ?
        """

        let ftsQuery = formatFTSQuery(query)

        var results: [SearchResult] = []

        let statement = try database.prepare(sql)
        for row in statement.bind(ftsQuery, sinceTimestamp, limit) {
            guard let cmdId = row[0] as? Int64,
                  let cmdText = row[1] as? String,
                  let shellName = row[4] as? String,
                  let freq = row[5] as? Int64
            else {
                continue
            }

            let rowTimestamp = row[2] as? Int64
            let dir = row[3] as? String
            let rank = row[6] as? Double ?? 0

            results.append(SearchResult(
                id: cmdId,
                command: cmdText,
                timestamp: rowTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                workingDirectory: dir,
                shell: HistoryEntry.Shell(rawValue: shellName) ?? .bash,
                frequency: Int(freq),
                score: -rank
            ))
        }

        return results
    }

    // MARK: - Private Helpers

    /// Format query for FTS5 (escape special characters, add prefix matching)
    private func formatFTSQuery(_ query: String) -> String {
        // Split into words and add prefix matching for each
        let words = query.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { word -> String in
                // Escape special FTS5 characters
                var escaped = word
                for char in ["\"", "'", "(", ")", "*", "-", ":", "^", "{", "}"] {
                    escaped = escaped.replacingOccurrences(of: char, with: " ")
                }
                // Add prefix matching
                return "\(escaped)*"
            }

        return words.joined(separator: " ")
    }
}
