/// Helper for applying inline styles to terminal text
enum TextStyler {
    /// Apply all inline styles (bold, italic, code)
    /// Uses a single-pass parser to handle nesting and precedence correctly.
    /// - Parameters:
    ///   - text: The text to style
    ///   - baseReset: The ANSI code to reset to after a colored block (default: Default FG `[39m`)
    static func apply(_ text: String, baseReset: String = Theme.defaultColor) -> String {
        var result = ""
        let chars = Array(text)
        var index = 0
        var inBold = false
        var inItalic = false

        while index < chars.count {
            if processCodeBlock(chars, index: &index, result: &result, baseReset: baseReset) {
                continue
            }

            if processBold(chars, index: &index, result: &result, inBold: &inBold) {
                continue
            }

            if processItalic(chars, index: &index, result: &result, inItalic: &inItalic) {
                continue
            }

            // Regular character
            result.append(chars[index])
            index += 1
        }

        // Close any open styles at the end
        if inBold { result += Theme.boldOff }
        if inItalic { result += Theme.italicOff }

        return result
    }

    private static func processCodeBlock(
        _ chars: [Character],
        index: inout Int,
        result: inout String,
        baseReset: String
    ) -> Bool {
        guard chars[index] == "`" else { return false }

        // Find end of code block
        var endIndex = index + 1
        while endIndex < chars.count {
            if chars[endIndex] == "`" { break }
            endIndex += 1
        }

        // If we found an end backtick
        if endIndex < chars.count {
            // Output code block with color
            result += Theme.code // Cyan
            result += String(chars[index + 1 ..< endIndex])
            result += baseReset // Reset to base color (default or header color)
            index = endIndex + 1
        } else {
            // Unclosed code block, treat start as literal
            result.append(chars[index])
            index += 1
        }
        return true
    }

    private static func processBold(
        _ chars: [Character],
        index: inout Int,
        result: inout String,
        inBold: inout Bool
    ) -> Bool {
        guard index + 1 < chars.count, chars[index] == "*", chars[index + 1] == "*" else { return false }

        if inBold {
            result += Theme.boldOff
        } else {
            result += Theme.bold
        }
        inBold.toggle()
        index += 2
        return true
    }

    private static func processItalic(
        _ chars: [Character],
        index: inout Int,
        result: inout String,
        inItalic: inout Bool
    ) -> Bool {
        guard chars[index] == "_" else { return false }

        let prev = index > 0 ? chars[index - 1] : " "
        let next = index + 1 < chars.count ? chars[index + 1] : " "

        let isPrevAlpha = prev.isLetter || prev.isNumber
        let isNextAlpha = next.isLetter || next.isNumber

        // Toggle Off: text_ or punct_
        if inItalic, !isNextAlpha {
            result += Theme.italicOff
            inItalic = false
            index += 1
            return true
        }
        // Toggle On: _text
        else if !inItalic, !isPrevAlpha, isNextAlpha {
            result += Theme.italic
            inItalic = true
            index += 1
            return true
        }
        return false
    }
}
