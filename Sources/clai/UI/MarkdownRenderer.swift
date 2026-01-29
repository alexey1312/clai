import Foundation

/// Renders markdown content to styled terminal output
struct MarkdownRenderer {
    /// Callback for rendering tables externally (e.g., via Noora)
    typealias TableHandler = (_ headers: [String], _ rows: [[String]]) -> Void

    private let terminalWidth: Int
    private let tableHandler: TableHandler?
    private var activeCallout: CalloutStyle?

    init(terminalWidth: Int, tableHandler: TableHandler? = nil) {
        self.terminalWidth = terminalWidth
        self.tableHandler = tableHandler
        activeCallout = nil
    }

    /// Render markdown text to terminal
    mutating func render(_ response: String) {
        let lines = response.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var inCodeBlock = false
        var lineIndex = 0

        while lineIndex < lines.count {
            let lineStr = lines[lineIndex]
            let trimmed = lineStr.trimmingCharacters(in: .whitespaces)

            // Table detection
            if !inCodeBlock && trimmed.contains("|") && lineIndex + 1 < lines.count {
                let nextLine = lines[lineIndex + 1].trimmingCharacters(in: .whitespaces)
                let isDelimiter = nextLine.contains("|") && nextLine.contains("-") && nextLine
                    .allSatisfy { "|- :".contains($0) }

                if isDelimiter {
                    activeCallout = nil
                    var tableLines = [lineStr]
                    lineIndex += 1
                    tableLines.append(lines[lineIndex])
                    lineIndex += 1

                    while lineIndex < lines.count {
                        let nextRow = lines[lineIndex]
                        if nextRow.trimmingCharacters(in: .whitespaces).contains("|") {
                            tableLines.append(nextRow)
                            lineIndex += 1
                        } else {
                            break
                        }
                    }
                    renderTable(tableLines)
                    continue
                }
            }

            // Code blocks (```)
            if lineStr.hasPrefix("```") {
                activeCallout = nil
                if !inCodeBlock {
                    inCodeBlock = true
                    renderCodeBlockStart(lineStr)
                } else {
                    inCodeBlock = false
                    renderCodeBlockEnd()
                }
                lineIndex += 1
                continue
            }

            // Inside code block
            if inCodeBlock {
                print("\(Theme.muted)│\(Theme.reset) \(Theme.code)\(lineStr)\(Theme.reset)")
                lineIndex += 1
                continue
            }

            // Horizontal Rule (---, ***, ___)
            if trimmed.count >= 3, Set(trimmed).count == 1,
               trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("_")
            {
                activeCallout = nil
                let line = String(repeating: "─", count: terminalWidth)
                print("\(Theme.muted)\(line)\(Theme.reset)")
                lineIndex += 1
                continue
            }

            // Render inline content
            renderInlineContent(lineStr, trimmed: trimmed)
            lineIndex += 1
        }
    }

    // MARK: - Code Blocks

    private func renderCodeBlockStart(_ lineStr: String) {
        let lang = String(lineStr.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        let label = lang.isEmpty ? "" : " \(lang) "
        let prefix = "╭───"

        if label.isEmpty {
            let line = String(repeating: "─", count: max(0, terminalWidth - 1))
            print("\(Theme.muted)╭\(line)\(Theme.reset)")
        } else {
            let remaining = max(0, terminalWidth - prefix.count - label.count)
            let suffix = String(repeating: "─", count: remaining)
            print("\(Theme.muted)\(prefix)\(Theme.accent)\(label)\(Theme.muted)\(suffix)\(Theme.reset)")
        }
    }

    private func renderCodeBlockEnd() {
        let line = String(repeating: "─", count: max(0, terminalWidth - 1))
        print("\(Theme.muted)╰\(line)\(Theme.reset)")
    }

    // MARK: - Inline Content

    private mutating func renderInlineContent(_ lineStr: String, trimmed: String) {
        // Headers (# ## ###)
        if lineStr.hasPrefix("### ") {
            activeCallout = nil
            let content = TextStyler.apply(String(lineStr.dropFirst(4)), baseReset: Theme.header3)
            print("\(Theme.header3)\(content)\(Theme.reset)")
            return
        }
        if lineStr.hasPrefix("## ") {
            activeCallout = nil
            let content = TextStyler.apply(String(lineStr.dropFirst(3)), baseReset: Theme.header2)
            print("\(Theme.header2)\(content)\(Theme.reset)")
            return
        }
        if lineStr.hasPrefix("# ") {
            activeCallout = nil
            let content = TextStyler.apply(String(lineStr.dropFirst(2)), baseReset: Theme.header1)
            print("\(Theme.header1)\(content)\(Theme.reset)")
            return
        }
        // Bullet points
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            activeCallout = nil
            renderBulletPoint(lineStr, trimmed: trimmed)
            return
        }
        // Blockquotes (> )
        if lineStr.hasPrefix("> ") {
            renderBlockquote(lineStr)
            return
        }
        // Numbered lists
        if let match = lineStr.range(of: #"^\s*\d+\.\s+"#, options: .regularExpression) {
            activeCallout = nil
            renderNumberedList(lineStr, match: match)
            return
        }
        // Regular text
        activeCallout = nil
        print(TextStyler.apply(lineStr))
    }

