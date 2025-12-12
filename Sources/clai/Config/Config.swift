import Foundation
import Yams

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

// MARK: - Config Loading

extension Config {
    /// Config file location
    static var configFileURL: URL {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("clai")
        return configDir.appendingPathComponent("config.yaml")
    }

    /// Load configuration from file, environment variables, and defaults
    static func load() -> Config {
        var config = Config.default

        // Try to load from config file
        if let fileConfig = loadFromFile() {
            config = config.merged(with: fileConfig)
        }

        // Apply environment variable overrides
        config = config.applyingEnvironmentOverrides()

        return config
    }

    /// Load configuration from YAML file
    private static func loadFromFile() -> Config? {
        let fileURL = configFileURL

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let yamlString = try String(contentsOf: fileURL, encoding: .utf8)
            let decoder = YAMLDecoder()
            return try decoder.decode(Config.self, from: yamlString)
        } catch {
            // Log error but don't crash
            print("Warning: Failed to load config file: \(error.localizedDescription)")
            return nil
        }
    }

    /// Merge another config into this one (other takes precedence)
    func merged(with other: Config) -> Config {
        Config(
            provider: ProviderConfig(
                defaultProvider: other.provider.defaultProvider ?? provider.defaultProvider,
                fallback: other.provider.fallback.isEmpty ? provider.fallback : other.provider.fallback
            ),
            mlx: MLXConfig(
                modelId: other.mlx.modelId,
                downloadConsented: other.mlx.downloadConsented || mlx.downloadConsented,
                preferSmallModel: other.mlx.preferSmallModel || mlx.preferSmallModel
            ),
            ollama: OllamaConfig(
                model: other.ollama.model,
                host: other.ollama.host
            ),
            anthropic: CloudProviderConfig(
                apiKeyEnv: other.anthropic.apiKeyEnv,
                model: other.anthropic.model
            ),
            openai: CloudProviderConfig(
                apiKeyEnv: other.openai.apiKeyEnv,
                model: other.openai.model
            ),
            cache: CacheConfig(
                enabled: other.cache.enabled,
                ttlDays: other.cache.ttlDays
            )
        )
    }

    /// Apply environment variable overrides
    func applyingEnvironmentOverrides() -> Config {
        var config = self
        let env = ProcessInfo.processInfo.environment

        // CLAI_PROVIDER overrides default provider
        if let providerOverride = env["CLAI_PROVIDER"] {
            config.provider.defaultProvider = providerOverride
        }

        // CLAI_MLX_MODEL overrides MLX model
        if let mlxModel = env["CLAI_MLX_MODEL"] {
            config.mlx.modelId = mlxModel
        }

        // CLAI_OLLAMA_MODEL overrides Ollama model
        if let ollamaModel = env["CLAI_OLLAMA_MODEL"] {
            config.ollama.model = ollamaModel
        }

        // CLAI_OLLAMA_HOST overrides Ollama host
        if let ollamaHost = env["CLAI_OLLAMA_HOST"] {
            config.ollama.host = ollamaHost
        }

        // CLAI_CACHE_ENABLED controls caching
        if let cacheEnabled = env["CLAI_CACHE_ENABLED"] {
            config.cache.enabled = cacheEnabled.lowercased() == "true" || cacheEnabled == "1"
        }

        return config
    }

    /// Save configuration to file
    func save() throws {
        let fileURL = Config.configFileURL
        let configDir = fileURL.deletingLastPathComponent()

        // Create config directory if needed
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        // Encode to YAML
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(self)

        try yamlString.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

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
