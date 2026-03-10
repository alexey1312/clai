import Foundation
import Testing
import Yams

@testable import clai

@Suite("Configuration Tests", .serialized)
struct ConfigurationTests {
    init() {
        Config.clearCache()
    }

    @Test("Config has valid defaults")
    func defaultConfig() {
        let config = Config.default
        #expect(!config.provider.fallback.isEmpty)
        #expect(config.cache.ttlDays > 0)
    }

    @Test("Config can be encoded to YAML")
    func configEncode() throws {
        let config = Config.default
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(config)
        #expect(!yaml.isEmpty)
        #expect(yaml.contains("provider"))
    }

    @Test("Config validation passes for valid config")
    func validConfigValidation() throws {
        let config = Config.default
        try config.validate()
    }

    @Test("Config validation fails for invalid provider")
    func invalidProviderValidation() {
        var config = Config.default
        config.provider.defaultProvider = "invalid_provider"
        #expect(throws: Config.ValidationError.self) {
            try config.validate()
        }
    }

    @Test("Config validation fails for invalid TTL")
    func invalidTTLValidation() {
        var config = Config.default
        config.cache.ttlDays = 0
        #expect(throws: Config.ValidationError.self) {
            try config.validate()
        }
    }

    @Test("Config environment override works")
    func environmentOverride() {
        // Note: This test depends on environment variables not being set
        let config = Config.default.applyingEnvironmentOverrides()
        // Default should still be there if env vars not set
        #expect(config.provider.fallback == Config.default.provider.fallback)
    }
}

@Suite("ConfigError Tests", .serialized)
struct ConfigErrorTests {
    init() {
        Config.clearCache()
    }

    @Test("ConfigError.yamlParsingFailed has descriptive message with snippet")
    func yamlParsingErrorWithSnippet() {
        let error = ConfigError.yamlParsingFailed(
            problem: "did not find expected key",
            line: 5,
            column: 3,
            snippet: "  4 | mlx:\n> 5 | model_id mlx-community/Qwen3-4B-4bit\n        ^"
        )
        let description = error.errorDescription!
        #expect(description.contains("line 5"))
        #expect(description.contains("column 3"))
        #expect(description.contains("did not find expected key"))
        #expect(description.contains("model_id"))
    }

    @Test("ConfigError.yamlParsingFailed works without snippet")
    func yamlParsingErrorWithoutSnippet() {
        let error = ConfigError.yamlParsingFailed(
            problem: "unexpected end of stream",
            line: 10,
            column: 1,
            snippet: nil
        )
        let description = error.errorDescription!
        #expect(description.contains("line 10"))
        #expect(description.contains("column 1"))
        #expect(!description.contains("\n"))
    }

    @Test("ConfigError.yamlDecodingFailed has field info")
    func yamlDecodingError() {
        let error = ConfigError.yamlDecodingFailed(
            field: "provider.fallback",
            message: "expected array"
        )
        let description = error.errorDescription!
        #expect(description.contains("provider.fallback"))
        #expect(description.contains("expected array"))
    }

    @Test("ConfigError.fileReadFailed includes path")
    func fileReadError() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "file not found"])
        let error = ConfigError.fileReadFailed(path: "/path/to/config.yaml", underlying: underlying)
        let description = error.errorDescription!
        #expect(description.contains("/path/to/config.yaml"))
    }
}
