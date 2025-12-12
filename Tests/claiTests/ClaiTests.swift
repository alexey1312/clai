import Foundation
import Testing

@testable import clai

// MARK: - Unit Tests

@Suite("Context Gathering Tests")
struct ContextGatheringTests {
    @Test("ContextGatherer can be instantiated")
    func contextGathererInit() {
        let gatherer = ContextGatherer()
        // Just verify it can be instantiated without crashing
        _ = gatherer
    }

    @Test("ContextGatherer gathers context for known command")
    func gatherKnownCommand() async throws {
        let gatherer = ContextGatherer()
        let context = try await gatherer.gather(for: "ls")
        // ls should have help output
        #expect(context.helpOutput != nil || context.manPageContent != nil)
    }
}

@Suite("Platform Detection Tests")
struct PlatformDetectionTests {
    @Test("PlatformDetector returns valid info")
    func platformDetector() {
        let platform = PlatformDetector.current
        #expect(platform.isMacOS || platform.isLinux)
    }

    @Test("PlatformDetector correctly identifies platform type")
    func platformType() {
        let platform = PlatformDetector.current
        // Can't be both macOS and Linux
        #expect(!(platform.isMacOS && platform.isLinux))
    }

    #if os(macOS)
        @Test("macOS platform has correct properties")
        func macOSPlatform() {
            let platform = PlatformDetector.current
            #expect(platform.isMacOS)
            #expect(!platform.isLinux)
            #expect(platform.macOSVersion != nil)
        }
    #endif
}

@Suite("Prompt Building Tests")
struct PromptBuildingTests {
    @Test("PromptBuilder creates explain prompt")
    func explainPrompt() {
        let context = CommandContext(helpOutput: "Usage: git", manPageContent: nil, tldrContent: nil)
        let prompt = PromptBuilder.buildExplainPrompt(command: "git", context: context)
        #expect(prompt.contains("git"))
        #expect(prompt.lowercased().contains("explain"))
    }

    @Test("PromptBuilder creates suggest prompt")
    func suggestPrompt() {
        let prompt = PromptBuilder.buildSuggestPrompt(task: "find large files")
        #expect(prompt.contains("find large files"))
    }

    @Test("PromptBuilder creates examples prompt")
    func examplesPrompt() {
        let context = CommandContext(helpOutput: "tar help", manPageContent: nil, tldrContent: nil)
        let prompt = PromptBuilder.buildExamplesPrompt(command: "tar", context: context)
        #expect(prompt.contains("tar"))
        #expect(prompt.lowercased().contains("example"))
    }

    @Test("PromptBuilder creates man summary prompt")
    func manSummaryPrompt() {
        let manContent = "NAME\n\trsync -- a fast, versatile, remote file-copying tool"
        let prompt = PromptBuilder.buildManSummaryPrompt(command: "rsync", manContent: manContent)
        #expect(prompt.contains("rsync"))
        #expect(prompt.contains(manContent))
    }

    @Test("PromptBuilder handles empty context")
    func emptyContext() {
        let context = CommandContext(helpOutput: nil, manPageContent: nil, tldrContent: nil)
        let prompt = PromptBuilder.buildExplainPrompt(command: "unknown", context: context)
        #expect(prompt.contains("unknown"))
    }
}

@Suite("Configuration Tests")
struct ConfigurationTests {
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

    @Test("Config merging works correctly")
    func configMerging() {
        let base = Config.default
        var overlay = Config.default
        overlay.provider.defaultProvider = "ollama"
        overlay.cache.ttlDays = 14

        let merged = base.merged(with: overlay)
        #expect(merged.provider.defaultProvider == "ollama")
        #expect(merged.cache.ttlDays == 14)
    }

    @Test("Config environment override works")
    func environmentOverride() {
        // Note: This test depends on environment variables not being set
        let config = Config.default.applyingEnvironmentOverrides()
        // Default should still be there if env vars not set
        #expect(config.provider.fallback == Config.default.provider.fallback)
    }
}

@Suite("Cache Tests")
struct CacheTests {
    @Test("Cache key generation is deterministic")
    func cacheKeyDeterministic() {
        let key1 = ResponseCache.generateKey(command: "git", mode: "explain", provider: "ollama")
        let key2 = ResponseCache.generateKey(command: "git", mode: "explain", provider: "ollama")
        #expect(key1 == key2)
    }

    @Test("Cache key differs for different commands")
    func cacheKeysDiffer() {
        let key1 = ResponseCache.generateKey(command: "git", mode: "explain", provider: "ollama")
        let key2 = ResponseCache.generateKey(command: "ls", mode: "explain", provider: "ollama")
        #expect(key1 != key2)
    }

    @Test("Cache key differs for different modes")
    func cacheKeysDifferModes() {
        let key1 = ResponseCache.generateKey(command: "git", mode: "explain", provider: "ollama")
        let key2 = ResponseCache.generateKey(command: "git", mode: "suggest", provider: "ollama")
        #expect(key1 != key2)
    }

