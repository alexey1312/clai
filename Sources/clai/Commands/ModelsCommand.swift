import ArgumentParser
import Foundation

/// Command for managing local LLM models
struct ModelsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "models",
        abstract: "Manage local LLM models (MLX and Ollama)",
        discussion: """
        Interactive model management for local LLMs.

        Running 'clai models' opens an interactive menu to:
        - View downloaded and available models
        - Set default model
        - Download new MLX models
        - Delete MLX models to free space

        Examples:
          clai models          Interactive model management
          clai models list     List all models (non-interactive)
        """,
        subcommands: [ListModelsCommand.self],
        defaultSubcommand: nil
    )

    @Flag(name: .shortAndLong, help: "Show detailed output")
    var verbose = false

    mutating func run() async throws {
        // Check if running in a terminal
        guard isatty(STDIN_FILENO) != 0 else {
            // Non-interactive mode, fall back to list
            let manager = ModelsManager(verbose: verbose)
            await manager.printList()
            return
        }

        let manager = ModelsManager(verbose: verbose)
        try await manager.runInteractive()
    }
}

/// Subcommand to list models non-interactively
struct ListModelsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all models"
    )

    @Flag(name: .shortAndLong, help: "Show detailed output")
    var verbose = false

    mutating func run() async throws {
        let manager = ModelsManager(verbose: verbose)
        await manager.printList()
    }
}
