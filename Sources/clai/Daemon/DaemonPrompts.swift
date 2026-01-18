import Foundation

// MARK: - Daemon Prompt Builder

/// Builds prompts for daemon requests
enum DaemonPromptBuilder {
    static func buildCompletionPrompt(_ request: CompletionRequest) -> String {
        """
        Complete this shell command. Return ONLY completions, one per line, in format:
        completion|description

        Partial command: \(request.partial)
        Shell: \(request.shell ?? "unknown")

        Return the most likely 3-5 completions. Be concise.
        """
    }

    static func buildExplainPrompt(_ command: String) -> String {
        """
        Explain this shell command briefly (2-3 sentences max).
        If it's destructive (rm -rf, dd, etc.), say so.

        Command: \(command)

        Format:
        EXPLANATION: <brief explanation>
        DESTRUCTIVE: <yes/no>
        WARNINGS: <comma-separated warnings or "none">
        """
    }

    static func buildSuggestPrompt(_ task: String) -> String {
        """
        Suggest shell commands for this task. Return 1-3 commands.
        Format each as:
        COMMAND: <the command>
        EXPLANATION: <brief explanation>

        Task: \(task)
        """
    }
}

// MARK: - Daemon Response Parser

/// Parses LLM responses into structured results
enum DaemonResponseParser {
    static func parseCompletionSuggestions(_ response: String) -> [CompletionSuggestion] {
        response.split(separator: "\n")
            .compactMap { line -> CompletionSuggestion? in
                let parts = line.split(separator: "|", maxSplits: 1)
                guard let completion = parts.first else { return nil }
                let description = parts.count > 1 ? String(parts[1]) : nil
                return CompletionSuggestion(
                    completion: String(completion).trimmingCharacters(in: .whitespaces),
                    description: description?.trimmingCharacters(in: .whitespaces),
                    score: 1.0
                )
            }
    }

    static func parseExplanation(_ response: String) -> ExplanationResult {
        var explanation = ""
        var isDestructive = false
        var warnings: [String] = []

        for line in response.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("EXPLANATION:") {
                explanation = extractValue(from: trimmed, prefix: "EXPLANATION:")
            } else if trimmed.hasPrefix("DESTRUCTIVE:") {
                let value = extractValue(from: trimmed, prefix: "DESTRUCTIVE:").lowercased()
                isDestructive = value == "yes" || value == "true"
            } else if trimmed.hasPrefix("WARNINGS:") {
                let warningsStr = extractValue(from: trimmed, prefix: "WARNINGS:")
                if warningsStr.lowercased() != "none" {
                    warnings = warningsStr
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespaces) }
                }
            }
        }

        if explanation.isEmpty {
            explanation = response.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return ExplanationResult(
            explanation: explanation,
            isDestructive: isDestructive,
            warnings: warnings
        )
    }

    static func parseSuggestions(_ response: String) -> [CommandSuggestion] {
        var suggestions: [CommandSuggestion] = []
        var currentCommand: String?
        var currentExplanation: String?

        for line in response.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("COMMAND:") {
                if let cmd = currentCommand, let exp = currentExplanation {
                    suggestions.append(CommandSuggestion(command: cmd, explanation: exp))
                }
                currentCommand = extractValue(from: trimmed, prefix: "COMMAND:")
                currentExplanation = nil
            } else if trimmed.hasPrefix("EXPLANATION:") {
                currentExplanation = extractValue(from: trimmed, prefix: "EXPLANATION:")
            }
        }

        if let cmd = currentCommand, let exp = currentExplanation {
            suggestions.append(CommandSuggestion(command: cmd, explanation: exp))
        }

        return suggestions
    }

    private static func extractValue(from line: String, prefix: String) -> String {
        String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }
}
