import Foundation

#if canImport(Metal)
    import Metal
#endif

/// Checks if MLX Metal libraries are available at runtime
enum MLXAvailabilityChecker {
    /// Check if MLX Metal is functional
    /// This prevents confusing error messages when MLX libraries aren't bundled
    static func isMLXFunctional() -> Bool {
        #if canImport(Metal)
            // First, check if Metal is available at all
            guard MTLCreateSystemDefaultDevice() != nil else {
                return false
            }

            // Check if MLX_DISABLE environment variable is set
            if ProcessInfo.processInfo.environment["CLAI_DISABLE_MLX"] != nil {
                return false
            }

            // Check if mlx.metallib exists next to the binary (colocated loading)
            // This is where MLX looks first when loading the Metal library
            let binaryDir = resolveExecutableDirectory()
            let metallibPath = (binaryDir as NSString).appendingPathComponent("mlx.metallib")

            if FileManager.default.fileExists(atPath: metallibPath) {
                return true
            }

            // Also check Resources/mlx.metallib (alternative colocated path)
            let resourcesMetallibPath = (binaryDir as NSString)
                .appendingPathComponent("Resources/mlx.metallib")
            if FileManager.default.fileExists(atPath: resourcesMetallibPath) {
                return true
            }

            // If running from a development build, metallib might be in bundle
            // Check if we're in a build directory (not Homebrew)
            if binaryDir.contains(".build/") || binaryDir.contains("DerivedData") {
                return true
            }

            // No metallib found - MLX will fail with "Failed to load metallib" error
            return false
        #else
            return false
        #endif
    }

    /// Get the directory containing the executable, following symlinks
    private static func resolveExecutableDirectory() -> String {
        // Try Bundle.main first (works for app bundles)
        if let bundlePath = Bundle.main.executablePath {
            let url = URL(fileURLWithPath: bundlePath)
            let resolved = url.resolvingSymlinksInPath()
            return resolved.deletingLastPathComponent().path
        }

        // Fallback to CommandLine for CLI tools
        let arg0 = CommandLine.arguments.first ?? ""
        let url = URL(fileURLWithPath: arg0)
        let resolved = url.resolvingSymlinksInPath()
        return resolved.deletingLastPathComponent().path
    }
}
