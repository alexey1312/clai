@testable import clai
import XCTest

final class OllamaPerfTests: XCTestCase {
    func testOllamaAvailabilityCheckPerformance() async {
        let iterations = 10
        let startTime = Date()

        for _ in 0 ..< iterations {
            _ = await OllamaChecker.isAvailable()
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let average = duration / Double(iterations)

        print("Ollama availability check took \(duration)s for \(iterations) iterations. Average: \(average)s")

        // This is just to see the output, not asserting anything strict
        XCTAssert(true)
    }
}
