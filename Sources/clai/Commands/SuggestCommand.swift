import ArgumentParser
import Foundation

struct SuggestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "suggest",
        abstract: "Suggest CLI commands for a task",
        discussion: """
        Describes a task in natural language and get command suggestions.

        Examples:
          clai suggest "find large files in current directory"
          clai suggest "compress a folder into a tar.gz"
          clai suggest "find all Swift files modified today"
        """
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Natural language description of the task")
    var task: [String] = []

    mutating func run() async throws {
        var taskString = task.joined(separator: " ")

        // If no task provided, try interactive prompt (TTY only)
        if taskString.isEmpty {
            guard isatty(STDIN_FILENO) != 0 else {
                throw ValidationError("Please describe the task you want to accomplish")
            }

            let terminal = TerminalUI()
            terminal.showPrompt("Enter task to accomplish: ")

            guard let input = readLine(),
                  !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                print()
                print("No task provided. Try:")
                print("  clai suggest \"find large files\"   Get command suggestions")
                print("  clai explain ls                 Explain a command")
                print("  clai --help                     Show all options")
                return
            }

            taskString = input.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let engine = ClaiEngine(options: options)
        try await engine.suggest(task: taskString)
    }
}
