// swiftlint:disable file_length
import AnyLanguageModel
import Foundation

#if canImport(MLXLMCommon)
    import MLXLMCommon
#endif

#if !os(Linux)
    import Noora
#endif

/// Protocol for LLM providers
protocol LLMProvider: Sendable {
    var name: String { get }
    var supportsStreaming: Bool { get }
    func generate(prompt: String) async throws -> String
    func generateStreaming(prompt: String, onChunk: @escaping @Sendable (String) -> Void) async throws
        -> String
}

/// Manages LLM provider selection and fallback chain
final class ProviderManager: Sendable {
    private let preferredProvider: Provider?

    /// Default fallback chain: Foundation → MLX → Ollama → Anthropic → OpenAI
    private let defaultChain: [Provider] = [.foundation, .mlx, .ollama, .anthropic, .openai]

    init(preferredProvider: Provider?) {
        self.preferredProvider = preferredProvider
    }

    /// Get the first available provider from the chain
    func getAvailableProvider() async throws -> LLMProvider {
        // If user specified a provider, use only that one
        if let preferred = preferredProvider {
            guard let provider = try await createProvider(preferred) else {
                throw ClaiError.providerUnavailable(preferred.rawValue)
            }
            return provider
        }

        // Otherwise, check providers concurrently while maintaining priority
        return try await withThrowingTaskGroup(of: (Int, LLMProvider?).self) { group in
            for (index, providerType) in defaultChain.enumerated() {
                group.addTask {
                    let provider = try await self.createProvider(providerType)
                    return (index, provider)
                }
            }

            var results: [Int: LLMProvider?] = [:]
            var nextIndexToCheck = 0

            // Collect results as they come in
            for try await (index, provider) in group {
                results[index] = provider

                // Check if we can satisfy the request with what we have so far
                while nextIndexToCheck < defaultChain.count {
                    // If we don't have the result for the current priority yet, stop and wait
                    guard let resultContainer = results[nextIndexToCheck] else {
                        break
                    }

                    // If we have a provider, return it!
                    if let foundProvider = resultContainer {
                        group.cancelAll()
                        return foundProvider
                    }

                    // If result was nil (not available), move to next priority
                    nextIndexToCheck += 1
                }
            }

            throw ClaiError.noProviderAvailable
        }
    }

    private func createProvider(_ type: Provider) async throws -> LLMProvider? {
        switch type {
        case .foundation:
            await FoundationModelProvider.createIfAvailable()
        case .mlx:
            await MLXProvider.createIfAvailable()
        case .ollama:
            await OllamaProvider.createIfAvailable()
        case .anthropic:
            AnthropicProvider.createIfAvailable()
        case .openai:
            OpenAIProvider.createIfAvailable()
        }
    }
}

// MARK: - Provider Implementations

/// FoundationModel provider (macOS 26+)
#if canImport(FoundationModels)
    import FoundationModels

    struct FoundationModelProvider: LLMProvider {
        let name = "FoundationModel"
        let supportsStreaming = true

        private let _model: any Sendable
        private let _session: any Sendable

        @available(macOS 26.0, iOS 26.0, *)
        private var model: FoundationModels.SystemLanguageModel {
            // swiftlint:disable:next force_cast
            _model as! FoundationModels.SystemLanguageModel
        }

        @available(macOS 26.0, iOS 26.0, *)
        private var session: FoundationModels.LanguageModelSession {
            // swiftlint:disable:next force_cast
            _session as! FoundationModels.LanguageModelSession
        }

        @available(macOS 26.0, iOS 26.0, *)
        private init(model: FoundationModels.SystemLanguageModel) {
            _model = model
            _session = FoundationModels.LanguageModelSession(model: model)
        }

        static func createIfAvailable() async -> FoundationModelProvider? {
            guard #available(macOS 26.0, iOS 26.0, *) else {
                return nil
            }
            guard PlatformDetector.current.supportsFoundationModel else {
                return nil
            }

            let model = FoundationModels.SystemLanguageModel.default
            if case .unavailable = model.availability {
                return nil
            }

            return FoundationModelProvider(model: model)
        }

        func generate(prompt: String) async throws -> String {
            guard #available(macOS 26.0, iOS 26.0, *) else {
                throw ClaiError.providerUnavailable("FoundationModel requires macOS 26+")
            }
            let response = try await session.respond(to: prompt)
            return response.content
        }

        func generateStreaming(
            prompt: String, onChunk: @escaping @Sendable (String) -> Void
        ) async throws -> String {
            guard #available(macOS 26.0, iOS 26.0, *) else {
                throw ClaiError.providerUnavailable("FoundationModel requires macOS 26+")
            }
            var fullResponse = ""
            let stream = session.streamResponse(to: prompt)
            for try await snapshot in stream {
                let newContent = String(snapshot.content.dropFirst(fullResponse.count))
                if !newContent.isEmpty {
                    onChunk(newContent)
                }
                fullResponse = snapshot.content
            }
            return fullResponse
        }
    }
