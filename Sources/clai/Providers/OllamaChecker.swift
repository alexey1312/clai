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

    /// Model digest (hash). Ollama API always returns this field.
    let digest: String
}

/// Checks Ollama availability
enum OllamaChecker {
    private static let defaultHost = "http://localhost:11434"

    // Cache the availability check to avoid redundant network requests
    // Using nonisolated(unsafe) to satisfy strict concurrency with NSLock
    private nonisolated(unsafe) static var _cachedAvailability: (host: String, timestamp: Date, isAvailable: Bool, models: [String]?)?
    private nonisolated(unsafe) static let _cacheLock = NSLock()
    private static let _cacheTTL: TimeInterval = 5.0 // 5 seconds

    /// Check if Ollama is running and accessible
    static func isAvailable(host: String = defaultHost) async -> Bool {
        // Check cache first
        _cacheLock.lock()
        if let cache = _cachedAvailability,
           cache.host == host,
           Date().timeIntervalSince(cache.timestamp) < _cacheTTL
        {
            let result = cache.isAvailable
            _cacheLock.unlock()
            return result
        }
        _cacheLock.unlock()

        let (isAvailable, models): (Bool, [String]?) = await {
            guard let url = URL(string: "\(host)/api/tags") else {
                return (false, nil)
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse else {
                    return (false, nil)
                }

                let isUp = httpResponse.statusCode == 200
                var fetchedModels: [String]?

                if isUp {
                    // Opportunistically decode models to populate cache
                    if let tagsResponse = try? JSONDecoder().decode(OllamaTagsResponse.self, from: data) {
                        fetchedModels = tagsResponse.models.map(\.name)
                    }
                }

                return (isUp, fetchedModels)
            } catch {
                return (false, nil)
            }
        }()

        // Update cache
        _cacheLock.lock()
        _cachedAvailability = (host: host, timestamp: Date(), isAvailable: isAvailable, models: models)
        _cacheLock.unlock()

        return isAvailable
    }

    /// Get list of available models (names only)
    static func availableModels(host: String = defaultHost) async -> [String] {
        // Check cache first
        _cacheLock.lock()
        if let cache = _cachedAvailability,
           cache.host == host,
           Date().timeIntervalSince(cache.timestamp) < _cacheTTL,
           let cachedModels = cache.models
        {
            _cacheLock.unlock()
            return cachedModels
        }
        _cacheLock.unlock()

        guard let url = URL(string: "\(host)/api/tags") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            let models = response.models.map(\.name)

            // Update cache with fresh models
            _cacheLock.lock()
            _cachedAvailability = (host: host, timestamp: Date(), isAvailable: true, models: models)
            _cacheLock.unlock()

            return models
        } catch {
            return []
        }
    }

    /// Get detailed information about available models
    static func availableModelsDetailed(host: String = defaultHost) async -> [OllamaModelInfo] {
        guard let url = URL(string: "\(host)/api/tags") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)

            return response.models.map { model in
                let sizeBytes = Int64(model.size ?? 0)

                return OllamaModelInfo(
                    name: model.name,
                    sizeBytes: sizeBytes,
                    sizeFormatted: ByteFormatter.format(sizeBytes),
                    digest: model.digest ?? ""
                )
            }
        } catch {
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
