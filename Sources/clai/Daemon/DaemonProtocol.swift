import Foundation

// MARK: - Socket Path

/// Unix socket path for daemon communication
enum DaemonPaths {
    static let socketDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".clai")

    static let socketPath: URL = socketDirectory.appendingPathComponent("clai.sock")

    static let pidFile: URL = socketDirectory.appendingPathComponent("daemon.pid")

    static let logFile: URL = socketDirectory.appendingPathComponent("daemon.log")
}

// MARK: - Request Types

/// Request types sent to daemon
enum DaemonRequest: Codable, Sendable {
    /// Complete a partial command
    case complete(CompletionRequest)

    /// Explain a command
    case explain(ExplainRequest)

    /// Suggest a command for a task
    case suggest(SuggestRequest)

    /// Ping to check daemon health
    case ping

    /// Shutdown the daemon
    case shutdown
}

/// Request for command completion
struct CompletionRequest: Codable, Sendable {
    /// The partial command to complete
    let partial: String

    /// Current working directory
    let workingDirectory: String?

    /// Shell type
    let shell: String?
}

/// Request to explain a command
struct ExplainRequest: Codable, Sendable {
    /// The command to explain
    let command: String
}

/// Request to suggest commands for a task
struct SuggestRequest: Codable, Sendable {
    /// Natural language description of the task
    let task: String
}

// MARK: - Response Types

/// Response from daemon
enum DaemonResponse: Codable, Sendable {
    /// Successful response with data
    case success(DaemonResult)

    /// Error response
    case error(DaemonErrorResponse)

    /// Timeout response
    case timeout

    /// Pong response (for ping)
    case pong(PongResponse)

    /// Shutdown acknowledged
    case shutdownAck
}

/// Result types from daemon
enum DaemonResult: Codable, Sendable {
    /// Completion suggestions
    case completions([CompletionSuggestion])

    /// Command explanation
    case explanation(ExplanationResult)

    /// Command suggestions
    case suggestions([CommandSuggestion])
}

/// A single completion suggestion
struct CompletionSuggestion: Codable, Sendable {
    /// The suggested completion
    let completion: String

    /// Brief description of what this completion does
    let description: String?

    /// Priority score (higher = more relevant)
    let score: Double
}

/// Result of explaining a command
struct ExplanationResult: Codable, Sendable {
    /// Plain text explanation
    let explanation: String

    /// Whether the command is destructive
    let isDestructive: Bool

    /// Warnings about the command
    let warnings: [String]
}

/// A command suggestion for a task
struct CommandSuggestion: Codable, Sendable {
    /// The suggested command
    let command: String

    /// Explanation of what the command does
    let explanation: String
}

/// Error response from daemon
struct DaemonErrorResponse: Codable, Sendable {
    /// Error message
    let message: String

    /// Error code for programmatic handling
    let code: ErrorCode

    enum ErrorCode: String, Codable, Sendable {
        case providerUnavailable
        case timeout
        case invalidRequest
        case internalError
    }
}

/// Pong response with daemon status
struct PongResponse: Codable, Sendable {
    /// Daemon uptime in seconds
    let uptimeSeconds: Double

    /// Current provider name
    let provider: String

    /// Whether provider is ready
    let providerReady: Bool
}

// MARK: - Wire Protocol

/// Protocol for encoding/decoding messages over the socket
enum DaemonWireProtocol {
    /// Encode a request for transmission
    static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        var data = try encoder.encode(value)
        // Append newline as message delimiter
        data.append(0x0A) // newline
        return data
    }

    /// Decode a response from received data
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        // Remove trailing newline if present
        var trimmedData = data
        if let last = trimmedData.last, last == 0x0A {
            trimmedData = trimmedData.dropLast()
        }
        return try decoder.decode(type, from: trimmedData)
    }
}

// MARK: - Daemon Errors

/// Errors that can occur during daemon operations
enum DaemonError: Error, LocalizedError {
    case alreadyRunning
    case notRunning
    case socketCreationFailed(errno: Int32)
    case bindFailed(errno: Int32)
    case listenFailed(errno: Int32)
    case connectionFailed(errno: Int32)
    case timeout
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            "Daemon is already running"
        case .notRunning:
            "Daemon is not running"
        case let .socketCreationFailed(errno):
            "Failed to create socket: \(String(cString: strerror(errno)))"
        case let .bindFailed(errno):
            "Failed to bind socket: \(String(cString: strerror(errno)))"
        case let .listenFailed(errno):
            "Failed to listen on socket: \(String(cString: strerror(errno)))"
        case let .connectionFailed(errno):
            "Failed to connect: \(String(cString: strerror(errno)))"
        case .timeout:
            "Request timed out"
        case .invalidResponse:
            "Invalid response from daemon"
        }
    }
}

// MARK: - Daemon Configuration

/// Configuration for daemon behavior
struct DaemonConfig: Codable, Sendable {
    /// Timeout for AI responses in milliseconds
    var responseTimeoutMs: Int

    /// Maximum concurrent requests
    var maxConcurrentRequests: Int

    /// Whether to preload provider on startup
    var preloadProvider: Bool

    static var `default`: DaemonConfig {
        DaemonConfig(
            responseTimeoutMs: 200,
            maxConcurrentRequests: 4,
            preloadProvider: true
        )
    }

    enum CodingKeys: String, CodingKey {
        case responseTimeoutMs = "response_timeout_ms"
        case maxConcurrentRequests = "max_concurrent_requests"
        case preloadProvider = "preload_provider"
    }
}
