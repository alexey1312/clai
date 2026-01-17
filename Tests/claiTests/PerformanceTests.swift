@testable import clai
import XCTest

final class PerformanceTests: XCTestCase {
    func testSha256HashCorrectness() {
        // Known test vector
        let input = "hello"
        let expected = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

        // This uses the extension in ResponseCache.swift which we optimized
        XCTAssertEqual(input.sha256Hash, expected)

        // Another test vector
        let input2 = "clai:explain:ls"
        // echo -n "clai:explain:ls" | sha256sum
        // 93e5b8a4cb232d510401db023eaf41e4c8f896c6d7fa3f5d88673732f6767bfd
        let expected2 = "93e5b8a4cb232d510401db023eaf41e4c8f896c6d7fa3f5d88673732f6767bfd"
        XCTAssertEqual(input2.sha256Hash, expected2)
    }
}
