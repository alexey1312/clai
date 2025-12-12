import Foundation

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

    /// Check if Ollama is running and accessible
    static func isAvailable(host: String = defaultHost) async -> Bool {
        guard let url = URL(string: "\(host)/api/tags") else {
            return false
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    /// Get list of available models (names only)
    static func availableModels(host: String = defaultHost) async -> [String] {
        guard let url = URL(string: "\(host)/api/tags") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            return response.models.map(\.name)
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
                let sizeBytes = model.size ?? 0

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
