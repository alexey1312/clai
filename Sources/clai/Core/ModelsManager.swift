import Foundation

#if canImport(MLXLLM)
    import AnyLanguageModel
#endif

/// Errors for model management operations
enum ModelsError: Error, LocalizedError {
    case mlxNotAvailable

    var errorDescription: String? {
        switch self {
        case .mlxNotAvailable:
            "MLX is not available on this platform. Requires Apple Silicon Mac."
        }
    }
}

/// Action to perform on models
enum ModelAction: String, CaseIterable {
    case setDefault = "Set default model"
    case download = "Download MLX model"
    case delete = "Delete MLX model"
    case exit = "Exit"
}

/// Model selection for setting default
enum ModelSelection: Sendable {
    case mlx(modelId: String)
    case ollama(model: String)
}

/// Manager for model operations
final class ModelsManager {
    private let terminal: TerminalUI
    private let verbose: Bool

    init(verbose: Bool = false) {
        terminal = TerminalUI(verbose: verbose)
        self.verbose = verbose
    }

    // MARK: - Discovery

    /// Get all MLX models (downloaded + available from curated list)
    func getAllMLXModels() -> [MLXModelInfo] {
        let config = Config.load()
        let downloaded = MLXModelDiscovery.discoverDownloaded()
        return CuratedModels.getModelsWithStatus(
            downloaded: downloaded,
            defaultModelId: config.mlx.modelId
        )
    }

    /// Get only downloaded MLX models
    func getDownloadedMLXModels() -> [MLXModelInfo] {
        let config = Config.load()
        var models = MLXModelDiscovery.discoverDownloaded()

        // Mark default
        for index in models.indices {
            models[index].isDefault = models[index].modelId == config.mlx.modelId
        }

        return models
    }

    /// Get Ollama models
    func getOllamaModels() async -> [OllamaModelInfo] {
        let config = Config.load()
        return await OllamaChecker.availableModelsDetailed(host: config.ollama.host)
    }

    /// Check if Ollama is available
    func isOllamaAvailable() async -> Bool {
        let config = Config.load()
        return await OllamaChecker.isAvailable(host: config.ollama.host)
    }

    // MARK: - Configuration

    /// Set default model
    func setDefaultModel(_ selection: ModelSelection) throws {
        var config = Config.load()

        switch selection {
        case let .mlx(modelId):
            config.mlx.modelId = modelId
            config.provider.defaultProvider = "mlx"
        case let .ollama(model):
            config.ollama.model = model
            config.provider.defaultProvider = "ollama"
        }

        try config.save()
    }

    /// Get current default model ID
    func getCurrentDefault() -> String {
        let config = Config.load()
        return config.mlx.modelId
    }

    // MARK: - Download

    /// Download an MLX model (triggers HuggingFace download)
    func downloadMLXModel(_ modelId: String) async throws {
        #if canImport(MLXLLM)
            terminal.showProgress("Downloading \(modelId)...")
            terminal.showInfo("This may take a few minutes depending on your connection.")
            terminal.showInfo("")

            // Create the model and session - this triggers the download
            let model = MLXLanguageModel(modelId: modelId)
            let session = LanguageModelSession(model: model)

            // Generate a simple prompt to trigger model loading
            _ = try await session.respond(to: "Hi")

            terminal.showSuccess("Model downloaded successfully!")

            // Update config to mark consent
            var config = Config.load()
            config.mlx.downloadConsented = true
            try config.save()
        #else
            throw ModelsError.mlxNotAvailable
        #endif
    }

    // MARK: - Delete

    /// Delete an MLX model
    func deleteMLXModel(_ modelId: String) throws {
        try MLXModelDiscovery.deleteModel(modelId)
        terminal.showSuccess("Deleted \(modelId)")

        // If this was the default, suggest setting a new one
        let config = Config.load()
        if config.mlx.modelId == modelId {
            terminal.showWarning("This was your default model. Please set a new default.")
        }
    }

    // MARK: - Interactive TUI

    /// Run interactive model management
    func runInteractive() async throws {
        var shouldExit = false

        while !shouldExit {
            // Display current state
            await printModelsList()

            // Get action from user
            guard let action = await terminal.promptChoice(
                "What would you like to do?",
                options: ModelAction.self
            ) else {
                shouldExit = true
                continue
            }

            switch action {
            case .setDefault:
                try await handleSetDefault()
            case .download:
                try await handleDownload()
            case .delete:
                try await handleDelete()
            case .exit:
                shouldExit = true
            }

            if !shouldExit {
                print() // Spacing between iterations
            }
        }
    }

    // MARK: - Private Helpers

    private func printModelsList() async {
        let mlxModels = getAllMLXModels()
        let ollamaModels = await getOllamaModels()
        let config = Config.load()

        terminal.printLine()
        terminal.showHeader("MLX Models (Apple Silicon)")
        terminal.printLine()

        if mlxModels.isEmpty {
            terminal.printLine("  No models available")
        } else {
            for model in mlxModels {
                let defaultMark = model.isDefault ? "[*]" : "[ ]"
                let status = model.isDownloaded ? "Downloaded" : "Available"
                let defaultLabel = model.isDefault ? ", Default" : ""
                let desc = model.description.map { " - \($0)" } ?? ""

                terminal.printLine(
                    "  \(defaultMark) \(model.displayName) (\(model.sizeFormatted)) - \(status)\(defaultLabel)\(desc)"
                )
            }
        }

        // Show Ollama models if available
        if !ollamaModels.isEmpty {
            terminal.printLine()
            terminal.showHeader("Ollama Models")
            terminal.printLine()

            for model in ollamaModels {
                let isDefault = model.name == config.ollama.model &&
                    config.provider.defaultProvider == "ollama"
                let defaultMark = isDefault ? "[*]" : "[ ]"
                let defaultLabel = isDefault ? " - Default" : ""

                terminal.printLine("  \(defaultMark) \(model.name) (\(model.sizeFormatted))\(defaultLabel)")
            }
        }

        terminal.printLine()
    }

