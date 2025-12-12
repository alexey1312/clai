import Foundation

/// Information about an MLX model
struct MLXModelInfo: Sendable {
    /// Full model ID (e.g., "mlx-community/Qwen3-4B-4bit")
    let modelId: String

    /// Display name for UI
    let displayName: String

    /// Size in bytes (if downloaded)
    let sizeBytes: Int64?

    /// Human-readable size (e.g., "2.5GB")
    let sizeFormatted: String

    /// Whether the model is downloaded locally
    let isDownloaded: Bool

    /// Whether this is the current default model
    var isDefault: Bool

    /// Path to the model in cache (if downloaded)
    let cachePath: URL?

    /// Description of the model
    let description: String?
}

/// Discovery of MLX models in HuggingFace cache
enum MLXModelDiscovery {
    /// Base URL for HuggingFace cache
    static var cacheBaseURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
    }

    /// Discover downloaded MLX models from HuggingFace cache
    static func discoverDownloaded() -> [MLXModelInfo] {
        let fileManager = FileManager.default
        let cacheURL = cacheBaseURL

        guard fileManager.fileExists(atPath: cacheURL.path) else {
            return []
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            return contents.compactMap { url -> MLXModelInfo? in
                let dirName = url.lastPathComponent

                // Only look for mlx-community models.
                // This is intentional: we focus on curated MLX models from the mlx-community
                // organization which are optimized for Apple Silicon. Models from other
                // organizations may not be compatible or optimized for MLX inference.
                guard dirName.hasPrefix("models--mlx-community--") else {
                    return nil
                }

                // Parse model ID from directory name
                guard let modelId = parseModelId(from: dirName) else {
                    return nil
                }

                // Check if model has actual content (snapshots directory)
                let snapshotsURL = url.appendingPathComponent("snapshots")
                guard fileManager.fileExists(atPath: snapshotsURL.path) else {
                    return nil
                }

                // Calculate directory size
                let sizeBytes = directorySize(at: url)
                let sizeFormatted = ByteFormatter.format(sizeBytes)

                // Create display name from model ID
                let displayName = modelId
                    .replacingOccurrences(of: "mlx-community/", with: "")

                return MLXModelInfo(
                    modelId: modelId,
                    displayName: displayName,
                    sizeBytes: sizeBytes,
                    sizeFormatted: sizeFormatted,
                    isDownloaded: true,
                    isDefault: false,
                    cachePath: url,
                    description: nil
                )
            }
            .sorted { $0.displayName < $1.displayName }
        } catch {
            return []
        }
    }

    /// Parse model ID from cache directory name
    /// e.g., "models--mlx-community--Qwen3-4B-4bit" -> "mlx-community/Qwen3-4B-4bit"
    static func parseModelId(from directoryName: String) -> String? {
        guard directoryName.hasPrefix("models--") else {
            return nil
        }

        let withoutPrefix = String(directoryName.dropFirst("models--".count))
        let parts = withoutPrefix.split(separator: "--", maxSplits: 1)

        guard parts.count == 2 else {
            return nil
        }

        return "\(parts[0])/\(parts[1])"
    }

    /// Calculate total size of a directory
    static func directorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }

        return totalSize
    }

    /// Delete a model from cache
    static func deleteModel(_ modelId: String) throws {
        let dirName = "models--\(modelId.replacingOccurrences(of: "/", with: "--"))"
        let modelURL = cacheBaseURL.appendingPathComponent(dirName)

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw MLXModelError.modelNotFound(modelId)
        }

        try FileManager.default.removeItem(at: modelURL)
    }
}

/// Errors for MLX model operations
enum MLXModelError: Error, LocalizedError {
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .modelNotFound(modelId):
            "Model not found: \(modelId)"
        }
    }
}
