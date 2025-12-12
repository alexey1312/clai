import Foundation

/// Errors that can occur during clai operations
enum ClaiError: Error, LocalizedError {
    case noProviderAvailable
    case providerUnavailable(String)
    case commandFailed(String)
    case commandNotFound(String)
    case networkError(String)
    case configurationError(String)
    case cacheError(String)
    case emptyResponse(String)
    case downloadFailed(String, retries: Int)
    case downloadInterrupted(String, progress: Double)

    var errorDescription: String? {
        switch self {
        case .noProviderAvailable:
            return "No LLM provider available. Run 'clai setup' for installation instructions."
        case let .providerUnavailable(provider):
            return "Provider '\(provider)' is not available."
        case let .commandFailed(command):
            return "Failed to execute: \(command)"
        case let .commandNotFound(command):
            return "Command not found: \(command)"
        case let .networkError(message):
            return "Network error: \(message)"
        case let .configurationError(message):
            return "Configuration error: \(message)"
        case let .cacheError(message):
            return "Cache error: \(message)"
        case let .emptyResponse(provider):
            return "Provider '\(provider)' returned an empty response."
        case let .downloadFailed(url, retries):
            return "Download failed after \(retries) attempts: \(url)"
        case let .downloadInterrupted(url, progress):
            let percentage = Int(progress * 100)
            return "Download interrupted at \(percentage)%: \(url)"
        }
    }

    /// Whether this error is recoverable with retry
    var isRecoverable: Bool {
        switch self {
        case .networkError, .downloadFailed, .downloadInterrupted:
            true
        default:
            false
        }
    }
}
