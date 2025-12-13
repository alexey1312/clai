import Foundation

/// Curated model definition
struct CuratedMLXModel: Sendable {
    /// HuggingFace model ID
    let modelId: String

    /// Display name
    let displayName: String

    /// Estimated size when downloaded
    let estimatedSize: String

    /// Short description
    let description: String

    /// Whether this is the recommended default
    let isRecommended: Bool
}

/// Curated list of recommended MLX models for clai
enum CuratedModels {
    /// Recommended MLX models for CLI help assistant use case
    static let mlxModels: [CuratedMLXModel] = [
        CuratedMLXModel(
            modelId: "mlx-community/Qwen3-0.6B-4bit",
            displayName: "Qwen3 0.6B",
            estimatedSize: "~400MB",
            description: "Fastest, minimal memory",
            isRecommended: false
        ),
        CuratedMLXModel(
            modelId: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit",
            displayName: "DeepSeek R1 1.5B",
            estimatedSize: "~1GB",
            description: "Good reasoning ability",
            isRecommended: false
        ),
        CuratedMLXModel(
            modelId: "mlx-community/Qwen3-4B-4bit",
            displayName: "Qwen3 4B",
            estimatedSize: "~2.5GB",
            description: "Best balance of speed and quality",
            isRecommended: true
        ),
        CuratedMLXModel(
            modelId: "mlx-community/Qwen3-4B-Instruct-2507-4bit",
            displayName: "Qwen3 4B Instruct",
            estimatedSize: "~2.5GB",
            description: "Latest instruction-tuned",
            isRecommended: false
        ),
        CuratedMLXModel(
            modelId: "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit",
            displayName: "DeepSeek R1 7B",
            estimatedSize: "~4GB",
            description: "High quality, more memory",
            isRecommended: false
        ),
    ]

    /// Get curated model info, merging with downloaded status
    static func getModelsWithStatus(
        downloaded: [MLXModelInfo],
        defaultModelId: String
    ) -> [MLXModelInfo] {
        let downloadedIds = Set(downloaded.map(\.modelId))

        return mlxModels.map { curated in
            let isDownloaded = downloadedIds.contains(curated.modelId)
            let downloadedInfo = downloaded.first { $0.modelId == curated.modelId }

            return MLXModelInfo(
                modelId: curated.modelId,
                displayName: curated.displayName,
                sizeBytes: downloadedInfo?.sizeBytes,
                sizeFormatted: downloadedInfo?.sizeFormatted ?? curated.estimatedSize,
                isDownloaded: isDownloaded,
                isDefault: curated.modelId == defaultModelId,
                cachePath: downloadedInfo?.cachePath,
                description: curated.description
            )
        }
    }

    /// Find curated model by ID
    static func find(byId modelId: String) -> CuratedMLXModel? {
        mlxModels.first { $0.modelId == modelId }
    }

    /// Get the recommended model
    static var recommended: CuratedMLXModel {
        mlxModels.first { $0.isRecommended } ?? mlxModels[0]
    }

    /// Get estimated size for a model ID
    static func getEstimatedSize(for modelId: String) -> String {
        if let curated = find(byId: modelId) {
            return curated.estimatedSize
        }
        // Fallback for unknown models
        return "unknown size"
    }
}
