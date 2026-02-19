import Crypto
import Dispatch
import Foundation

@preconcurrency import SQLite

/// SQLite-based response cache with TTL expiration
final class ResponseCache: @unchecked Sendable {
    private var _database: Connection?
    // Serial queue for SQLite operations to avoid blocking Swift Concurrency pool
    private let queue = DispatchQueue(label: "com.clai.response-cache", qos: .userInitiated)

    private let responses = Table("responses")

    // Column definitions
    private let id = Expression<Int64>("id")
    private let cacheKey = Expression<String>("cache_key")
    private let response = Expression<String>("response")
    private let provider = Expression<String>("provider")
    private let createdAt = Expression<Date>("created_at")

    /// Default TTL of 7 days
    private let ttlDays: Int = 7

    /// Background task for database initialization
    private var dbInitTask: Task<Void, Error>!

    init() throws {
        // Start database initialization in background on the serial queue
        dbInitTask = Task { [weak self] in
            guard let self else { return }
            try await _initDatabaseAndSet()
        }

        // Optimize startup: Run cleanup in background
        // This avoids blocking ClaiEngine initialization on DB operations
        Task { [weak self] in
            // Delay cleanup to ensure it doesn't contend with the first request
            try? await Task.sleep(for: .seconds(2))
            try? await self?.cleanupExpired()
        }
    }

    /// Initialize database and set property safely on the queue
    private func _initDatabaseAndSet() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let connection = try self._initDatabase()
                    self._database = connection
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
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
    private func createTable(_ connection: Connection) throws {
        try connection.run(
            responses.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(cacheKey, unique: true)
                table.column(response)
                table.column(provider)
                table.column(createdAt)
            }
        )

        // Create index for faster lookups
        try connection.run(responses.createIndex(cacheKey, ifNotExists: true))

        // Create index on createdAt to speed up expiration cleanup
        try connection.run(responses.createIndex(createdAt, ifNotExists: true))
    }

    /// Generate a cache key from command and context
    static func generateKey(command: String, mode: String, provider: String) -> String {
        let components = [command, mode, provider]
        let combined = components.joined(separator: ":")
        return combined.sha256Hash
    }

    /// Execute a block with the database connection on the serial queue
    @discardableResult
    private func withConnection<T>(_ block: @Sendable @escaping (Connection) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let connection: Connection
                    if let existing = self._database {
                        connection = existing
                    } else {
                        // This should generally be handled by dbInitTask, but purely for safety
                        // inside the queue to avoid race conditions if init failed or wasn't awaited properly
                        // (though public methods await dbInitTask)
                        connection = try self._initDatabase()
                        self._database = connection
                    }

                    let result = try block(connection)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func _initDatabase() throws -> Connection {
        // Create cache directory if needed
        let cacheDir = Self.cacheDirectory
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let dbPath = cacheDir.appendingPathComponent("clai_cache.sqlite").path
        let connection = try Connection(dbPath)

        // Enable WAL mode for better concurrency and write performance
        try connection.run("PRAGMA journal_mode = WAL;")

        // Set synchronous to NORMAL for better performance with acceptable durability for cache
        try connection.run("PRAGMA synchronous = NORMAL;")

        try createTable(connection)
        return connection
    }

    /// Look up a cached response
    func get(key: String) async throws -> CachedResponse? {
        // Ensure database is initialized
        _ = try await dbInitTask.value

        return try await withConnection { connection in
            let query = self.responses.filter(self.cacheKey == key)

            guard let row = try connection.pluck(query) else {
                return nil
            }

            let responseCreatedAt = row[self.createdAt]
            guard let expirationDate = Calendar.current.date(
                byAdding: .day, value: self.ttlDays, to: responseCreatedAt
            ) else {
                // Date calculation failed - treat as expired
                try self.delete(key: key, connection: connection)
                return nil
            }

            // Check if expired
            if Date() > expirationDate {
                try self.delete(key: key, connection: connection)
                return nil
            }

            return CachedResponse(
                response: row[self.response],
                provider: row[self.provider],
                createdAt: responseCreatedAt
            )
        }
    }

    /// Store a response in the cache
    func set(key: String, response responseText: String, provider providerName: String) async throws {
        // Ensure database is initialized
        _ = try await dbInitTask.value

        try await withConnection { connection in
            let insert = self.responses.insert(
                or: .replace,
                self.cacheKey <- key,
                self.response <- responseText,
                self.provider <- providerName,
                self.createdAt <- Date()
            )
            try connection.run(insert)
        }
    }

    /// Delete a cached response
    func delete(key: String) async throws {
        // Ensure database is initialized
        _ = try await dbInitTask.value

        try await withConnection { connection in
            try self.delete(key: key, connection: connection)
        }
    }

    // Internal helper that takes connection (caller must be on queue)
    private func delete(key: String, connection: Connection) throws {
        let query = responses.filter(cacheKey == key)
        try connection.run(query.delete())
    }

    /// Clean up expired entries
    func cleanupExpired() async throws {
        // Ensure database is initialized
        _ = try await dbInitTask.value

        try await withConnection { connection in
            guard let expirationDate = Calendar.current.date(byAdding: .day, value: -self.ttlDays, to: Date()) else {
                return // Cannot calculate expiration date, skip cleanup
            }
            let expired = self.responses.filter(self.createdAt < expirationDate)
            try connection.run(expired.delete())
        }
    }

    /// Clear all cached responses
    func clearAll() async throws {
        // Ensure database is initialized
        _ = try await dbInitTask.value

        try await withConnection { connection in
            try connection.run(self.responses.delete())
        }
    }

    /// Get cache statistics
    func stats() async throws -> CacheStats {
        // Ensure database is initialized
        _ = try await dbInitTask.value

        return try await withConnection { connection in
            let count = try connection.scalar(self.responses.count)
            let databasePath = Self.cacheDirectory.appendingPathComponent("clai_cache.sqlite")

            var sizeBytes: Int64 = 0
            if let attrs = try? FileManager.default.attributesOfItem(atPath: databasePath.path) {
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
