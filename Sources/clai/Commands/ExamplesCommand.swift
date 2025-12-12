import ArgumentParser

struct ExamplesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "examples",
        abstract: "Show practical usage examples for a command",
        discussion: """
        Provides copy-pasteable examples for common use cases.

        Examples:
          clai examples tar
          clai examples git
          clai examples rsync
        """
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Command to show examples for")
    var command: String

    mutating func run() async throws {
        let engine = ClaiEngine(options: options)
        try await engine.examples(command: command)
    }
}
