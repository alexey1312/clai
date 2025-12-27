import XCTest
@testable import clai

final class TerminalUITests: XCTestCase {
    var ui: TerminalUI!

    override func setUp() {
        super.setUp()
        ui = TerminalUI()
    }

    func testStyleBold() {
        let input = "This is **bold** text"
        let expected = "This is \u{001B}[1mbold\u{001B}[0m text"
        XCTAssertEqual(ui.styleBold(input), expected)
    }

    func testStyleBoldMultiple() {
        let input = "**Bold1** and **Bold2**"
        let expected = "\u{001B}[1mBold1\u{001B}[0m and \u{001B}[1mBold2\u{001B}[0m"
        XCTAssertEqual(ui.styleBold(input), expected)
    }

    func testStyleInlineCode() {
        let input = "Use `ls` command"
        let expected = "Use \u{001B}[36mls\u{001B}[0m command"
        XCTAssertEqual(ui.styleInlineCode(input), expected)
    }

    func testApplyInlineStyles() {
        let input = "Use `ls` and **cd**"
        // Since applyInlineStyles applies bold then code
        // Bold: "Use `ls` and \u{001B}[1mcd\u{001B}[0m"
        // Code: "Use \u{001B}[36mls\u{001B}[0m and \u{001B}[1mcd\u{001B}[0m"
        let expected = "Use \u{001B}[36mls\u{001B}[0m and \u{001B}[1mcd\u{001B}[0m"
        XCTAssertEqual(ui.applyInlineStyles(input), expected)
    }

    func testApplyInlineStylesNested() {
        // Nested styles are tricky with [0m reset.
        // **bold `code` bold**
        // Bold: \u{001B}[1mbold `code` bold\u{001B}[0m
        // Code: \u{001B}[1mbold \u{001B}[36mcode\u{001B}[0m bold\u{001B}[0m
        // Note: The second "bold" will lose bold style because of [0m after code.
        // This is expected behavior for now given the implementation.
        let input = "**bold `code` bold**"
        let expected = "\u{001B}[1mbold \u{001B}[36mcode\u{001B}[0m bold\u{001B}[0m"
        XCTAssertEqual(ui.applyInlineStyles(input), expected)
    }
}
