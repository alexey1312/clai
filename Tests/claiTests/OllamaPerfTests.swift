@testable import clai
import XCTest

final class OllamaPerfTests: XCTestCase {
    func testOllamaAvailabilityCheckCaching() async {
        // First call - populates the cache (may involve network request)
        let firstCallStart = Date()
        _ = await OllamaChecker.isAvailable()
        let firstCallDuration = Date().timeIntervalSince(firstCallStart)

        // Subsequent calls should hit the cache and be very fast
        let cachedIterations = 9
        let cachedCallsStart = Date()

        for _ in 0 ..< cachedIterations {
            _ = await OllamaChecker.isAvailable()
        }

        let cachedCallsDuration = Date().timeIntervalSince(cachedCallsStart)
        let averageCachedCall = cachedCallsDuration / Double(cachedIterations)

        print("First call (may include network): \(firstCallDuration)s")
        print("Cached calls (\(cachedIterations)x): \(cachedCallsDuration)s total, \(averageCachedCall)s average")

        // Cached calls should be significantly faster than 100ms each
        // (network timeout alone would be much longer)
        XCTAssertLessThan(
            averageCachedCall,
            0.1,
            "Cached availability checks should be very fast (<100ms)"
        )
    }
}
