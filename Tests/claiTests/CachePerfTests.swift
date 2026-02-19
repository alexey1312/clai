@testable import clai
import XCTest
import Crypto

final class CachePerfTests: XCTestCase {
    // Helper to generate a unique cache key
    private static func uniqueKey(_ suffix: Int) -> String {
        let key = "test-command-\(suffix):mode-\(suffix):provider-\(suffix)"
        return key.sha256Hash
    }

    func testConcurrentCacheAccess() async throws {
        let cache = try ResponseCache()

        // Clear cache first
        try await cache.clearAll()

        // Number of concurrent operations
        let concurrentOps = 100

        // Measure time for concurrent writes
        let start = Date()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentOps {
                group.addTask {
                    let key = CachePerfTests.uniqueKey(i)
                    let response = "Response for \(i)"
                    do {
                        try await cache.set(key: key, response: response, provider: "test-provider")
                    } catch {
                        print("Cache set failed: \(error)")
                    }
                }
            }
        }

        let duration = Date().timeIntervalSince(start)
        print("Concurrent writes took: \(duration)s")

        // Verify stats
        let stats = try await cache.stats()
        XCTAssertEqual(stats.count, concurrentOps)

        // Measure time for concurrent reads
        let readStart = Date()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrentOps {
                group.addTask {
                    let key = CachePerfTests.uniqueKey(i)
                    do {
                        let result = try await cache.get(key: key)
                        if result == nil {
                            print("Cache miss for \(i)")
                        }
                    } catch {
                        print("Cache get failed: \(error)")
                    }
                }
            }
        }

        let readDuration = Date().timeIntervalSince(readStart)
        print("Concurrent reads took: \(readDuration)s")
    }
}
