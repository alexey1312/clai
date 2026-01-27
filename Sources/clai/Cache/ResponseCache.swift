import Crypto
import Foundation

@preconcurrency import SQLite

/// SQLite-based response cache with TTL expiration
final class ResponseCache: @unchecked Sendable {
    private var _database: Connection?
    private let lock = NSLock()

    private let responses = Table("responses")

    // Column definitions
    private let id = Expression<Int64>("id")
    private let cacheKey = Expression<String>("cache_key")
    private let response = Expression<String>("response")
    private let provider = Expression<String>("provider")
    private let createdAt = Expression<Date>("created_at")

    /// Default TTL of 7 days
    private let ttlDays: Int = 7

    init() throws {
        // Optimize startup: Run cleanup in background
        // This avoids blocking ClaiEngine initialization on DB operations
        Task { [weak self] in
            // Delay cleanup to ensure it doesn't contend with the first request
            try? await Task.sleep(for: .seconds(2))
            try? self?.cleanupExpired()
        }
    }

    /// Get cache directory path
    static var cacheDirectory: URL {
        let cacheDir =
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return cacheDir.appendingPathComponent("clai")
    }

    /// Create the responses table if it doesn't exist
    private func createTable(_ db: Connection) throws {
        try db.run(
            responses.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(cacheKey, unique: true)
                table.column(response)
                table.column(provider)
                table.column(createdAt)
            })

        // Create index for faster lookups
        try db.run(responses.createIndex(cacheKey, ifNotExists: true))

        // Create index on createdAt to speed up expiration cleanup
        try db.run(responses.createIndex(createdAt, ifNotExists: true))
    }

    /// Generate a cache key from command and context
    static func generateKey(command: String, mode: String, provider: String) -> String {
        let components = [command, mode, provider]
        let combined = components.joined(separator: ":")
        return combined.sha256Hash
    }

    /// Execute a block with the database connection
    @discardableResult
    private func withConnection<T>(_ block: (Connection) throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }

        let db: Connection
        if let existing = _database {
            db = existing
        } else {
            db = try _initDatabase()
            _database = db
        }

        return try block(db)
    }

    private func _initDatabase() throws -> Connection {
        // Create cache directory if needed
        let cacheDir = Self.cacheDirectory
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let dbPath = cacheDir.appendingPathComponent("clai_cache.sqlite").path
        let db = try Connection(dbPath)

        // Enable WAL mode for better concurrency and write performance
        try db.run("PRAGMA journal_mode = WAL;")

        // Set synchronous to NORMAL for better performance with acceptable durability for cache
        try db.run("PRAGMA synchronous = NORMAL;")

        try createTable(db)
        return db
    }

    /// Look up a cached response
    func get(key: String) throws -> CachedResponse? {
        try withConnection { db in
            let query = responses.filter(cacheKey == key)

            guard let row = try db.pluck(query) else {
                return nil
            }

            let responseCreatedAt = row[createdAt]
            guard let expirationDate = Calendar.current.date(
                byAdding: .day, value: ttlDays, to: responseCreatedAt
            ) else {
                // Date calculation failed - treat as expired
                try delete(key: key, db: db)
                return nil
            }

            // Check if expired
            if Date() > expirationDate {
                try delete(key: key, db: db)
                return nil
            }

            return CachedResponse(
                response: row[response],
                provider: row[provider],
                createdAt: responseCreatedAt
            )
        }
    }

    /// Store a response in the cache
    func set(key: String, response responseText: String, provider providerName: String) throws {
        try withConnection { db in
            let insert = responses.insert(
                or: .replace,
                cacheKey <- key,
                response <- responseText,
                provider <- providerName,
                createdAt <- Date()
            )
            try db.run(insert)
        }
    }

    /// Delete a cached response
    func delete(key: String) throws {
        try withConnection { db in
            try delete(key: key, db: db)
        }
    }

    // Internal helper that takes db (caller must hold lock)
    private func delete(key: String, db: Connection) throws {
        let query = responses.filter(cacheKey == key)
        try db.run(query.delete())
    }

    /// Clean up expired entries
    func cleanupExpired() throws {
        try withConnection { db in
            guard let expirationDate = Calendar.current.date(byAdding: .day, value: -ttlDays, to: Date()) else {
                return // Cannot calculate expiration date, skip cleanup
            }
            let expired = responses.filter(createdAt < expirationDate)
            try db.run(expired.delete())
        }
    }

    /// Clear all cached responses
    func clearAll() throws {
        try withConnection { db in
            try db.run(responses.delete())
        }
    }

    /// Get cache statistics
    func stats() throws -> CacheStats {
        try withConnection { db in
            let count = try db.scalar(responses.count)
            let dbPath = Self.cacheDirectory.appendingPathComponent("clai_cache.sqlite")

            var sizeBytes: Int64 = 0
            if let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath.path) {
                sizeBytes = attrs[.size] as? Int64 ?? 0
            }

            return CacheStats(count: count, sizeBytes: sizeBytes)
        }
    }
}

/// Cache statistics
struct CacheStats: Sendable {
    let count: Int
    let sizeBytes: Int64

    var sizeFormatted: String {
        ByteFormatter.format(sizeBytes)
    }
}

/// A cached response entry
struct CachedResponse: Sendable {
    let response: String
    let provider: String
    let createdAt: Date
}

// MARK: - String Hashing Extension

private let hexAlphabet = Array("0123456789abcdef".utf16)

extension String {
    /// Compute SHA256 hash of the string
    var sha256Hash: String {
        let data = Data(utf8)
        let digest = SHA256.hash(data: data)

        return String(unsafeUninitializedCapacity: 64) { buffer in
            var ptr = buffer.baseAddress!
            for byte in digest {
                ptr[0] = UInt8(hexAlphabet[Int(byte >> 4)])
                ptr[1] = UInt8(hexAlphabet[Int(byte & 0x0F)])
                ptr += 2
            }
            return 64
        }
    }
}
