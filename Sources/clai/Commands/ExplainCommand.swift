import ArgumentParser
import Foundation

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
        var commandString = command.joined(separator: " ")

        // If no command provided, try interactive prompt (TTY only)
        if commandString.isEmpty {
            guard isatty(STDIN_FILENO) != 0 else {
                throw ValidationError("Please provide a command to explain")
            }

            let terminal = TerminalUI()
            terminal.showPrompt("Enter command to explain: ")

            guard let input = readLine(),
                  !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                print()
                print("No command provided. Try:")
                print("  clai git rebase          Explain a command")
                print("  clai suggest \"task\"      Find commands for a task")
                print("  clai --help              Show all options")
                return
            }

            commandString = input.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let engine = ClaiEngine(options: options)
        try await engine.explain(command: commandString)
    }
}
