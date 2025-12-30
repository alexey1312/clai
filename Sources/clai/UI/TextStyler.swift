/// Helper for applying inline styles to terminal text
enum TextStyler {
    /// Apply all inline styles (bold, italic, code)
    /// Uses a single-pass parser to handle nesting and precedence correctly.
    static func apply(_ text: String) -> String {
        var result = ""
        let chars = Array(text)
        var i = 0
        var inBold = false
        var inItalic = false

        while i < chars.count {
            // Code block (`...`) - Highest precedence, consumes content literally
            if chars[i] == "`" {
                // Find end of code block
                var j = i + 1
                while j < chars.count {
                    if chars[j] == "`" { break }
                    j += 1
                }

                // If we found an end backtick
                if j < chars.count {
                    // Output code block with color
                    result += "\u{001B}[36m" // Cyan
                    result += String(chars[i+1..<j])
                    result += "\u{001B}[39m" // Reset Default FG
                    i = j + 1
                } else {
                    // Unclosed code block, treat start as literal
                    result.append(chars[i])
                    i += 1
                }
            }
            // Bold (**...**)
            else if i + 1 < chars.count, chars[i] == "*", chars[i + 1] == "*" {
                if inBold {
                    result += "\u{001B}[22m" // Bold off
                } else {
                    result += "\u{001B}[1m" // Bold on
                }
                inBold.toggle()
                i += 2
            }
            // Italic (_..._)
            else if chars[i] == "_" {
                let prev = i > 0 ? chars[i-1] : " "
                let next = i + 1 < chars.count ? chars[i+1] : " "

                let isPrevAlpha = prev.isLetter || prev.isNumber
                let isNextAlpha = next.isLetter || next.isNumber

                // Toggle Off: text_ or punct_
                // We only require that the NEXT character is NOT alphanumeric.
                // This allows closing after punctuation (e.g. "_Stop!_") while protecting snake_case (e.g. "snake_case" -> next 'c' is alpha)
                if inItalic && !isNextAlpha {
                    result += "\u{001B}[23m"
                    inItalic = false
                    i += 1
                }
                // Toggle On: _text
                // We require PREV char is NOT alphanumeric (space/start/punct) and NEXT IS alphanumeric.
                else if !inItalic && !isPrevAlpha && isNextAlpha {
                    result += "\u{001B}[3m"
                    inItalic = true
                    i += 1
                }
                else {
                    result.append(chars[i])
                    i += 1
                }
            }
            // Regular character
            else {
                result.append(chars[i])
                i += 1
            }
        }

        // Close any open styles at the end
        if inBold { result += "\u{001B}[22m" }
        if inItalic { result += "\u{001B}[23m" }

        return result
    }
}