    @Test("Cache directory is in caches folder")
    func cacheDirectory() {
        let cacheDir = ResponseCache.cacheDirectory
        #expect(cacheDir.path.contains("clai"))
    }
}

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    @Test("ClaiError has descriptive messages")
    func errorMessages() {
        let noProvider = ClaiError.noProviderAvailable
        #expect(noProvider.errorDescription?.contains("provider") == true)

        let unavailable = ClaiError.providerUnavailable("ollama")
        #expect(unavailable.errorDescription?.contains("ollama") == true)

        let notFound = ClaiError.commandNotFound("nonexistent")
        #expect(notFound.errorDescription?.contains("nonexistent") == true)
    }
}

// MARK: - Integration Tests with Mock Provider

/// Actor for collecting chunks in a thread-safe way
actor ChunksCollector {
    var chunks: [String] = []

    func append(_ chunk: String) {
        chunks.append(chunk)
    }
}

/// Mock LLM provider for testing
struct MockLLMProvider: LLMProvider {
    let name = "Mock"
    let supportsStreaming = true
    let response: String

    init(response: String = "This is a mock response explaining the command.") {
        self.response = response
    }

    func generate(prompt: String) async throws -> String {
        response
    }

    func generateStreaming(prompt: String, onChunk: @escaping @Sendable (String) -> Void) async throws -> String {
        // Simulate streaming by sending chunks
        let words = response.split(separator: " ")
        for word in words {
            onChunk(String(word) + " ")
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return response
    }
}

@Suite("Integration Tests")
struct IntegrationTests {
    @Test("Mock provider returns expected response")
    func mockProviderResponse() async throws {
        let expectedResponse = "Git rebase is used to reapply commits."
        let provider = MockLLMProvider(response: expectedResponse)
        let result = try await provider.generate(prompt: "Explain git rebase")
        #expect(result == expectedResponse)
    }

    @Test("Mock provider streaming works")
    func mockProviderStreaming() async throws {
        let expectedResponse = "One two three four"
        let provider = MockLLMProvider(response: expectedResponse)

        let chunksActor = ChunksCollector()
        let result = try await provider.generateStreaming(prompt: "Test") { chunk in
            Task { await chunksActor.append(chunk) }
        }

        #expect(result == expectedResponse)
        // Give time for chunks to be collected
        try await Task.sleep(nanoseconds: 100_000_000)
        let collected = await chunksActor.chunks
        #expect(!collected.isEmpty)
    }

    @Test("GlobalOptions parses correctly")
    func globalOptionsParsing() throws {
        // Test that Provider enum works
        let provider = Provider(rawValue: "ollama")
        #expect(provider == .ollama)

        let invalid = Provider(rawValue: "invalid")
        #expect(invalid == nil)
    }
}

@Suite("String Extension Tests")
struct StringExtensionTests {
    @Test("SHA256 hash is consistent")
    func sha256Consistent() {
        let hash1 = "test string".sha256Hash
        let hash2 = "test string".sha256Hash
        #expect(hash1 == hash2)
    }

    @Test("SHA256 hash is correct length")
    func sha256Length() {
        let hash = "hello world".sha256Hash
        // SHA256 produces 64 hex characters
        #expect(hash.count == 64)
    }

    @Test("SHA256 hash differs for different inputs")
    func sha256Differs() {
        let hash1 = "input1".sha256Hash
        let hash2 = "input2".sha256Hash
        #expect(hash1 != hash2)
    }
}

// Import Yams for config tests
import Yams

// MARK: - Streaming Fallback Tests

/// Mock provider that does NOT support streaming
struct NonStreamingMockProvider: LLMProvider {
    let name = "NonStreamingMock"
    let supportsStreaming = false
    let response: String

    init(response: String = "Non-streaming response") {
        self.response = response
    }

    func generate(prompt: String) async throws -> String {
        response
    }

    func generateStreaming(prompt: String, onChunk: @escaping @Sendable (String) -> Void) async throws -> String {
        // This should never be called when supportsStreaming is false
        fatalError("generateStreaming called on non-streaming provider")
    }
}

/// Mock provider that returns empty response
struct EmptyResponseMockProvider: LLMProvider {
    let name = "EmptyMock"
    let supportsStreaming = true

    func generate(prompt: String) async throws -> String {
        ""
    }

    func generateStreaming(prompt: String, onChunk: @escaping @Sendable (String) -> Void) async throws -> String {
        ""
    }
}

@Suite("Streaming Support Tests")
struct StreamingSupportTests {
    @Test("Provider correctly reports streaming support")
    func streamingSupportFlag() {
        let streamingProvider = MockLLMProvider()
        let nonStreamingProvider = NonStreamingMockProvider()

        #expect(streamingProvider.supportsStreaming == true)
        #expect(nonStreamingProvider.supportsStreaming == false)
    }

    @Test("Non-streaming provider can still generate responses")
    func nonStreamingProviderGenerates() async throws {
        let provider = NonStreamingMockProvider(response: "Test response")
        let result = try await provider.generate(prompt: "Test")
        #expect(result == "Test response")
    }
}

@Suite("Empty Response Tests")
struct EmptyResponseTests {
    @Test("ClaiError.emptyResponse has descriptive message")
    func emptyResponseErrorMessage() {
        let error = ClaiError.emptyResponse("TestProvider")
        #expect(error.errorDescription?.contains("TestProvider") == true)
        #expect(error.errorDescription?.contains("empty") == true)
    }
}
