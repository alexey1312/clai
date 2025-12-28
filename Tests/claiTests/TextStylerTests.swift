import XCTest
@testable import clai

final class TextStylerTests: XCTestCase {

    func testStyleBold() {
        let input = "This is **bold** text"
        // Expect specific reset [22m (Normal intensity) instead of [0m
        let expected = "This is \u{001B}[1mbold\u{001B}[22m text"
        XCTAssertEqual(TextStyler.styleBold(input), expected)
    }

    func testStyleBoldMultiple() {
        let input = "**Bold1** and **Bold2**"
        let expected = "\u{001B}[1mBold1\u{001B}[22m and \u{001B}[1mBold2\u{001B}[22m"
        XCTAssertEqual(TextStyler.styleBold(input), expected)
    }

    func testStyleInlineCode() {
        let input = "Use `ls` command"
        // Expect specific reset [39m (Default foreground color) instead of [0m
        let expected = "Use \u{001B}[36mls\u{001B}[39m command"
        XCTAssertEqual(TextStyler.styleInlineCode(input), expected)
    }

    func testApply() {
        let input = "Use `ls` and **cd**"
        // Since apply applies bold then code
        // Bold: "Use `ls` and \u{001B}[1mcd\u{001B}[22m"
        // Code: "Use \u{001B}[36mls\u{001B}[39m and \u{001B}[1mcd\u{001B}[22m"
        let expected = "Use \u{001B}[36mls\u{001B}[39m and \u{001B}[1mcd\u{001B}[22m"
        XCTAssertEqual(TextStyler.apply(input), expected)
    }

    func testApplyNested() {
        // Nested styles should now work correctly!
        // **bold `code` bold**
        // Bold: \u{001B}[1mbold `code` bold\u{001B}[22m
        // Code: \u{001B}[1mbold \u{001B}[36mcode\u{001B}[39m bold\u{001B}[22m
        // Note: The second "bold" retains bold style because [39m only resets color!
        let input = "**bold `code` bold**"
        let expected = "\u{001B}[1mbold \u{001B}[36mcode\u{001B}[39m bold\u{001B}[22m"
        XCTAssertEqual(TextStyler.apply(input), expected)
    }
}
