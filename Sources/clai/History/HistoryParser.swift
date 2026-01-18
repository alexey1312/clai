import Foundation

/// Protocol for shell-specific history parsers
protocol HistoryParser: Sendable {
    /// Parse a history file and return entries
    func parse(contents: String, sourcePath: String) -> ParsedHistory
}

/// Factory for creating the appropriate parser based on shell
enum HistoryParserFactory {
    static func parser(for shell: HistoryEntry.Shell) -> HistoryParser {
        switch shell {
        case .zsh:
            ZshHistoryParser()
        case .bash:
            BashHistoryParser()
        case .fish:
            FishHistoryParser()
        }
    }

    /// Detect shell from file path
    static func detectShell(from path: String) -> HistoryEntry.Shell? {
        let filename = (path as NSString).lastPathComponent
        let lowercased = filename.lowercased()

        if lowercased.contains("zsh") {
            return .zsh
        } else if lowercased.contains("bash") {
            return .bash
        } else if lowercased.contains("fish") {
            return .fish
        }

        return nil
    }

    /// Get default history paths for each shell
    static func defaultHistoryPaths() -> [(path: String, shell: HistoryEntry.Shell)] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            ("\(home)/.zsh_history", .zsh),
            ("\(home)/.bash_history", .bash),
            ("\(home)/.local/share/fish/fish_history", .fish),
        ]
    }
}

// MARK: - Zsh History Parser

/// Parser for zsh extended history format
/// Format: `: timestamp:duration;command` or just `command`
struct ZshHistoryParser: HistoryParser {
    func parse(contents: String, sourcePath: String) -> ParsedHistory {
        var entries: [HistoryEntry] = []
        var parseErrors = 0

        // Zsh history can have multiline commands with backslash continuation
        let lines = contents.components(separatedBy: "\n")
        var currentCommand = ""
        var currentTimestamp: Date?

        for line in lines {
            // Skip empty lines
            guard !line.isEmpty else { continue }

            // Check for extended history format: `: timestamp:duration;command`
            if line.hasPrefix(": ") {
                // Try to parse extended format
                if let entry = parseExtendedLine(line) {
                    // If we have a pending multiline command, save it first
                    if !currentCommand.isEmpty {
                        entries.append(HistoryEntry(
                            command: currentCommand,
                            timestamp: currentTimestamp,
                            workingDirectory: nil,
                            shell: .zsh
                        ))
                        currentCommand = ""
                    }
                    currentTimestamp = entry.timestamp
                    currentCommand = entry.command
                } else {
                    parseErrors += 1
                }
            } else if line.hasPrefix("\\") || currentCommand.hasSuffix("\\") {
                // Continuation of multiline command
                if currentCommand.hasSuffix("\\") {
                    currentCommand = String(currentCommand.dropLast()) + "\n" + line
                } else {
                    currentCommand += "\n" + line
                }
            } else if currentCommand.isEmpty {
                // Simple format (no timestamp)
                currentCommand = line
            } else {
                // Save current command and start new one
                entries.append(HistoryEntry(
                    command: currentCommand,
                    timestamp: currentTimestamp,
                    workingDirectory: nil,
                    shell: .zsh
                ))
                currentCommand = line
                currentTimestamp = nil
            }
        }

        // Don't forget the last command
        if !currentCommand.isEmpty {
            entries.append(HistoryEntry(
                command: currentCommand,
                timestamp: currentTimestamp,
                workingDirectory: nil,
                shell: .zsh
            ))
        }

        return ParsedHistory(
            entries: entries,
            shell: .zsh,
            sourcePath: sourcePath,
            parseErrors: parseErrors
        )
    }

    private func parseExtendedLine(_ line: String) -> (command: String, timestamp: Date?)? {
        // Format: `: timestamp:duration;command`
        // Example: `: 1699123456:0;git commit -m "fix bug"`

        guard line.hasPrefix(": ") else { return nil }

        let rest = String(line.dropFirst(2))

        // Find the semicolon that separates metadata from command
        guard let semicolonIndex = rest.firstIndex(of: ";") else {
            // No semicolon, treat the whole thing as command
            return (command: rest, timestamp: nil)
        }

        let metadata = String(rest[..<semicolonIndex])
        let command = String(rest[rest.index(after: semicolonIndex)...])

        // Parse timestamp from metadata (format: timestamp:duration)
        let parts = metadata.split(separator: ":")
        guard let timestampStr = parts.first,
              let timestamp = TimeInterval(timestampStr)
        else {
            return (command: command, timestamp: nil)
        }

        return (command: command, timestamp: Date(timeIntervalSince1970: timestamp))
    }
}

