import Foundation

/// Manages initial setup and model downloads
final class SetupManager: Sendable {
    private let useSmallModel: Bool
    private let verbose: Bool
    private let terminal: TerminalUI

    init(useSmallModel: Bool, verbose: Bool) {
        self.useSmallModel = useSmallModel
        self.verbose = verbose
        terminal = TerminalUI(verbose: verbose)
    }

    func run() async throws {
        terminal.showStep(1, of: 3, message: "Checking system configuration...")

        // Check platform capabilities
        let platform = PlatformDetector.current

        if verbose {
            terminal.showInfo("Platform: \(platform.description)")
        }

        // Load current config
        var config = Config.load()

        terminal.showStep(2, of: 3, message: "Detecting available providers...")

        // Check FoundationModel availability (macOS 26+)
        if platform.supportsFoundationModel {
            terminal.showSuccess("FoundationModel is available (macOS 26+)")
            terminal.showInfo("clai will use on-device Apple Intelligence by default")

            if await promptForMLXBackup() {
                try await downloadMLXModel(config: &config)
            }
            return
        }

        // Check Apple Silicon for MLX
        if platform.supportsMLX {
            terminal.showInfo("Apple Silicon detected - MLX models available")

            // Check if user already consented
            if config.mlx.downloadConsented {
                terminal.showInfo("Using previously configured MLX model")
                try await downloadMLXModel(config: &config)
            } else {
                // Prompt for download consent
                if let choice = await terminal.promptMLXDownload() {
                    try await handleDownloadChoice(choice, config: &config, platform: platform)
                }
            }
            return
        }

        // Check Ollama
        if await OllamaChecker.isAvailable() {
            terminal.showSuccess("Ollama is available")
            terminal.showInfo("clai will use Ollama for local inference")
            return
        }

        // No local providers - show setup instructions
        terminal.showStep(3, of: 3, message: "No local provider found")
        terminal.showWarning("No local LLM providers found")
        showInstallationInstructions(platform: platform)
    }

    private func handleDownloadChoice(
        _ choice: ModelDownloadChoice,
        config: inout Config,
        platform: PlatformInfo
    ) async throws {
        switch choice {
        case .downloadStandard:
            config.mlx.preferSmallModel = false
            config.mlx.downloadConsented = true
            try config.save()
            try await downloadMLXModel(config: &config)

        case .downloadSmall:
            config.mlx.preferSmallModel = true
            config.mlx.downloadConsented = true
            try config.save()
            try await downloadMLXModel(config: &config)

        case .useCloud:
            terminal.showInfo("\nTo use cloud providers, set API keys:")
            terminal.showInfo("  export ANTHROPIC_API_KEY=your-key")
            terminal.showInfo("  export OPENAI_API_KEY=your-key")

        case .skip:
            terminal.showInfo("\nYou can run 'clai setup' later to download a local model.")
            showInstallationInstructions(platform: platform)
        }
    }

    private func downloadMLXModel(config: inout Config) async throws {
        let useSmall = useSmallModel || config.mlx.preferSmallModel
        let modelId = useSmall
            ? "mlx-community/Qwen3-0.6B-4bit"
            : "mlx-community/Qwen3-4B-4bit"

        let size = useSmall ? "~400MB" : "~2.5GB"

        // Update config with selected model
        config.mlx.modelId = modelId
        try config.save()

        terminal.showInfo("Selected model: \(modelId) (\(size))")
        terminal.showInfo("Model will be downloaded on first use from Hugging Face.")
        terminal.showInfo("It will be cached at ~/.cache/huggingface/")
        terminal.showSuccess("Configuration saved successfully")
        terminal.showInfo("Run 'clai explain ls' to test (first run will download the model)")
    }

    private func promptForMLXBackup() async -> Bool {
        terminal.showInfo("\nFoundationModel provides fast, private inference.")
        terminal.showInfo("Would you like to also download an MLX model as backup?")
        return await terminal.promptYesNo("Download MLX model?")
    }

    private func showInstallationInstructions(platform: PlatformInfo) {
        terminal.showInfo("")
        terminal.showInfo("\u{001B}[1mTo use clai locally, install Ollama:\u{001B}[0m")
        terminal.showInfo("")

        if platform.isMacOS {
            terminal.showInfo("  \u{001B}[36mbrew install ollama\u{001B}[0m")
            terminal.showInfo("  # or download from https://ollama.ai")
        } else {
            terminal.showInfo("  \u{001B}[36mcurl -fsSL https://ollama.ai/install.sh | sh\u{001B}[0m")
        }

        terminal.showInfo("")
        terminal.showInfo("Then start Ollama and pull a model:")
        terminal.showInfo("  \u{001B}[36mollama serve\u{001B}[0m")
        terminal.showInfo("  \u{001B}[36mollama pull llama3.2\u{001B}[0m")

        terminal.showInfo("")
        terminal.showInfo("Alternatively, set cloud API keys:")
        terminal.showInfo("  \u{001B}[36mexport ANTHROPIC_API_KEY=your-key\u{001B}[0m")
        terminal.showInfo("  \u{001B}[36mexport OPENAI_API_KEY=your-key\u{001B}[0m")
    }
}
