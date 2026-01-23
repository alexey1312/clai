enum Theme {
    // MARK: - ANSI Base Codes

    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let boldOff = "\u{001B}[22m"
    static let italic = "\u{001B}[3m"
    static let italicOff = "\u{001B}[23m"

    // Foreground Colors
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan = "\u{001B}[36m"
    static let defaultColor = "\u{001B}[39m"
    static let gray = "\u{001B}[90m"

    // MARK: - Semantic Styles

    /// Error messages
    static let error = red
    /// Success messages
    static let success = green
    /// Warning messages
    static let warning = yellow
    /// Information messages
    static let info = defaultColor

    /// Primary accent color (used for prompt indices, inline code)
    static let accent = cyan
    /// Muted elements (brackets, code fences, blockquote bars)
    static let muted = gray

    /// Inline code style
    static let code = cyan

    // Headers
    static let header1 = bold + green
    static let header2 = bold + yellow
    static let header3 = bold + cyan

    /// Apply bold style
    static func applyBold(_ text: String) -> String {
        "\(bold)\(text)\(boldOff)"
    }

    /// Apply italic style
    static func applyItalic(_ text: String) -> String {
        "\(italic)\(text)\(italicOff)"
    }

    /// Apply color
    static func apply(_ text: String, color: String) -> String {
        "\(color)\(text)\(defaultColor)"
    }
}
