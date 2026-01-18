import Foundation

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

/// Unix socket server for handling shell integration requests
actor DaemonServer {
    private let socketPath: URL
    private var serverSocket: Int32 = -1
    private var isRunning = false
    private let startTime: Date
    private var providerManager: ProviderManager?
    private var currentProvider: (any LLMProvider)?
    private let config: DaemonConfig
    private var activeConnections = 0
    private let maxConnections: Int

    init(socketPath: URL = DaemonPaths.socketPath, config: DaemonConfig = .default) {
        self.socketPath = socketPath
        self.config = config
        maxConnections = config.maxConcurrentRequests
        startTime = Date()
    }

    // MARK: - Lifecycle

    /// Start the daemon server
    func start() async throws {
        guard !isRunning else {
            throw DaemonError.alreadyRunning
        }

        // Ensure socket directory exists
        let socketDir = socketPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: socketDir, withIntermediateDirectories: true)

        // Remove existing socket file if present
        if FileManager.default.fileExists(atPath: socketPath.path) {
            try FileManager.default.removeItem(at: socketPath)
        }

        // Create Unix domain socket
        #if canImport(Darwin)
            serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        #else
            serverSocket = socket(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0)
        #endif
        guard serverSocket >= 0 else {
            throw DaemonError.socketCreationFailed(errno: errno)
        }

        // Set socket options
        var reuseAddr: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        // Bind to socket path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.path.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let pathPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
            for (index, byte) in pathBytes.enumerated() {
                pathPtr[index] = byte
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult >= 0 else {
            close(serverSocket)
            throw DaemonError.bindFailed(errno: errno)
        }

        // Listen for connections
        guard listen(serverSocket, 5) >= 0 else {
            close(serverSocket)
            throw DaemonError.listenFailed(errno: errno)
        }

        // Set socket to non-blocking mode
        let flags = fcntl(serverSocket, F_GETFL, 0)
        _ = fcntl(serverSocket, F_SETFL, flags | O_NONBLOCK)

        isRunning = true

        // Write PID file
        try writePIDFile()

        // Preload provider if configured
        if config.preloadProvider {
            await preloadProvider()
        }

        log("Daemon started, listening on \(socketPath.path)")
    }

    /// Accept and handle incoming connections
    /// - Parameter checkShutdown: Closure that returns true when shutdown is requested (for signal handling)
    func runAcceptLoop(checkShutdown: @escaping @Sendable () -> Bool = { false }) async throws {
        while isRunning {
            // Check for shutdown request from signal handler
            if checkShutdown() { break }

            // Poll for incoming connections with a short timeout
            var pollFd = pollfd(fd: serverSocket, events: Int16(POLLIN), revents: 0)

            let pollResult = poll(&pollFd, 1, 100) // 100ms timeout

            if pollResult > 0, pollFd.revents & Int16(POLLIN) != 0 {
                let clientSocket = accept(serverSocket, nil, nil)
                if clientSocket >= 0 {
                    if activeConnections < maxConnections {
                        activeConnections += 1
                        Task {
                            await handleConnection(clientSocket)
                            await decrementConnections()
                        }
                    } else {
                        // Too many connections, send error and close
                        sendErrorAndClose(clientSocket, message: "Too many concurrent connections")
                    }
                }
            }

            // Small yield to prevent tight loop
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
    }

    /// Stop the daemon server
    func stop() async {
        guard isRunning else { return }

        isRunning = false

        // Close server socket
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }

        // Remove socket file
        try? FileManager.default.removeItem(at: socketPath)

        // Remove PID file
        try? FileManager.default.removeItem(at: DaemonPaths.pidFile)

        log("Daemon stopped")
    }

    /// Check if server is running
    func getIsRunning() -> Bool {
        isRunning
    }

    /// Get daemon uptime in seconds
    func getUptime() -> Double {
        Date().timeIntervalSince(startTime)
    }

    /// Get current provider name
    func getProviderName() async -> String {
        currentProvider?.name ?? "none"
    }

    // MARK: - Connection Handling

    private func handleConnection(_ clientSocket: Int32) async {
        defer {
            close(clientSocket)
        }

        // Set client socket timeout
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(clientSocket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        // Read request
        guard let requestData = readFromSocket(clientSocket) else {
            return
        }

        // Decode request
        guard let request = try? DaemonWireProtocol.decode(DaemonRequest.self, from: requestData) else {
            sendResponse(clientSocket, .error(DaemonErrorResponse(message: "Invalid request", code: .invalidRequest)))
            return
        }

        // Handle request
        let response = await handleRequest(request)

        // Send response
        sendResponse(clientSocket, response)
    }

    private func handleRequest(_ request: DaemonRequest) async -> DaemonResponse {
        switch request {
        case .ping:
            return await .pong(PongResponse(
                uptimeSeconds: getUptime(),
                provider: getProviderName(),
                providerReady: currentProvider != nil
            ))

        case .shutdown:
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                await stop()
            }
            return .shutdownAck

        case let .complete(req):
            return await handleCompletion(req)

        case let .explain(req):
            return await handleExplain(req)

        case let .suggest(req):
            return await handleSuggest(req)
        }
    }

    private func handleCompletion(_ request: CompletionRequest) async -> DaemonResponse {
        guard let provider = currentProvider else {
            return .error(DaemonErrorResponse(message: "No provider available", code: .providerUnavailable))
        }

        do {
            let prompt = DaemonPromptBuilder.buildCompletionPrompt(request)
            let result = try await generateWithTimeout(provider: provider, prompt: prompt)
            let suggestions = DaemonResponseParser.parseCompletionSuggestions(result)
            return .success(.completions(suggestions))
        } catch is DaemonError {
            return .timeout
        } catch {
            return .error(DaemonErrorResponse(message: error.localizedDescription, code: .internalError))
        }
    }

    private func handleExplain(_ request: ExplainRequest) async -> DaemonResponse {
        guard let provider = currentProvider else {
            return .error(DaemonErrorResponse(message: "No provider available", code: .providerUnavailable))
        }

        do {
            let prompt = DaemonPromptBuilder.buildExplainPrompt(request.command)
            let result = try await generateWithTimeout(provider: provider, prompt: prompt, multiplier: 5)
            let explanation = DaemonResponseParser.parseExplanation(result)
            return .success(.explanation(explanation))
        } catch is DaemonError {
            return .timeout
        } catch {
            return .error(DaemonErrorResponse(message: error.localizedDescription, code: .internalError))
        }
    }

    private func handleSuggest(_ request: SuggestRequest) async -> DaemonResponse {
        guard let provider = currentProvider else {
            return .error(DaemonErrorResponse(message: "No provider available", code: .providerUnavailable))
        }

        do {
            let prompt = DaemonPromptBuilder.buildSuggestPrompt(request.task)
            let result = try await generateWithTimeout(provider: provider, prompt: prompt, multiplier: 5)
            let suggestions = DaemonResponseParser.parseSuggestions(result)
            return .success(.suggestions(suggestions))
        } catch is DaemonError {
            return .timeout
        } catch {
            return .error(DaemonErrorResponse(message: error.localizedDescription, code: .internalError))
        }
    }

    private func generateWithTimeout(
        provider: any LLMProvider,
        prompt: String,
        multiplier: Int = 1
    ) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await provider.generate(prompt: prompt)
            }

            group.addTask {
                let timeout = UInt64(self.config.responseTimeoutMs * multiplier) * 1_000_000
                try await Task.sleep(nanoseconds: timeout)
                throw DaemonError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Provider Management

    private func preloadProvider() async {
        let manager = ProviderManager(preferredProvider: nil)
        providerManager = manager

        do {
            let provider = try await manager.getAvailableProvider()
            currentProvider = provider
            log("Provider loaded: \(provider.name)")
        } catch {
            log("Failed to load provider: \(error.localizedDescription)")
        }
    }

    // MARK: - Socket I/O

    private func readFromSocket(_ socket: Int32) -> Data? {
        var buffer = [UInt8](repeating: 0, count: 8192)
        var data = Data()

        while true {
            let bytesRead = recv(socket, &buffer, buffer.count, 0)
            if bytesRead > 0 {
                data.append(contentsOf: buffer[0 ..< bytesRead])
                // Check for newline delimiter
                if buffer[0 ..< bytesRead].contains(0x0A) {
                    break
                }
            } else {
                break
            }
        }

        return data.isEmpty ? nil : data
    }

    private func sendResponse(_ socket: Int32, _ response: DaemonResponse) {
        guard let data = try? DaemonWireProtocol.encode(response) else { return }

        _ = data.withUnsafeBytes { buffer in
            send(socket, buffer.baseAddress, buffer.count, 0)
        }
    }

    private func sendErrorAndClose(_ socket: Int32, message: String) {
        let response = DaemonResponse.error(DaemonErrorResponse(message: message, code: .internalError))
        sendResponse(socket, response)
        close(socket)
    }

    private func decrementConnections() {
        activeConnections -= 1
    }

    // MARK: - Utility

    private func writePIDFile() throws {
        let pid = getpid()
        try String(pid).write(to: DaemonPaths.pidFile, atomically: true, encoding: .utf8)
    }

    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"

        if let data = logMessage.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: DaemonPaths.logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? data.write(to: DaemonPaths.logFile)
            }
        }
    }
}
