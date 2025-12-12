import Foundation

/// Builds prompts for different clai operations
enum PromptBuilder {
    /// Build prompt for explaining a command
    static func buildExplainPrompt(command: String, context: CommandContext) -> String {
        var prompt = """
        You are a helpful CLI assistant. Explain the following command in plain language.
        Be concise but thorough. Include:
        - What the command does
        - What each argument/flag means
        - Common use cases
        - Potential gotchas or warnings

        Command: \(command)

        """

        if let help = context.helpOutput {
            prompt += "\n--help output:\n\(help.prefix(2000))\n"
        }

        if let man = context.manPageContent {
            prompt += "\nMan page excerpt:\n\(man.prefix(3000))\n"
        }

        prompt += "\nProvide a clear, beginner-friendly explanation."

        return prompt
    }

    /// Build prompt for suggesting commands
    static func buildSuggestPrompt(task: String) -> String {
        """
        You are a helpful CLI assistant. The user wants to accomplish the following task:

        Task: \(task)

        Suggest one or more CLI commands that accomplish this task. For each suggestion:
        1. Show the exact command
        2. Explain what it does
        3. Note any prerequisites or warnings

        Focus on common Unix/macOS commands. Prefer simple, safe solutions.
        """
    }

    /// Build prompt for showing examples
    static func buildExamplesPrompt(command: String, context: CommandContext) -> String {
        var prompt = """
        You are a helpful CLI assistant. Provide practical, copy-pasteable examples
        for the following command:

        Command: \(command)

        """

        if let help = context.helpOutput {
            prompt += "\n--help output:\n\(help.prefix(2000))\n"
        }

        prompt += """

        Provide 5-7 examples covering:
        - Basic usage
        - Common options
        - Real-world scenarios

        Format each example as:
        ```
        command --flags arguments
        ```
        Brief explanation of what this does.
        """

        return prompt
    }

    /// Build prompt for summarizing man pages
    static func buildManSummaryPrompt(command: String, manContent: String?) -> String {
        var prompt = """
        You are a helpful CLI assistant. Summarize the man page for: \(command)

        """

        if let man = manContent {
            prompt += "Man page content:\n\(man.prefix(8000))\n\n"
        }

        prompt += """
        Provide a concise summary including:
        1. What the command does (1-2 sentences)
        2. Most commonly used flags (top 5-10)
        3. Common usage patterns
        4. Important warnings or notes

        Keep it practical and beginner-friendly.
        """

        return prompt
    }
}
