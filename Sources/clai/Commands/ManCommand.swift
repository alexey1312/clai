import ArgumentParser

struct ManCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "man",
        abstract: "Summarize a man page in plain language",
        discussion: """
        Provides a concise summary of a command's man page,
        highlighting the most commonly used options.

        Examples:
          clai man rsync
          clai man tar
          clai man find
        """
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Command whose man page to summarize")
    var command: String

    mutating func run() async throws {
        let engine = ClaiEngine(options: options)
        try await engine.summarizeMan(command: command)
    }
}
