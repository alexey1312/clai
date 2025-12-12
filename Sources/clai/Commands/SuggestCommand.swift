import ArgumentParser

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
        let taskString = task.joined(separator: " ")
        guard !taskString.isEmpty else {
            throw ValidationError("Please describe the task you want to accomplish")
        }

        let engine = ClaiEngine(options: options)
        try await engine.suggest(task: taskString)
    }
}