    private func handleSetDefault() async throws {
        let mlxModels = getAllMLXModels().filter(\.isDownloaded)
        let ollamaModels = await getOllamaModels()

        var options: [(String, ModelSelection)] = []

        // Add downloaded MLX models
        for model in mlxModels {
            options.append(("\(model.displayName) (MLX)", .mlx(modelId: model.modelId)))
        }

        // Add Ollama models
        for model in ollamaModels {
            options.append(("\(model.name) (Ollama)", .ollama(model: model.name)))
        }

        if options.isEmpty {
            terminal.showWarning("No models available. Download an MLX model or start Ollama first.")
            return
        }

        terminal.printLine()
        terminal.showHeader("Select default model:")
        terminal.printLine()

        for (index, option) in options.enumerated() {
            terminal.printLine("  [\(index + 1)] \(option.0)")
        }
        terminal.printLine()
        terminal.showPrompt("Choose [1-\(options.count)]: ")

        guard let line = readLine(),
              let index = Int(line),
              index >= 1,
              index <= options.count
        else {
            terminal.showWarning("Invalid selection")
            return
        }

        let selection = options[index - 1].1
        try setDefaultModel(selection)
        terminal.showSuccess("Default model updated!")
    }

    private func handleDownload() async throws {
        let mlxModels = getAllMLXModels()
        let notDownloaded = mlxModels.filter { !$0.isDownloaded }

        if notDownloaded.isEmpty {
            terminal.showInfo("All curated models are already downloaded.")
            return
        }

        terminal.printLine()
        terminal.showHeader("Available for download:")
        terminal.printLine()

        for (index, model) in notDownloaded.enumerated() {
            let recommended = CuratedModels.find(byId: model.modelId)?.isRecommended == true
            let rec = recommended ? " (Recommended)" : ""
            let desc = model.description.map { " - \($0)" } ?? ""
            terminal.printLine("  [\(index + 1)] \(model.displayName) (\(model.sizeFormatted))\(rec)\(desc)")
        }
        terminal.printLine()
        terminal.showPrompt("Choose [1-\(notDownloaded.count)] or 0 to cancel: ")

        guard let line = readLine(),
              let index = Int(line)
        else {
            return
        }

        if index == 0 {
            return
        }

        guard index >= 1, index <= notDownloaded.count else {
            terminal.showWarning("Invalid selection")
            return
        }

        let model = notDownloaded[index - 1]
        try await downloadMLXModel(model.modelId)
    }

    private func handleDelete() async throws {
        let downloaded = getDownloadedMLXModels()

        if downloaded.isEmpty {
            terminal.showWarning("No MLX models downloaded.")
            return
        }

        terminal.printLine()
        terminal.showHeader("Downloaded models:")
        terminal.printLine()

        for (index, model) in downloaded.enumerated() {
            let defaultLabel = model.isDefault ? " (Default)" : ""
            terminal.printLine("  [\(index + 1)] \(model.displayName) (\(model.sizeFormatted))\(defaultLabel)")
        }
        terminal.printLine()
        terminal.showPrompt("Choose [1-\(downloaded.count)] or 0 to cancel: ")

        guard let line = readLine(),
              let index = Int(line)
        else {
            return
        }

        if index == 0 {
            return
        }

        guard index >= 1, index <= downloaded.count else {
            terminal.showWarning("Invalid selection")
            return
        }

        let model = downloaded[index - 1]

        // Confirm deletion
        terminal.printLine()
        let confirmed = await terminal.promptYesNo("Delete \(model.displayName) (\(model.sizeFormatted))?")

        if confirmed {
            try deleteMLXModel(model.modelId)
        }
    }

    // MARK: - Non-Interactive List

    /// Print models list for non-interactive mode
    func printList() async {
        let mlxModels = getAllMLXModels()
        let ollamaModels = await getOllamaModels()
        let config = Config.load()

        terminal.printLine()
        terminal.printLine("MLX Models:")
        for model in mlxModels {
            let status = model.isDownloaded ? "downloaded" : "available"
            let defaultMark = model.isDefault ? " (default)" : ""
            terminal.printLine("  \(model.modelId) [\(model.sizeFormatted)] - \(status)\(defaultMark)")
        }

        if !ollamaModels.isEmpty {
            terminal.printLine()
            terminal.printLine("Ollama Models:")
            for model in ollamaModels {
                let isDefault = model.name == config.ollama.model &&
                    config.provider.defaultProvider == "ollama"
                let defaultMark = isDefault ? " (default)" : ""
                terminal.printLine("  \(model.name) [\(model.sizeFormatted)]\(defaultMark)")
            }
        } else {
            terminal.printLine()
            terminal.printLine("Ollama: not running")
        }

        terminal.printLine()
    }
}
