import AnyLanguageModel
import Foundation

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

        // Otherwise, try the fallback chain
        for providerType in defaultChain {
            if let provider = try await createProvider(providerType) {
                return provider
            }
        }

        throw ClaiError.noProviderAvailable
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
struct FoundationModelProvider: LLMProvider {
    let name = "FoundationModel"
    let supportsStreaming = true // Apple's FoundationModel supports streaming (not yet implemented)

    static func createIfAvailable() async -> FoundationModelProvider? {
        // Check if FoundationModel is available (macOS 26+)
        guard PlatformDetector.current.supportsFoundationModel else {
            return nil
        }
        // Note: FoundationModel requires macOS 26+ which isn't widely available yet
        // For now, return nil even if platform check passes since the API isn't stable
        return nil
    }

    func generate(prompt: String) async throws -> String {
        // FoundationModel implementation would go here when macOS 26 is available
        throw ClaiError.providerUnavailable("FoundationModel requires macOS 26+")
    }

    func generateStreaming(
        prompt: String, onChunk: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        throw ClaiError.providerUnavailable("FoundationModel requires macOS 26+")
    }
}

/// MLX provider for Apple Silicon
struct MLXProvider: LLMProvider {
    let name = "MLX"
    let supportsStreaming = false // MLX streaming not implemented in AnyLanguageModel

    #if canImport(MLXLLM)
        private let model: MLXLanguageModel
        private let session: LanguageModelSession

        private init(model: MLXLanguageModel) {
            self.model = model
            session = LanguageModelSession(model: model)
        }

        static func createIfAvailable() async -> MLXProvider? {
            guard PlatformDetector.current.supportsMLX else {
                return nil
            }
            // Use a small, fast model for CLI help
            let model = MLXLanguageModel(modelId: "mlx-community/Qwen3-0.6B-4bit")
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
    private let session: LanguageModelSession

    init(modelName: String = "llama3.2") {
        model = OllamaLanguageModel(model: modelName)
        session = LanguageModelSession(model: model)
    }

    static func createIfAvailable() async -> OllamaProvider? {
        guard await OllamaChecker.isAvailable() else {
            return nil
        }
        // Get first available model, prefer llama3.2 or qwen3
        let models = await OllamaChecker.availableModels()
        let preferredModels = ["llama3.2", "qwen3", "llama3.1", "mistral", "gemma2"]

        var selectedModel = "llama3.2"
        for preferred in preferredModels where models.contains(where: { $0.hasPrefix(preferred) }) {
            selectedModel = models.first(where: { $0.hasPrefix(preferred) }) ?? preferred
            break
        }

        // If no preferred model found, use first available
        if !models.isEmpty, !preferredModels.contains(where: { models.contains($0) }) {
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
    private let session: LanguageModelSession

    init(apiKey: String, modelName: String = "claude-sonnet-4-5-20250929") {
        model = AnthropicLanguageModel(apiKey: apiKey, model: modelName)
        session = LanguageModelSession(model: model)
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
    private let session: LanguageModelSession

    init(apiKey: String, modelName: String = "gpt-4o-mini") {
        model = OpenAILanguageModel(apiKey: apiKey, model: modelName)
        session = LanguageModelSession(model: model)
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
