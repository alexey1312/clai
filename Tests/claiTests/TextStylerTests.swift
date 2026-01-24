@testable import clai
import XCTest

final class TextStylerTests: XCTestCase {
    func testApplyBold() {
        let input = "This is **bold** text"
        // Expect specific reset [22m (Normal intensity) instead of [0m
        let expected = "This is \u{001B}[1mbold\u{001B}[22m text"
        XCTAssertEqual(TextStyler.apply(input), expected)
    }

    func testApplyBoldMultiple() {
        let input = "**Bold1** and **Bold2**"
        let expected = "\u{001B}[1mBold1\u{001B}[22m and \u{001B}[1mBold2\u{001B}[22m"
        XCTAssertEqual(TextStyler.apply(input), expected)
    }

    func testApplyInlineCode() {
        let input = "Use `ls` command"
        // Expect specific reset [39m (Default foreground color) instead of [0m
        let expected = "Use \u{001B}[36mls\u{001B}[39m command"
        XCTAssertEqual(TextStyler.apply(input), expected)
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

    func testApplyLink() {
        let input = "[GitHub](https://github.com)"
        // Accent([36m) + GitHub + Reset([39m) + " (" + Muted([90m) + URL + Reset([39m) + ")"
        let expected = "\u{001B}[36mGitHub\u{001B}[39m (\u{001B}[90mhttps://github.com\u{001B}[39m)"
        XCTAssertEqual(TextStyler.apply(input), expected)
    }

    func testApplyNestedLink() {
        let input = "[**Bold**](url)"
        // Accent([36m) + Bold([1m) + "Bold" + BoldOff([22m) + Reset([39m) + ...
        let expected = "\u{001B}[36m\u{001B}[1mBold\u{001B}[22m\u{001B}[39m (\u{001B}[90murl\u{001B}[39m)"
        XCTAssertEqual(TextStyler.apply(input), expected)
    }
}
