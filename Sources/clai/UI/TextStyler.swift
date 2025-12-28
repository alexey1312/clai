/// Helper for applying inline styles to terminal text
enum TextStyler {
    /// Apply all inline styles (bold, code)
    static func apply(_ text: String) -> String {
        var result = text
        result = styleBold(result)
        result = styleInlineCode(result)
        return result
    }

    /// Style bold text (**text**)
    static func styleBold(_ text: String) -> String {
        var result = ""
        var inBold = false
        let chars = Array(text)
        var i = 0

        while i < chars.count {
            if i + 1 < chars.count, chars[i] == "*", chars[i + 1] == "*" {
                if inBold {
                    // Reset normal intensity (22m) instead of resetting all (0m)
                    result += "\u{001B}[22m"
                } else {
                    result += "\u{001B}[1m"
                }
                inBold.toggle()
                i += 2
            } else {
                result.append(chars[i])
                i += 1
            }
        }

        return result
    }

    /// Style inline code with backticks
    static func styleInlineCode(_ text: String) -> String {
        var result = ""
        var inCode = false
        var iterator = text.makeIterator()

        while let char = iterator.next() {
            if char == "`" {
                if inCode {
                    // Reset default foreground color (39m) instead of resetting all (0m)
                    result += "\u{001B}[39m"
                } else {
                    result += "\u{001B}[36m"
                }
                inCode.toggle()
            } else {
                result.append(char)
            }
        }

        return result
    }
}