// MARK: - Bash History Parser

/// Parser for bash history format
/// Simple format: one command per line (no timestamps unless HISTTIMEFORMAT is set)
struct BashHistoryParser: HistoryParser {
    func parse(contents: String, sourcePath: String) -> ParsedHistory {
        var entries: [HistoryEntry] = []
        var parseErrors = 0
        var pendingTimestamp: Date?

        let lines = contents.components(separatedBy: "\n")

        for line in lines {
            // Skip empty lines
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            // Check for timestamp line (starts with #)
            // Format: #1699123456
            if line.hasPrefix("#") {
                let timestampStr = String(line.dropFirst())
                if let timestamp = TimeInterval(timestampStr) {
                    pendingTimestamp = Date(timeIntervalSince1970: timestamp)
                } else {
                    // Not a timestamp, might be a comment or special line
                    parseErrors += 1
                }
                continue
            }

            entries.append(HistoryEntry(
                command: line,
                timestamp: pendingTimestamp,
                workingDirectory: nil,
                shell: .bash
            ))
            pendingTimestamp = nil
        }

        return ParsedHistory(
            entries: entries,
            shell: .bash,
            sourcePath: sourcePath,
            parseErrors: parseErrors
        )
    }
}

// MARK: - Fish History Parser

/// Parser for fish history format (YAML)
/// Format:
/// ```yaml
/// - cmd: git commit -m "fix bug"
///   when: 1699123456
///   paths:
///     - /Users/alex/project
/// ```
struct FishHistoryParser: HistoryParser {
    func parse(contents: String, sourcePath: String) -> ParsedHistory {
        var entries: [HistoryEntry] = []
        var parseErrors = 0

        var currentCommand: String?
        var currentTimestamp: Date?
        var currentPaths: [String] = []
        var inPaths = false

        let lines = contents.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // New entry starts with "- cmd:"
            if trimmed.hasPrefix("- cmd:") {
                // Save previous entry if exists
                if let cmd = currentCommand {
                    entries.append(HistoryEntry(
                        command: cmd,
                        timestamp: currentTimestamp,
                        workingDirectory: currentPaths.first,
                        shell: .fish
                    ))
                }

                // Parse new command
                let value = extractYamlValue(trimmed, key: "- cmd:")
                currentCommand = unescapeFishCommand(value)
                currentTimestamp = nil
                currentPaths = []
                inPaths = false
            } else if trimmed.hasPrefix("when:") {
                let value = extractYamlValue(trimmed, key: "when:")
                if let timestamp = TimeInterval(value) {
                    currentTimestamp = Date(timeIntervalSince1970: timestamp)
                }
                inPaths = false
            } else if trimmed.hasPrefix("paths:") {
                inPaths = true
            } else if inPaths, trimmed.hasPrefix("- ") {
                let path = String(trimmed.dropFirst(2))
                currentPaths.append(path)
            } else if !trimmed.isEmpty, !trimmed.hasPrefix("#") {
                // Unknown line format
                parseErrors += 1
            }
        }

        // Don't forget the last entry
        if let cmd = currentCommand {
            entries.append(HistoryEntry(
                command: cmd,
                timestamp: currentTimestamp,
                workingDirectory: currentPaths.first,
                shell: .fish
            ))
        }

        return ParsedHistory(
            entries: entries,
            shell: .fish,
            sourcePath: sourcePath,
            parseErrors: parseErrors
        )
    }

    private func extractYamlValue(_ line: String, key: String) -> String {
        guard line.hasPrefix(key) else { return "" }
        return String(line.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
    }

    /// Unescape fish history command format
    /// Fish escapes backslashes and newlines
    private func unescapeFishCommand(_ command: String) -> String {
        var result = command

        // Fish uses \\n for newlines
        result = result.replacingOccurrences(of: "\\n", with: "\n")
        // And \\\\ for backslashes
        result = result.replacingOccurrences(of: "\\\\", with: "\\")

        return result
    }
}