#else
    struct FoundationModelProvider: LLMProvider {
        let name = "FoundationModel"
        let supportsStreaming = true

        static func createIfAvailable() async -> FoundationModelProvider? {
            nil
        }

        func generate(prompt: String) async throws -> String {
            throw ClaiError.providerUnavailable("FoundationModel not available")
        }

        func generateStreaming(
            prompt: String, onChunk: @escaping @Sendable (String) -> Void
        ) async throws -> String {
            throw ClaiError.providerUnavailable("FoundationModel not available")
        }
    }
#endif

/// MLX provider for Apple Silicon
struct MLXProvider: LLMProvider {
    let name = "MLX"
    let supportsStreaming = false // MLX streaming not implemented in AnyLanguageModel

    #if canImport(MLXLLM)
        private let model: MLXLanguageModel
        private let session: AnyLanguageModel.LanguageModelSession

        private init(model: MLXLanguageModel) {
            self.model = model
            session = AnyLanguageModel.LanguageModelSession(model: model)
        }

        static func createIfAvailable() async -> MLXProvider? {
            guard PlatformDetector.current.supportsMLX else {
                return nil
            }

            // MLX may fail if Metal libraries aren't bundled (e.g., Homebrew distribution).
            // Suppress stderr during initialization to avoid confusing error messages.
            guard MLXAvailabilityChecker.isMLXFunctional() else {
                return nil
            }

            // Get model configuration
            let config = Config.load()
            let smallModelId = "mlx-community/Qwen3-0.6B-4bit"

            // Determine preferred model based on config
            let preferredModelId = config.mlx.preferSmallModel ? smallModelId : config.mlx.modelId

            // Check what's available
            let preferredIsDownloaded = MLXModelDiscovery.isModelDownloaded(preferredModelId)
            let smallIsDownloaded = MLXModelDiscovery.isModelDownloaded(smallModelId)
            let canFallbackToSmall = preferredModelId != smallModelId && smallIsDownloaded

            // Select model: preferred if available, else small model (prevents large first-run download)
            let modelId: String = if preferredIsDownloaded {
                preferredModelId
            } else if canFallbackToSmall {
                smallModelId
            } else {
                smallModelId
            }

            // Pre-download model with progress display if not already cached
            if !MLXModelDiscovery.isModelDownloaded(modelId) {
                let modelName = modelId.replacingOccurrences(of: "mlx-community/", with: "")
                let estimatedSize = CuratedModels.getEstimatedSize(for: modelId)

                do {
                    try await Noora().progressBarStep(
                        message: "Downloading \(modelName) (\(estimatedSize))",
                        successMessage: "Model downloaded",
                        errorMessage: "Download failed"
                    ) { updateProgress in
                        // Bridge sync callback to async Noora update using unsafe capture
                        nonisolated(unsafe) let unsafeProgress = updateProgress
                        _ = try await MLXLMCommon.loadModel(id: modelId) { progress in
                            Task {
                                await unsafeProgress(progress.fractionCompleted)
                            }
                        }
                    }
                } catch {
                    Noora().warning(.alert("Download interrupted. Will retry..."))
                }
            }

            let model = MLXLanguageModel(modelId: modelId)
            return MLXProvider(model: model)
        }

        func generate(prompt: String) async throws -> String {
            let response = try await session.respond(to: prompt)
            return response.content
        }

        func generateStreaming(
            prompt: String, onChunk: @escaping @Sendable (String) -> Void
        ) async throws -> String {
            var fullResponse = ""
            let stream = session.streamResponse(to: prompt)
            for try await snapshot in stream {
                let newContent = String(snapshot.content.dropFirst(fullResponse.count))
                if !newContent.isEmpty {
                    onChunk(newContent)
                }
                fullResponse = snapshot.content
            }
            return fullResponse
        }
    #else
        static func createIfAvailable() async -> MLXProvider? {
            nil
        }

        func generate(prompt: String) async throws -> String {
            throw ClaiError.providerUnavailable("MLX not available")
        }

        func generateStreaming(
            prompt: String, onChunk: @escaping @Sendable (String) -> Void
        ) async throws -> String {
            throw ClaiError.providerUnavailable("MLX not available")
        }
    #endif
}

/// Ollama provider for local inference
struct OllamaProvider: LLMProvider {
    let name = "Ollama"
    let supportsStreaming = true
    private let model: OllamaLanguageModel
    private let session: AnyLanguageModel.LanguageModelSession

    init(modelName: String = "llama3.2") {
        model = OllamaLanguageModel(model: modelName)
        session = AnyLanguageModel.LanguageModelSession(model: model)
    }

