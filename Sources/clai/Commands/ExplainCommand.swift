import ArgumentParser

struct ExplainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "explain",
        abstract: "Explain a CLI command in plain language",
        discussion: """
        Provides a plain-language explanation of what a command does,
        including common use cases and potential gotchas.

        Examples:
          clai explain git rebase
          clai explain "find . -name '*.swift' -exec rm {} \\;"
        """
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Command to explain (e.g., 'git rebase' or 'find . -name *.txt')")
    var command: [String] = []

    mutating func run() async throws {
        let commandString = command.joined(separator: " ")
        guard !commandString.isEmpty else {
            throw ValidationError("Please provide a command to explain")
        }

        let engine = ClaiEngine(options: options)
        try await engine.explain(command: commandString)
    }
}