    private func renderBulletPoint(_ lineStr: String, trimmed: String) {
        let indent = lineStr.prefix(while: { $0 == " " }).count
        let content = String(trimmed.dropFirst(2))
        let padding = String(repeating: " ", count: 2 + indent)
        let level = indent / 2
        let bullets = ["•", "◦", "▪"]
        let bullet = bullets[min(level, bullets.count - 1)]
        print("\(padding)\(Theme.accent)\(bullet)\(Theme.reset) \(TextStyler.apply(content))")
    }

    private mutating func renderBlockquote(_ lineStr: String) {
        let content = String(lineStr.dropFirst(2))

        // Check for callout definition (e.g. "> [!NOTE]")
        if let callout = CalloutStyle(from: content) {
            activeCallout = callout
            let header =
                "  \(callout.color)│\(Theme.reset) " +
                "\(callout.color)\(Theme.bold)\(callout.icon) \(callout.title)\(Theme.reset)"
            print(header)
            return
        }

        if let callout = activeCallout {
            // Callout content
            print("  \(callout.color)│\(Theme.reset) \(TextStyler.apply(content))")
        } else {
            // Standard blockquote
            print(
                "  \(Theme.muted)│\(Theme.defaultColor) \(Theme.italic)" +
                    "\(TextStyler.apply(content))\(Theme.italicOff)"
            )
        }
    }

    private func renderNumberedList(_ lineStr: String, match: Range<String.Index>) {
        let prefix = lineStr[match]
        let indent = prefix.prefix(while: { $0 == " " }).count
        let numberPart = prefix.trimmingCharacters(in: .whitespaces)
        let content = String(lineStr[match.upperBound...])
        let padding = String(repeating: " ", count: 2 + indent)
        print("\(padding)\(Theme.accent)\(numberPart)\(Theme.reset) \(TextStyler.apply(content))")
    }

    // MARK: - Tables

    private func renderTable(_ lines: [String]) {
        guard lines.count >= 2 else { return }

        // Use box renderer if no external handler is provided
        let keepMarkdown = tableHandler == nil
        let (headers, rows) = parseMarkdownTable(lines, keepMarkdown: keepMarkdown)

        guard !headers.isEmpty else { return }

        if let tableHandler {
            // Delegate to external renderer (e.g., Noora)
            tableHandler(headers, rows)
        } else {
            // Internal Box Drawing renderer
            renderBoxedTable(headers: headers, rows: rows)
        }
    }

    /// Parse markdown table into structured data
    private func parseMarkdownTable(_ lines: [String], keepMarkdown: Bool) -> (headers: [String], rows: [[String]]) {
        let headerRaw = splitRow(lines[0])
        let bodyRaw = lines.dropFirst(2).map(splitRow)

        // Strip markdown formatting unless requested to keep
        let headers = headerRaw.map { keepMarkdown ? $0 : stripMarkdown($0) }
        let colCount = headers.count

        let rows = bodyRaw.map { row -> [String] in
            let padded = row + Array(repeating: "", count: max(0, colCount - row.count))
            return Array(padded.prefix(colCount).map { keepMarkdown ? $0 : stripMarkdown($0) })
        }

        return (headers, rows)
    }

