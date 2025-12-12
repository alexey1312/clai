import Foundation

/// Utility for handling network operations with retry logic
enum NetworkRetry {
    /// Default retry configuration
    struct Configuration: Sendable {
        /// Maximum number of retry attempts
        let maxRetries: Int

        /// Initial delay between retries (doubles each attempt)
        let initialDelay: TimeInterval

        /// Maximum delay between retries
        let maxDelay: TimeInterval

        /// Default configuration: 3 retries with exponential backoff
        static let `default` = Configuration(
            maxRetries: 3,
            initialDelay: 1.0,
            maxDelay: 30.0
        )

        /// Aggressive configuration: 5 retries with longer delays
        static let aggressive = Configuration(
            maxRetries: 5,
            initialDelay: 2.0,
            maxDelay: 60.0
        )
    }

    /// Execute an operation with retry logic
    /// - Parameters:
    ///   - config: Retry configuration
    ///   - operation: The async operation to execute
    ///   - onRetry: Called before each retry with attempt number and error
    /// - Returns: The result of the operation
    static func execute<T>(
        config: Configuration = .default,
        operation: @Sendable () async throws -> T,
        onRetry: (@Sendable (Int, Error) async -> Void)? = nil
    ) async throws -> T {
        var lastError: Error?
        var delay = config.initialDelay

        for attempt in 1 ... config.maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Don't retry non-recoverable errors
                if let claiError = error as? ClaiError, !claiError.isRecoverable {
                    throw error
                }

                // Don't retry if this was the last attempt
                if attempt == config.maxRetries {
                    break
                }

                // Notify about retry
                await onRetry?(attempt, error)

                // Wait before next attempt (exponential backoff)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // Increase delay for next attempt
                delay = min(delay * 2, config.maxDelay)
            }
        }

        // All retries exhausted
        if let lastError {
            throw lastError
        }

        // Should never reach here
        throw ClaiError.networkError("Operation failed")
    }

    /// Check if an error is a network-related error
    static func isNetworkError(_ error: Error) -> Bool {
        // Check for URLError types
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed:
                return true
            default:
                return false
            }
        }

        // Check for our own network errors
        if let claiError = error as? ClaiError {
            return claiError.isRecoverable
        }

        // Check error description for common network error patterns
        let description = error.localizedDescription.lowercased()
        return description.contains("network")
            || description.contains("connection")
            || description.contains("timeout")
            || description.contains("offline")
    }
}

// MARK: - Download Tracking

/// Tracks download progress for resume support
final class DownloadTracker: @unchecked Sendable {
    /// Download state
    struct State: Codable {
        let url: String
        var bytesDownloaded: Int64
        var totalBytes: Int64
        var lastModified: Date

        var progress: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(bytesDownloaded) / Double(totalBytes)
        }

        var isComplete: Bool {
            bytesDownloaded >= totalBytes && totalBytes > 0
        }
    }

    private let stateFileURL: URL

    init(identifier: String) {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let claiCacheDir = cacheDir.appendingPathComponent("clai")
        stateFileURL = claiCacheDir.appendingPathComponent("download_\(identifier).json")
    }

    /// Load existing download state
    func loadState() -> State? {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: stateFileURL)
            return try JSONDecoder().decode(State.self, from: data)
        } catch {
            return nil
        }
    }

    /// Save download state
    func saveState(_ state: State) {
        do {
            let dir = stateFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(state)
            try data.write(to: stateFileURL)
        } catch {
            // Silently fail - state tracking is best-effort
        }
    }

    /// Clear download state
    func clearState() {
        try? FileManager.default.removeItem(at: stateFileURL)
    }

    /// Update progress
    func updateProgress(bytesDownloaded: Int64, totalBytes: Int64, url: String) {
        let state = State(
            url: url,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            lastModified: Date()
        )
        saveState(state)
    }
}
