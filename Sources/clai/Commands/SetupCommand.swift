import ArgumentParser

struct SetupCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setup",
        abstract: "Set up clai and download required models",
        discussion: """
        Pre-downloads MLX models and verifies provider configuration.
        Run this to prepare clai for offline use.

        On Apple Silicon, downloads the configured MLX model (~2.5GB by default).
        On other systems, verifies Ollama or cloud provider availability.
        """
    )

    @Flag(name: .long, help: "Download smaller model (~400MB instead of ~2.5GB)")
    var small = false

    @Flag(name: .long, help: "Show detailed progress")
    var verbose = false

    mutating func run() async throws {
        let setup = SetupManager(useSmallModel: small, verbose: verbose)
        try await setup.run()
    }
}
