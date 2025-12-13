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
    /// Base URL for HuggingFace cache (traditional location)
    static var huggingFaceCacheURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")
    }

    /// Base URL for AnyLanguageModel/MLX-Swift-LM cache (Library/Caches location)
    static var libraryCacheURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Caches")
            .appendingPathComponent("models")
            .appendingPathComponent("mlx-community")
    }

    /// All cache URLs to search for models
    static var allCacheURLs: [URL] {
        [huggingFaceCacheURL, libraryCacheURL]
    }

    /// Discover downloaded MLX models from all cache locations
    static func discoverDownloaded() -> [MLXModelInfo] {
        var allModels: [MLXModelInfo] = []

        // Search Library cache first (~/Library/Caches/models/mlx-community/)
        // This is where AnyLanguageModel downloads models, so prefer this location
        allModels.append(contentsOf: discoverFromLibraryCache())

        // Search HuggingFace cache (~/.cache/huggingface/hub/)
        // Legacy location, kept for backward compatibility
        allModels.append(contentsOf: discoverFromHuggingFaceCache())

        // Deduplicate by modelId (first occurrence wins, which is Library cache)
        var seen = Set<String>()
        return allModels.filter { model in
            if seen.contains(model.modelId) {
                return false
            }
            seen.insert(model.modelId)
            return true
        }
        .sorted { $0.displayName < $1.displayName }
    }

    /// Discover models from HuggingFace cache (~/.cache/huggingface/hub/)
    private static func discoverFromHuggingFaceCache() -> [MLXModelInfo] {
        let fileManager = FileManager.default
        let cacheURL = huggingFaceCacheURL

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
        } catch {
            return []
        }
    }

    /// Discover models from Library cache (~/Library/Caches/models/mlx-community/)
    private static func discoverFromLibraryCache() -> [MLXModelInfo] {
        let fileManager = FileManager.default
        let cacheURL = libraryCacheURL

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

                // Skip hidden directories
                guard !dirName.hasPrefix(".") else {
                    return nil
                }

                // Check if this looks like a model directory (has config.json or model files)
                let configURL = url.appendingPathComponent("config.json")
                guard fileManager.fileExists(atPath: configURL.path) else {
                    return nil
                }

                // Model ID is mlx-community/<dirname>
                let modelId = "mlx-community/\(dirName)"

                // Calculate directory size
                let sizeBytes = directorySize(at: url)
                let sizeFormatted = ByteFormatter.format(sizeBytes)

                return MLXModelInfo(
                    modelId: modelId,
                    displayName: dirName,
                    sizeBytes: sizeBytes,
                    sizeFormatted: sizeFormatted,
                    isDownloaded: true,
                    isDefault: false,
                    cachePath: url,
                    description: nil
                )
            }
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

    /// Check if a specific model is downloaded locally
    static func isModelDownloaded(_ modelId: String) -> Bool {
        let fileManager = FileManager.default

        // Check Library cache first (~/Library/Caches/models/mlx-community/ModelName)
        let libDirName = libraryDirName(for: modelId)
        let libraryModelURL = libraryCacheURL.appendingPathComponent(libDirName)
        let configURL = libraryModelURL.appendingPathComponent("config.json")

        if fileManager.fileExists(atPath: configURL.path) {
            return true
        }

        // Check HuggingFace cache (~/.cache/huggingface/hub/models--mlx-community--ModelName)
        let hfDirName = huggingFaceDirName(for: modelId)
        let hfModelURL = huggingFaceCacheURL.appendingPathComponent(hfDirName)
        let hfSnapshotsURL = hfModelURL.appendingPathComponent("snapshots")

        return fileManager.fileExists(atPath: hfSnapshotsURL.path)
    }

    /// Delete a model from all cache locations
    static func deleteModel(_ modelId: String) throws {
        let fileManager = FileManager.default
        var deletedCount = 0

        // Try HuggingFace cache (~/.cache/huggingface/hub/models--mlx-community--ModelName)
        let hfDirName = huggingFaceDirName(for: modelId)
        let hfModelURL = huggingFaceCacheURL.appendingPathComponent(hfDirName)

        if fileManager.fileExists(atPath: hfModelURL.path) {
            try fileManager.removeItem(at: hfModelURL)
            deletedCount += 1
        }

        // Try Library cache (~/Library/Caches/models/mlx-community/ModelName)
        let libDirName = libraryDirName(for: modelId)
        let libraryModelURL = libraryCacheURL.appendingPathComponent(libDirName)

        if fileManager.fileExists(atPath: libraryModelURL.path) {
            try fileManager.removeItem(at: libraryModelURL)
            deletedCount += 1
        }

        guard deletedCount > 0 else {
            throw MLXModelError.modelNotFound(modelId)
        }
    }

    // MARK: - Private Helpers

    /// Convert model ID to HuggingFace cache directory name
    /// e.g., "mlx-community/Qwen3-4B-4bit" -> "models--mlx-community--Qwen3-4B-4bit"
    private static func huggingFaceDirName(for modelId: String) -> String {
        "models--\(modelId.replacingOccurrences(of: "/", with: "--"))"
    }

    /// Convert model ID to Library cache directory name
    /// e.g., "mlx-community/Qwen3-4B-4bit" -> "Qwen3-4B-4bit"
    private static func libraryDirName(for modelId: String) -> String {
        modelId.replacingOccurrences(of: "mlx-community/", with: "")
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
