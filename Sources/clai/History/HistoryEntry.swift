import Foundation

/// A single command from shell history
struct HistoryEntry: Sendable, Equatable {
    /// The command text
    let command: String

    /// Unix timestamp when the command was executed (if available)
    let timestamp: Date?

    /// Working directory when command was run (if available)
    let workingDirectory: String?

    /// Which shell this came from
    let shell: Shell

    /// How many times this exact command appears
    var frequency: Int = 1

    enum Shell: String, Sendable {
        case zsh
        case bash
        case fish
    }
}

/// Result of parsing a history file
struct ParsedHistory: Sendable {
    let entries: [HistoryEntry]
    let shell: HistoryEntry.Shell
    let sourcePath: String
    let parseErrors: Int
}
