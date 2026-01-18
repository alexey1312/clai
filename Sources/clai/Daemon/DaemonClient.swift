import Foundation

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

/// Client for communicating with the clai daemon
struct DaemonClient: Sendable {
    private let socketPath: URL
    private let timeoutMs: Int

    init(socketPath: URL = DaemonPaths.socketPath, timeoutMs: Int = 200) {
        self.socketPath = socketPath
        self.timeoutMs = timeoutMs
    }

    // MARK: - Public API

    /// Check if daemon is running
    func isRunning() -> Bool {
        guard FileManager.default.fileExists(atPath: socketPath.path) else {
            return false
        }

        // Try to ping
        do {
            _ = try ping()
            return true
        } catch {
            return false
        }
    }

    /// Ping the daemon and get status
    func ping() throws -> PongResponse {
        let response = try sendRequest(.ping)

        guard case let .pong(pong) = response else {
            throw DaemonError.invalidResponse
        }

        return pong
    }

    /// Request command completions
    func complete(
        partial: String,
        shell: String? = nil,
        workingDirectory: String? = nil
    ) throws -> [CompletionSuggestion] {
        let request = CompletionRequest(
            partial: partial,
            workingDirectory: workingDirectory,
            shell: shell
        )

        let response = try sendRequest(.complete(request))

        switch response {
        case let .success(.completions(completions)):
            return completions
        case .timeout:
            return []
        case let .error(error):
            throw ClaiError.commandFailed(error.message)
        default:
            throw DaemonError.invalidResponse
        }
    }

    /// Request command explanation
    func explain(command: String) throws -> ExplanationResult {
        let request = ExplainRequest(command: command)
        let response = try sendRequest(.explain(request))

        switch response {
        case let .success(.explanation(explanation)):
            return explanation
        case .timeout:
            throw DaemonError.timeout
        case let .error(error):
            throw ClaiError.commandFailed(error.message)
        default:
            throw DaemonError.invalidResponse
        }
    }

    /// Request command suggestions for a task
    func suggest(task: String) throws -> [CommandSuggestion] {
        let request = SuggestRequest(task: task)
        let response = try sendRequest(.suggest(request))

        switch response {
        case let .success(.suggestions(suggestions)):
            return suggestions
        case .timeout:
            return []
        case let .error(error):
            throw ClaiError.commandFailed(error.message)
        default:
            throw DaemonError.invalidResponse
        }
    }

    /// Request daemon shutdown
    func shutdown() throws {
        let response = try sendRequest(.shutdown)

        guard case .shutdownAck = response else {
            throw DaemonError.invalidResponse
        }
    }

    // MARK: - Socket Communication

    private func sendRequest(_ request: DaemonRequest) throws -> DaemonResponse {
        // Create socket
        let clientSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard clientSocket >= 0 else {
            throw DaemonError.socketCreationFailed(errno: errno)
        }
        defer { close(clientSocket) }

        // Set timeout
        var timeout = timeval(
            tv_sec: __darwin_time_t(timeoutMs / 1000),
            tv_usec: __darwin_suseconds_t((timeoutMs % 1000) * 1000)
        )
        setsockopt(clientSocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(clientSocket, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        // Connect to daemon
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.path.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let pathPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
            for (index, byte) in pathBytes.enumerated() {
                pathPtr[index] = byte
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(clientSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult >= 0 else {
            throw DaemonError.connectionFailed(errno: errno)
        }

        // Send request
        let requestData = try DaemonWireProtocol.encode(request)
        let sendResult = requestData.withUnsafeBytes { buffer in
            send(clientSocket, buffer.baseAddress, buffer.count, 0)
        }

        guard sendResult > 0 else {
            throw DaemonError.connectionFailed(errno: errno)
        }

        // Receive response
        var responseBuffer = [UInt8](repeating: 0, count: 65536)
        var responseData = Data()

        while true {
            let bytesRead = recv(clientSocket, &responseBuffer, responseBuffer.count, 0)
            if bytesRead > 0 {
                responseData.append(contentsOf: responseBuffer[0 ..< bytesRead])
                if responseBuffer[0 ..< bytesRead].contains(0x0A) {
                    break
                }
            } else if bytesRead == 0 {
                break
            } else {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    throw DaemonError.timeout
                }
                throw DaemonError.connectionFailed(errno: errno)
            }
        }

        guard !responseData.isEmpty else {
            throw DaemonError.invalidResponse
        }

        return try DaemonWireProtocol.decode(DaemonResponse.self, from: responseData)
    }
}

// MARK: - Daemon Status Checker

/// Utility for checking daemon status without full client
enum DaemonStatus {
    /// Check if daemon is running by checking PID file and socket
    static func check() -> DaemonStatusInfo {
        let socketExists = FileManager.default.fileExists(atPath: DaemonPaths.socketPath.path)
        let pidFileExists = FileManager.default.fileExists(atPath: DaemonPaths.pidFile.path)

        var pid: Int32?
        var processRunning = false

        if pidFileExists, let pidString = try? String(contentsOf: DaemonPaths.pidFile, encoding: .utf8),
           let pidValue = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines))
        {
            pid = pidValue
            // Check if process is running
            processRunning = kill(pidValue, 0) == 0
        }

        // Try to ping if socket exists
        var pingSuccess = false
        var uptime: Double?
        var provider: String?

        if socketExists {
            let client = DaemonClient()
            if let pong = try? client.ping() {
                pingSuccess = true
                uptime = pong.uptimeSeconds
                provider = pong.provider
            }
        }

        return DaemonStatusInfo(
            isRunning: pingSuccess,
            socketExists: socketExists,
            pid: pid,
            processRunning: processRunning,
            uptime: uptime,
            provider: provider
        )
    }

    /// Kill daemon by PID if running
    static func killIfRunning() -> Bool {
        let status = check()

        if let pid = status.pid, status.processRunning {
            kill(pid, SIGTERM)
            return true
        }

        return false
    }
}

/// Information about daemon status
struct DaemonStatusInfo: Sendable {
    let isRunning: Bool
    let socketExists: Bool
    let pid: Int32?
    let processRunning: Bool
    let uptime: Double?
    let provider: String?

    var uptimeFormatted: String? {
        guard let uptime else { return nil }

        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let seconds = Int(uptime) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}