    private func splitRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var parts = trimmed.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if trimmed.hasPrefix("|"), parts.first?.isEmpty == true { parts.removeFirst() }
        if trimmed.hasSuffix("|"), parts.last?.isEmpty == true { parts.removeLast() }
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Remove markdown inline formatting (bold, italic, code)
    private func stripMarkdown(_ text: String) -> String {
        var result = text
        // Remove bold (**text** or __text__)
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        // Remove inline code (`code`)
        result = result.replacingOccurrences(of: "`", with: "")
        // Note: single underscores for italic are tricky (could be part of identifiers)
        // so we only remove double underscores above
        return result
    }

    /// Render table using box drawing characters and Theme colors
    private func renderBoxedTable(headers: [String], rows: [[String]]) {
        let colCount = headers.count
        guard colCount > 0 else { return }

        // Apply styles and calculate visible widths
        let styledHeaders = headers.map { header -> String in
            let styled = TextStyler.apply(header, baseReset: Theme.bold)
            return Theme.applyBold(styled)
        }

        let styledRows = rows.map { row in
            row.map { TextStyler.apply($0) }
        }

        var widths = styledHeaders.map { Theme.visibleWidth($0) }
        for row in styledRows {
            for (colIndex, cell) in row.enumerated() where colIndex < widths.count {
                widths[colIndex] = max(widths[colIndex], Theme.visibleWidth(cell))
            }
        }

        // Borders
        let border = Theme.muted
        let reset = Theme.reset

        // Top border: ╭───┬───╮
        let topBorder = widths.map { String(repeating: "─", count: $0 + 2) }.joined(separator: "┬")
        print("\(border)╭\(topBorder)╮\(reset)")

        // Header row
        printBoxedRow(styledHeaders, widths: widths, border: border, reset: reset)

        // Middle separator: ├───┼───┤
        let midBorder = widths.map { String(repeating: "─", count: $0 + 2) }.joined(separator: "┼")
        print("\(border)├\(midBorder)┤\(reset)")

        // Rows
        for row in styledRows {
            printBoxedRow(row, widths: widths, border: border, reset: reset)
        }

        // Bottom border: ╰───┴───╯
        let bottomBorder = widths.map { String(repeating: "─", count: $0 + 2) }.joined(separator: "┴")
        print("\(border)╰\(bottomBorder)╯\(reset)")
    }

    private func printBoxedRow(_ cells: [String], widths: [Int], border: String, reset: String) {
        var line = "\(border)│\(reset)"
        for (index, cell) in cells.enumerated() {
            let width = widths[index]
            let visibleLen = Theme.visibleWidth(cell)
            let padding = String(repeating: " ", count: width - visibleLen)
            line += " \(cell)\(padding) \(border)│\(reset)"
        }
        print(line)
    }
}

// MARK: - Supporting Types

/// Callout style for blockquotes (e.g., > [!NOTE])
struct CalloutStyle {
    let icon: String
    let color: String
    let title: String

    init?(from text: String) {
        guard text.hasPrefix("[!") else { return nil }
        guard let closingBracket = text.firstIndex(of: "]") else { return nil }

        // Extract type between [ and ]
        let typeRange = text.index(after: text.startIndex) ..< closingBracket
        let type = String(text[typeRange]).uppercased() // e.g., "!WARNING"

        guard type.hasPrefix("!") else { return nil }
        let key = String(type.dropFirst()) // "WARNING"

        switch key {
        case "NOTE": self.init(icon: "ℹ", color: Theme.blue, title: "NOTE")
        case "TIP": self.init(icon: "💡", color: Theme.success, title: "TIP")
        case "IMPORTANT": self.init(icon: "🔥", color: Theme.magenta, title: "IMPORTANT")
        case "WARNING": self.init(icon: "⚠", color: Theme.warning, title: "WARNING")
        case "CAUTION": self.init(icon: "⚡", color: Theme.error, title: "CAUTION")
        default: return nil
        }
    }

    init(icon: String, color: String, title: String) {
        self.icon = icon
        self.color = color
        self.title = title
    }
}