    static func createIfAvailable() async -> OllamaProvider? {
        guard await OllamaChecker.isAvailable() else {
            return nil
        }

        // Get available models
        var models = await OllamaChecker.availableModels()
        let preferredModels = ["llama3.2", "qwen3", "llama3.1", "mistral", "gemma2"]
        let defaultModel = "llama3.2"

        // If no models available, offer to download one
        if models.isEmpty {
            #if !os(Linux)
                do {
                    try await Noora().progressBarStep(
                        message: "Downloading Ollama model: \(defaultModel)",
                        successMessage: "Model downloaded",
                        errorMessage: "Download failed"
                    ) { updateProgress in
                        nonisolated(unsafe) let unsafeProgress = updateProgress
                        _ = try await OllamaChecker.pullModel(defaultModel) { completed, total in
                            let fraction = total > 0 ? Double(completed) / Double(total) : 0
                            Task {
                                await unsafeProgress(fraction)
                            }
                        }
                    }
                    models = [defaultModel]
                } catch {
                    Noora().warning(.alert("Failed to download Ollama model: \(error.localizedDescription)"))
                    return nil
                }
            #else
                // On Linux, download without Noora progress UI
                do {
                    print("Downloading Ollama model: \(defaultModel)...")
                    _ = try await OllamaChecker.pullModel(defaultModel) { _, _ in }
                    print("Model downloaded")
                    models = [defaultModel]
                } catch {
                    print("Failed to download: \(error.localizedDescription)")
                    return nil
                }
            #endif
        }

        // Select preferred model from available ones
        var selectedModel = defaultModel
        for preferred in preferredModels where models.contains(where: { $0.hasPrefix(preferred) }) {
            selectedModel = models.first(where: { $0.hasPrefix(preferred) }) ?? preferred
            break
        }

        // If no preferred model found, use first available
        if !models.isEmpty, !preferredModels.contains(where: { pref in models.contains { $0.hasPrefix(pref) } }) {
            selectedModel = models[0]
        }

        return OllamaProvider(modelName: selectedModel)
    }

    func generate(prompt: String) async throws -> String {
        let response = try await session.respond(to: prompt)
        return response.content
    }

    func generateStreaming(
        prompt: String, onChunk: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        var fullResponse = ""
        let stream = session.streamResponse(to: prompt)
        for try await snapshot in stream {
            let newContent = String(snapshot.content.dropFirst(fullResponse.count))
            if !newContent.isEmpty {
                onChunk(newContent)
            }
            fullResponse = snapshot.content
        }
        return fullResponse
    }
}

/// Anthropic provider for cloud inference
struct AnthropicProvider: LLMProvider {
    let name = "Anthropic"
    let supportsStreaming = true
    private let model: AnthropicLanguageModel
    private let session: AnyLanguageModel.LanguageModelSession

    init(apiKey: String, modelName: String = "claude-sonnet-4-5-20250929") {
        model = AnthropicLanguageModel(apiKey: apiKey, model: modelName)
        session = AnyLanguageModel.LanguageModelSession(model: model)
    }

    static func createIfAvailable() -> AnthropicProvider? {
        guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
              !apiKey.isEmpty
        else {
            return nil
        }
        // Use Claude 3.5 Haiku for fast, cost-effective CLI help
        return AnthropicProvider(apiKey: apiKey, modelName: "claude-3-5-haiku-20241022")
    }

    func generate(prompt: String) async throws -> String {
        let response = try await session.respond(to: prompt)
        return response.content
    }

    func generateStreaming(
        prompt: String, onChunk: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        var fullResponse = ""
        let stream = session.streamResponse(to: prompt)
        for try await snapshot in stream {
            let newContent = String(snapshot.content.dropFirst(fullResponse.count))
            if !newContent.isEmpty {
                onChunk(newContent)
            }
            fullResponse = snapshot.content
        }
        return fullResponse
    }
}

/// OpenAI provider for cloud inference
struct OpenAIProvider: LLMProvider {
    let name = "OpenAI"
    let supportsStreaming = true
    private let model: OpenAILanguageModel
    private let session: AnyLanguageModel.LanguageModelSession

    init(apiKey: String, modelName: String = "gpt-4o-mini") {
        model = OpenAILanguageModel(apiKey: apiKey, model: modelName)
        session = AnyLanguageModel.LanguageModelSession(model: model)
    }

    static func createIfAvailable() -> OpenAIProvider? {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
              !apiKey.isEmpty
        else {
            return nil
        }
        // Use GPT-4o-mini for fast, cost-effective CLI help
        return OpenAIProvider(apiKey: apiKey)
    }

    func generate(prompt: String) async throws -> String {
        let response = try await session.respond(to: prompt)
        return response.content
    }

    func generateStreaming(
        prompt: String, onChunk: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        var fullResponse = ""
        let stream = session.streamResponse(to: prompt)
        for try await snapshot in stream {
            let newContent = String(snapshot.content.dropFirst(fullResponse.count))
            if !newContent.isEmpty {
                onChunk(newContent)
            }
            fullResponse = snapshot.content
        }
        return fullResponse
    }
}
