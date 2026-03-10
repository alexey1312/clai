import Foundation
import Yams

// MARK: - Config Loading

extension Config {
    private nonisolated(unsafe) static var _cachedConfig: Config?
    private static let _cacheLock = NSLock()

    /// Clear the cached configuration
    static func clearCache() {
        _cacheLock.lock()
        defer { _cacheLock.unlock() }
        _cachedConfig = nil
    }

    /// Config file location
    static var configFileURL: URL {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("clai")
        return configDir.appendingPathComponent("config.yaml")
    }

    /// Load configuration from file (single source of truth)
    ///
    /// Flow:
    /// 1. Create config file with defaults if it doesn't exist
    /// 2. Load from file (the only source)
    /// 3. Apply environment variable overrides
    /// 4. Validate
    ///
    /// - Throws: `ConfigError` on file/parsing errors, `ValidationError` on invalid values
    static func load() throws -> Config {
        _cacheLock.lock()
        if let cached = _cachedConfig {
            _cacheLock.unlock()
            var config = cached.applyingEnvironmentOverrides()
            try config.validate()
            return config
        }
        _cacheLock.unlock()

        let fileURL = configFileURL

        // 1. Create file with defaults if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try createDefaultConfigFile(at: fileURL)
        }

        // 2. Load from file (single source of truth)
        var config = try loadFromFile(at: fileURL)

        _cacheLock.lock()
        _cachedConfig = config
        _cacheLock.unlock()

        // 3. Apply environment variable overrides
        config = config.applyingEnvironmentOverrides()

        // 4. Validate
        try config.validate()

        return config
    }

    /// Create default config file with documentation comments
    private static func createDefaultConfigFile(at fileURL: URL) throws {
        let configDir = fileURL.deletingLastPathComponent()

        // Create directory if needed
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        } catch {
            throw ConfigError.directoryCreationFailed(path: configDir.path, underlying: error)
        }

        // Generate YAML with documentation
        let yamlContent = generateDefaultConfigYAML()

        // Write file
        do {
            try yamlContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw ConfigError.fileCreationFailed(path: fileURL.path, underlying: error)
        }
    }

    /// Generate default config YAML with documentation comments
    private static func generateDefaultConfigYAML() -> String {
        """
        # clai configuration
        # Environment overrides: CLAI_PROVIDER, CLAI_MLX_MODEL, CLAI_OLLAMA_MODEL, CLAI_OLLAMA_HOST, CLAI_CACHE_ENABLED

        provider:
          # default: ollama  # uncomment to set preferred provider
          fallback:
            - foundation
            - mlx
            - ollama
            - anthropic
            - openai

        mlx:
          model_id: mlx-community/Qwen3-4B-4bit
          download_consented: false
          prefer_small_model: false

        ollama:
          model: llama3.2
          host: http://localhost:11434

        anthropic:
          api_key_env: ANTHROPIC_API_KEY
          model: claude-3-5-haiku-20241022

        openai:
          api_key_env: OPENAI_API_KEY
          model: gpt-4o-mini

        cache:
          enabled: true
          ttl_days: 7
        """
    }

    /// Load configuration from YAML file
    private static func loadFromFile(at fileURL: URL) throws -> Config {
        // Read file content
        let yamlString: String
        do {
            yamlString = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw ConfigError.fileReadFailed(path: fileURL.path, underlying: error)
        }

        // Parse YAML
        do {
            let decoder = YAMLDecoder()
            return try decoder.decode(Config.self, from: yamlString)
        } catch let error as YamlError {
            throw mapYamlError(error, yamlContent: yamlString)
        } catch let error as DecodingError {
            throw mapDecodingError(error)
        } catch {
            throw ConfigError.yamlParsingFailed(
                problem: error.localizedDescription,
                line: 0,
                column: 0,
                snippet: nil
            )
        }
    }

    /// Map Yams YamlError to ConfigError with position info
    private static func mapYamlError(_ error: YamlError, yamlContent: String) -> ConfigError {
        let lines = yamlContent.components(separatedBy: .newlines)

        switch error {
        case let .scanner(context, problem, mark, _):
            let snippet = createSnippet(lines: lines, line: mark.line, column: mark.column)
            let message = context.map { "\($0): \(problem)" } ?? problem
            return .yamlParsingFailed(problem: message, line: mark.line, column: mark.column, snippet: snippet)

        case let .parser(context, problem, mark, _):
            let snippet = createSnippet(lines: lines, line: mark.line, column: mark.column)
            let message = context.map { "\($0): \(problem)" } ?? problem
            return .yamlParsingFailed(problem: message, line: mark.line, column: mark.column, snippet: snippet)

        case let .composer(context, problem, mark, _):
            let snippet = createSnippet(lines: lines, line: mark.line, column: mark.column)
            let message = context.map { "\($0): \(problem)" } ?? problem
            return .yamlParsingFailed(problem: message, line: mark.line, column: mark.column, snippet: snippet)

        default:
            return .yamlParsingFailed(
                problem: error.localizedDescription,
                line: 0,
                column: 0,
                snippet: nil
            )
        }
    }

    /// Map DecodingError to ConfigError
    private static func mapDecodingError(_ error: DecodingError) -> ConfigError {
        switch error {
        case let .keyNotFound(key, context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            let field = path.isEmpty ? key.stringValue : "\(path).\(key.stringValue)"
            return .yamlDecodingFailed(field: field, message: "missing required field")

        case let .typeMismatch(type, context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return .yamlDecodingFailed(field: path, message: "expected \(type)")

        case let .valueNotFound(type, context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return .yamlDecodingFailed(field: path, message: "expected \(type), got null")

        case let .dataCorrupted(context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return .yamlDecodingFailed(field: path, message: context.debugDescription)

        @unknown default:
            return .yamlDecodingFailed(field: "unknown", message: error.localizedDescription)
        }
    }

    /// Create a code snippet showing the error location
    /// - Parameters:
    ///   - lines: Array of source file lines
    ///   - line: 1-based line number where error occurred
    ///   - column: Column position of the error
    /// - Returns: Formatted snippet with line numbers and caret marker, or empty string if line is out of bounds
    private static func createSnippet(lines: [String], line: Int, column: Int) -> String {
        // Convert 1-based line number to 0-based array index
        let lineIndex = line - 1
        guard lineIndex >= 0, lineIndex < lines.count else { return "" }

        var result = ""

        // Show previous line for context if available
        if lineIndex > 0 {
            result += "  \(line - 1) | \(lines[lineIndex - 1])\n"
        }

        // Show the error line with marker
        result += "> \(line) | \(lines[lineIndex])\n"

        // Show column marker
        let padding = String(repeating: " ", count: String(line).count + 3 + max(0, column - 1))
        result += "\(padding)^"

        return result
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
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        } catch {
            throw ConfigError.directoryCreationFailed(path: configDir.path, underlying: error)
        }

        // Encode to YAML
        let encoder = YAMLEncoder()
        let yamlString: String
        do {
            yamlString = try encoder.encode(self)
        } catch {
            throw ConfigError.yamlEncodingFailed(underlying: error)
        }

        do {
            try yamlString.write(to: fileURL, atomically: true, encoding: .utf8)

            // Invalidate cache so next load() re-reads from disk without environment overrides applied
            _cacheLock.lock()
            _cachedConfig = nil
            _cacheLock.unlock()
        } catch {
            throw ConfigError.fileCreationFailed(path: fileURL.path, underlying: error)
        }
    }
}
