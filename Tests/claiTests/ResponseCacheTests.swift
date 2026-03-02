@testable import clai
import Crypto
import XCTest

final class ResponseCacheTests: XCTestCase {
    // Helper to generate a unique cache key
    private func uniqueKey(_ suffix: String) -> String {
        let key = "test-command-\(suffix):mode-test:provider-test"
        return key.sha256Hash
    }

    func testValidEntryReturnsValue() async throws {
        let cache = try ResponseCache()
        let key = uniqueKey("valid")
        let response = "Valid Response"

        try await cache.set(key: key, response: response, provider: "test")

        let result = try await cache.get(key: key)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.response, response)
    }

    func testExpiredEntryReturnsNil() async throws {
        let cache = try ResponseCache()
        let key = uniqueKey("expired")
        let response = "Expired Response"

        // 8 days ago (TTL is 7 days)
        guard let oldDate = Calendar.current.date(byAdding: .day, value: -8, to: Date()) else {
            XCTFail("Could not calculate old date")
            return
        }

        // Use internal set method
        try await cache.set(key: key, response: response, provider: "test", createdAt: oldDate)

        let result = try await cache.get(key: key)
        XCTAssertNil(result, "Expired entry should return nil")
    }

    func testJustAboutExpiredEntryReturnsNil() async throws {
        let cache = try ResponseCache()
        let key = uniqueKey("expired-just-now")
        let response = "Expired Response"

        // Exactly 7 days + 1 second ago
        guard let oldDate = Calendar.current.date(
            byAdding: .second,
            value: -1,
            to:
            Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        ) else {
            XCTFail("Could not calculate old date")
            return
        }

        try await cache.set(key: key, response: response, provider: "test", createdAt: oldDate)

        let result = try await cache.get(key: key)
        XCTAssertNil(result, "Entry expired by 1 second should return nil")
    }

    func testJustValidEntryReturnsValue() async throws {
        let cache = try ResponseCache()
        let key = uniqueKey("valid-just-now")
        let response = "Valid Response"

        // Exactly 7 days - 1 hour ago
        guard let oldDate = Calendar.current.date(
            byAdding: .hour,
            value: 1,
            to:
            Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        ) else {
            XCTFail("Could not calculate old date")
            return
        }

        try await cache.set(key: key, response: response, provider: "test", createdAt: oldDate)

        let result = try await cache.get(key: key)
        XCTAssertNotNil(result, "Entry within TTL should return value")
        XCTAssertEqual(result?.response, response)
    }
}
