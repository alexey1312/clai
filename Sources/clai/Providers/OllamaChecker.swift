import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Information about an Ollama model
struct OllamaModelInfo: Sendable {
    /// Model name (e.g., "llama3.2:latest")
    let name: String

    /// Size in bytes
    let sizeBytes: Int64

    /// Human-readable size (e.g., "2.0GB")
    let sizeFormatted: String

    /// Model digest (hash)
    let digest: String
}

/// Checks Ollama availability
enum OllamaChecker {
    private static let defaultHost = "http://localhost:11434"

    // Cache structure for availability check results
    private struct AvailabilityCache: Sendable {
        let host: String
        let timestamp: Date
        let isAvailable: Bool
        let models: [OllamaModelInfo]?
    }

    // Using nonisolated(unsafe) to satisfy strict concurrency with NSLock
    private nonisolated(unsafe) static var _cachedAvailability: AvailabilityCache?
    private static let _cacheLock = NSLock()
    private static let _cacheTTL: TimeInterval = 5.0 // 5 seconds

    // Dedicated session with short timeout for availability checks
    private static let checkSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0.5 // Fail fast if unresponsive
        config.timeoutIntervalForResource = 1.0
        return URLSession(configuration: config)
    }()

    /// Check if Ollama is running and accessible
    static func isAvailable(host: String = defaultHost) async -> Bool {
        // Check cache first
        let cachedResult: Bool? = _cacheLock.withLock {
            if let cache = _cachedAvailability,
               cache.host == host,
               Date().timeIntervalSince(cache.timestamp) < _cacheTTL
            {
                return cache.isAvailable
            }
            return nil
        }

        if let result = cachedResult {
            return result
        }

        let isAvailable = await {
            guard let url = URL(string: "\(host)/") else {
                return false
            }

            do {
                let (_, response) = try await checkSession.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse else {
                    return false
                }

                return httpResponse.statusCode == 200
            } catch {
                // Network errors are expected when Ollama isn't running
                #if DEBUG
                    fputs("OllamaChecker: \(error.localizedDescription)\n", stderr)
                #endif
                return false
            }
        }()

        // Update cache
        _cacheLock.withLock {
            // Preserve existing models if they belong to the same host
            let existingModels = _cachedAvailability?.host == host ? _cachedAvailability?.models : nil
            _cachedAvailability = AvailabilityCache(
                host: host, timestamp: Date(), isAvailable: isAvailable, models: existingModels
            )
        }

        return isAvailable
    }

    /// Get list of available models (names only)
    static func availableModels(host: String = defaultHost) async -> [String] {
        await availableModelsDetailed(host: host).map(\.name)
    }

    /// Get detailed information about available models
    static func availableModelsDetailed(host: String = defaultHost) async -> [OllamaModelInfo] {
        // Check cache first
        let cachedModels: [OllamaModelInfo]? = _cacheLock.withLock {
            if let cache = _cachedAvailability,
               cache.host == host,
               Date().timeIntervalSince(cache.timestamp) < _cacheTTL,
               let models = cache.models
            {
                return models
            }
            return nil
        }

        if let models = cachedModels {
            return models
        }

        guard let url = URL(string: "\(host)/api/tags") else {
            return []
        }

        do {
            let (data, _) = try await checkSession.data(from: url)
            let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)

            let detailedModels: [OllamaModelInfo] = response.models.map { model in
                let sizeBytes = Int64(model.size ?? 0)
                return OllamaModelInfo(
                    name: model.name,
                    sizeBytes: sizeBytes,
                    sizeFormatted: ByteFormatter.format(sizeBytes),
                    digest: model.digest ?? ""
                )
            }

            // Update cache with fresh models
            _cacheLock.withLock {
                _cachedAvailability = AvailabilityCache(
                    host: host, timestamp: Date(), isAvailable: true, models: detailedModels
                )
            }

            return detailedModels
        } catch {
            #if DEBUG
                fputs("OllamaChecker.availableModelsDetailed: \(error.localizedDescription)\n", stderr)
            #endif
            return []
        }
    }

    /// Pull (download) a model from Ollama library with progress reporting
    /// - Parameters:
    ///   - model: Model name to pull (e.g., "llama3.2")
    ///   - host: Ollama host URL
    ///   - onProgress: Progress callback with (completed bytes, total bytes)
    /// - Returns: True if pull succeeded
    #if canImport(Darwin)
        static func pullModel(
            _ model: String,
            host: String = defaultHost,
            onProgress: @escaping @Sendable (Int64, Int64) -> Void
        ) async throws -> Bool {
            guard let url = URL(string: "\(host)/api/pull") else {
                throw OllamaError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = OllamaPullRequest(model: model, stream: true)
            request.httpBody = try JSONEncoder().encode(body)

            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200
            else {
                throw OllamaError.pullFailed(model)
            }

            var lastTotal: Int64 = 0
            var lastCompleted: Int64 = 0

            for try await line in bytes.lines {
                guard let data = line.data(using: .utf8) else { continue }

                if let pullResponse = try? JSONDecoder().decode(OllamaPullResponse.self, from: data) {
                    if let total = pullResponse.total, let completed = pullResponse.completed {
                        lastTotal = total
                        lastCompleted = completed
                        onProgress(completed, total)
                    }

                    if pullResponse.status == "success" {
                        return true
                    }

                    if let error = pullResponse.error {
                        throw OllamaError.pullError(error)
                    }
                }
            }

            // If we got here with some progress, consider it success
            return lastCompleted > 0 && lastCompleted >= lastTotal
        }
    #else
        static func pullModel(
            _ model: String,
            host: String = defaultHost,
            onProgress _: @escaping @Sendable (Int64, Int64) -> Void
        ) async throws -> Bool {
            guard let url = URL(string: "\(host)/api/pull") else {
                throw OllamaError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Use non-streaming on Linux (no progress updates)
            let body = OllamaPullRequest(model: model, stream: false)
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200
            else {
                throw OllamaError.pullFailed(model)
            }

            if let pullResponse = try? JSONDecoder().decode(OllamaPullResponse.self, from: data) {
                if pullResponse.status == "success" {
                    return true
                }
                if let error = pullResponse.error {
                    throw OllamaError.pullError(error)
                }
            }

            return true
        }
    #endif
}

// MARK: - Ollama Errors

enum OllamaError: Error, LocalizedError {
    case invalidURL
    case pullFailed(String)
    case pullError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid Ollama URL"
        case let .pullFailed(model):
            "Failed to pull model: \(model)"
        case let .pullError(message):
            "Ollama error: \(message)"
        }
    }
}

// MARK: - Ollama API Types

private struct OllamaTagsResponse: Codable {
    let models: [OllamaModel]
}

private struct OllamaModel: Codable {
    let name: String
    let size: Int64?
    let digest: String?
}

private struct OllamaPullRequest: Codable {
    let model: String
    let stream: Bool
}

private struct OllamaPullResponse: Codable {
    let status: String?
    let digest: String?
    let total: Int64?
    let completed: Int64?
    let error: String?
}
