import Foundation

// MARK: - Configuration

/// Configuration for clai
struct Config: Codable, Sendable {
    /// Provider configuration
    var provider: ProviderConfig

    /// MLX model configuration
    var mlx: MLXConfig

    /// Ollama configuration
    var ollama: OllamaConfig

    /// Anthropic configuration
    var anthropic: CloudProviderConfig

    /// OpenAI configuration
    var openai: CloudProviderConfig

    /// Cache configuration
    var cache: CacheConfig

    /// Creates default configuration
    static var `default`: Config {
        Config(
            provider: ProviderConfig(),
            mlx: MLXConfig(),
            ollama: OllamaConfig(),
            anthropic: CloudProviderConfig(apiKeyEnv: "ANTHROPIC_API_KEY", model: "claude-3-5-haiku-20241022"),
            openai: CloudProviderConfig(apiKeyEnv: "OPENAI_API_KEY", model: "gpt-4o-mini"),
            cache: CacheConfig()
        )
    }
}

/// Provider selection configuration
struct ProviderConfig: Codable, Sendable {
    /// Default provider to use
    var defaultProvider: String?

    /// Fallback chain order
    var fallback: [String]

    init(defaultProvider: String? = nil, fallback: [String] = ["foundation", "mlx", "ollama", "anthropic", "openai"]) {
        self.defaultProvider = defaultProvider
        self.fallback = fallback
    }

    enum CodingKeys: String, CodingKey {
        case defaultProvider = "default"
        case fallback
    }
}

/// MLX model configuration
struct MLXConfig: Codable, Sendable {
    /// HuggingFace model ID
    var modelId: String

    /// Whether user has consented to download
    var downloadConsented: Bool

    /// Preferred model size (small or standard)
    var preferSmallModel: Bool

    init(
        modelId: String = "mlx-community/Qwen3-4B-4bit",
        downloadConsented: Bool = false,
        preferSmallModel: Bool = false
    ) {
        self.modelId = modelId
        self.downloadConsented = downloadConsented
        self.preferSmallModel = preferSmallModel
    }

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case downloadConsented = "download_consented"
        case preferSmallModel = "prefer_small_model"
    }
}

/// Ollama configuration
struct OllamaConfig: Codable, Sendable {
    /// Model name
    var model: String

    /// Ollama server host
    var host: String

    init(model: String = "llama3.2", host: String = "http://localhost:11434") {
        self.model = model
        self.host = host
    }
}

/// Cloud provider configuration
struct CloudProviderConfig: Codable, Sendable {
    /// Environment variable name for API key
    var apiKeyEnv: String

    /// Model name
    var model: String

    enum CodingKeys: String, CodingKey {
        case apiKeyEnv = "api_key_env"
        case model
    }
}

/// Cache configuration
struct CacheConfig: Codable, Sendable {
    /// Whether caching is enabled
    var enabled: Bool

    /// TTL in days
    var ttlDays: Int

    init(enabled: Bool = true, ttlDays: Int = 7) {
        self.enabled = enabled
        self.ttlDays = ttlDays
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case ttlDays = "ttl_days"
    }
}

// Config loading methods are in ConfigLoading.swift

// MARK: - Validation

extension Config {
    /// Validation errors
    enum ValidationError: Error, LocalizedError {
        case invalidProvider(String)
        case invalidModelId(String)
        case invalidHost(String)
        case invalidTTL(Int)

        var errorDescription: String? {
            switch self {
            case let .invalidProvider(name):
                "Invalid provider '\(name)'. Valid options: foundation, mlx, ollama, anthropic, openai"
            case let .invalidModelId(modelId):
                "Invalid model ID '\(modelId)'"
            case let .invalidHost(host):
                "Invalid host URL '\(host)'"
            case let .invalidTTL(days):
                "Invalid TTL '\(days)'. Must be positive."
            }
        }
    }

    /// Validate the configuration
    func validate() throws {
        let validProviders = ["foundation", "mlx", "ollama", "anthropic", "openai"]

        // Validate default provider
        if let defaultProvider = provider.defaultProvider {
            guard validProviders.contains(defaultProvider) else {
                throw ValidationError.invalidProvider(defaultProvider)
            }
        }

        // Validate fallback chain
        for fallbackProvider in provider.fallback {
            guard validProviders.contains(fallbackProvider) else {
                throw ValidationError.invalidProvider(fallbackProvider)
            }
        }

        // Validate Ollama host URL
        guard URL(string: ollama.host) != nil else {
            throw ValidationError.invalidHost(ollama.host)
        }

        // Validate cache TTL
        guard cache.ttlDays > 0 else {
            throw ValidationError.invalidTTL(cache.ttlDays)
        }
    }
}
