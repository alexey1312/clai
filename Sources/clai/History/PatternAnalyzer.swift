import Foundation

/// Analyzes command history for patterns and optimization opportunities
final class PatternAnalyzer: Sendable {
    private let store: HistoryStore

    init(store: HistoryStore) {
        self.store = store
    }

    /// Analyze a specific command for optimization opportunities
    func analyze(command: String) throws -> CommandAnalysis {
        // Find this command in history
        let results = try store.searchExact(pattern: command, limit: 100)

        // Find exact matches
        let exactMatches = results.filter { $0.command == command }
        let frequency = exactMatches.map(\.frequency).reduce(0, +)

        // Find similar commands (same base command)
        let baseCommand = extractBaseCommand(command)
        let similar = results.filter {
            $0.command != command && extractBaseCommand($0.command) == baseCommand
        }

        // Calculate suggestions
        var suggestions: [OptimizationSuggestion] = []

        // Alias suggestion for frequently used commands
        if frequency >= 3 && command.count > 15 {
            let aliasName = generateAliasName(for: command)
            suggestions.append(OptimizationSuggestion(
                type: .alias,
                description: "Consider creating an alias for this frequently used command",
                code: "alias \(aliasName)='\(escapeForAlias(command))'"
            ))
        }

        // Shell function suggestion for complex commands
        if command.contains("|") || command.contains("&&") || command.contains(";") {
            if frequency >= 2 {
                let funcName = generateFunctionName(for: command)
                suggestions.append(OptimizationSuggestion(
                    type: .shellFunction,
                    description: "Complex command could be wrapped in a shell function",
                    code: generateShellFunction(name: funcName, command: command)
                ))
            }
        }

        // Similar command variations
        if !similar.isEmpty {
            let variations = similar.prefix(3).map(\.command)
            suggestions.append(OptimizationSuggestion(
                type: .variation,
                description: "You have similar commands in history",
                code: variations.joined(separator: "\n")
            ))
        }

        return CommandAnalysis(
            command: command,
            frequency: frequency,
            similar: similar.map(\.command),
            suggestions: suggestions
        )
    }

    /// Find frequently used commands that could be aliases
    func findAliasCandidates(minFrequency: Int = 3, minLength: Int = 15) throws -> [AliasCandidate] {
        let frequent = try store.mostFrequent(limit: 100)

        return frequent
            .filter { $0.frequency >= minFrequency && $0.command.count >= minLength }
            .map { result in
                AliasCandidate(
                    command: result.command,
                    frequency: result.frequency,
                    suggestedAlias: generateAliasName(for: result.command),
                    aliasCode: "alias \(generateAliasName(for: result.command))='\(escapeForAlias(result.command))'"
                )
            }
    }

    /// Detect command sequences (commands often run together)
    func findSequences(minOccurrences: Int = 3) throws -> [CommandSequence] {
        // This is a simplified implementation
        // A full implementation would need timestamp-based sequence detection
        // For now, we'll just return an empty array
        // TODO: Implement proper sequence detection with timestamps
        []
    }

    // MARK: - Private Helpers

    private func extractBaseCommand(_ command: String) -> String {
        // Extract the main command (first word)
        let trimmed = command.trimmingCharacters(in: .whitespaces)

        // Handle sudo prefix
        var cmd = trimmed
        if cmd.hasPrefix("sudo ") {
            cmd = String(cmd.dropFirst(5))
        }

        // Get first word
        if let spaceIndex = cmd.firstIndex(of: " ") {
            return String(cmd[..<spaceIndex])
        }
        return cmd
    }

    private func generateAliasName(for command: String) -> String {
        let base = extractBaseCommand(command)

        // Extract key flags/words for the alias name
        let words = command.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty && !$0.hasPrefix("-") }

        if words.count <= 1 {
            return base
        }

        // Create abbreviation from first letters
        let abbrev = words.prefix(3)
            .compactMap(\.first)
            .map { String($0).lowercased() }
            .joined()

        return abbrev.isEmpty ? base : abbrev
    }

    private func generateFunctionName(for command: String) -> String {
        let base = extractBaseCommand(command)
        return "\(base)_workflow"
    }

    private func escapeForAlias(_ command: String) -> String {
        command.replacingOccurrences(of: "'", with: "'\\''")
    }

    private func generateShellFunction(name: String, command: String) -> String {
        """
        \(name)() {
            \(command)
        }
        """
    }
}

// MARK: - Supporting Types

/// Analysis result for a specific command
struct CommandAnalysis: Sendable {
    let command: String
    let frequency: Int
    let similar: [String]
    let suggestions: [OptimizationSuggestion]

    var hasOptimizations: Bool {
        !suggestions.isEmpty
    }
}

/// A suggestion for optimizing a command
struct OptimizationSuggestion: Sendable {
    enum SuggestionType: String, Sendable {
        case alias = "Alias"
        case shellFunction = "Shell Function"
        case variation = "Variations"
        case flag = "Flag Suggestion"
    }

    let type: SuggestionType
    let description: String
    let code: String
}

/// A candidate command for aliasing
struct AliasCandidate: Sendable {
    let command: String
    let frequency: Int
    let suggestedAlias: String
    let aliasCode: String
}

/// A detected sequence of commands
struct CommandSequence: Sendable {
    let commands: [String]
    let occurrences: Int
    let suggestedFunction: String
}
