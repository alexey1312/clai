import Foundation
import Testing

@testable import clai

// MARK: - Daemon Protocol Tests

@Suite("DaemonProtocol Tests")
struct DaemonProtocolTests {
    @Test("DaemonRequest ping encodes correctly")
    func pingRequestEncoding() throws {
        let request = DaemonRequest.ping
        let data = try DaemonWireProtocol.encode(request)
        let decoded = try DaemonWireProtocol.decode(DaemonRequest.self, from: data)

        if case .ping = decoded {
            // Success
        } else {
            Issue.record("Expected ping request")
        }
    }

    @Test("DaemonRequest shutdown encodes correctly")
    func shutdownRequestEncoding() throws {
        let request = DaemonRequest.shutdown
        let data = try DaemonWireProtocol.encode(request)
        let decoded = try DaemonWireProtocol.decode(DaemonRequest.self, from: data)

        if case .shutdown = decoded {
            // Success
        } else {
            Issue.record("Expected shutdown request")
        }
    }

    @Test("CompletionRequest encodes and decodes")
    func completionRequestEncoding() throws {
        let request = DaemonRequest.complete(CompletionRequest(
            partial: "git reb",
            workingDirectory: "/tmp",
            shell: "zsh"
        ))
        let data = try DaemonWireProtocol.encode(request)
        let decoded = try DaemonWireProtocol.decode(DaemonRequest.self, from: data)

        if case let .complete(req) = decoded {
            #expect(req.partial == "git reb")
            #expect(req.workingDirectory == "/tmp")
            #expect(req.shell == "zsh")
        } else {
            Issue.record("Expected complete request")
        }
    }

    @Test("ExplainRequest encodes and decodes")
    func explainRequestEncoding() throws {
        let request = DaemonRequest.explain(ExplainRequest(command: "ls -la"))
        let data = try DaemonWireProtocol.encode(request)
        let decoded = try DaemonWireProtocol.decode(DaemonRequest.self, from: data)

        if case let .explain(req) = decoded {
            #expect(req.command == "ls -la")
        } else {
            Issue.record("Expected explain request")
        }
    }

    @Test("SuggestRequest encodes and decodes")
    func suggestRequestEncoding() throws {
        let request = DaemonRequest.suggest(SuggestRequest(task: "compress folder"))
        let data = try DaemonWireProtocol.encode(request)
        let decoded = try DaemonWireProtocol.decode(DaemonRequest.self, from: data)

        if case let .suggest(req) = decoded {
            #expect(req.task == "compress folder")
        } else {
            Issue.record("Expected suggest request")
        }
    }

    @Test("DaemonResponse pong encodes correctly")
    func pongResponseEncoding() throws {
        let response = DaemonResponse.pong(PongResponse(
            uptimeSeconds: 123.45,
            provider: "ollama",
            providerReady: true
        ))
        let data = try DaemonWireProtocol.encode(response)
        let decoded = try DaemonWireProtocol.decode(DaemonResponse.self, from: data)

        if case let .pong(pong) = decoded {
            #expect(pong.uptimeSeconds == 123.45)
            #expect(pong.provider == "ollama")
            #expect(pong.providerReady == true)
        } else {
            Issue.record("Expected pong response")
        }
    }

    @Test("DaemonResponse error encodes correctly")
    func errorResponseEncoding() throws {
        let response = DaemonResponse.error(DaemonErrorResponse(
            message: "Provider not available",
            code: .providerUnavailable
        ))
        let data = try DaemonWireProtocol.encode(response)
        let decoded = try DaemonWireProtocol.decode(DaemonResponse.self, from: data)

        if case let .error(err) = decoded {
            #expect(err.message == "Provider not available")
            #expect(err.code == .providerUnavailable)
        } else {
            Issue.record("Expected error response")
        }
    }

    @Test("DaemonResponse timeout encodes correctly")
    func timeoutResponseEncoding() throws {
        let response = DaemonResponse.timeout
        let data = try DaemonWireProtocol.encode(response)
        let decoded = try DaemonWireProtocol.decode(DaemonResponse.self, from: data)

        if case .timeout = decoded {
            // Success
        } else {
            Issue.record("Expected timeout response")
        }
    }

    @Test("Wire protocol appends newline delimiter")
    func wireProtocolNewline() throws {
        let request = DaemonRequest.ping
        let data = try DaemonWireProtocol.encode(request)

        #expect(data.last == 0x0A) // Newline character
    }

    @Test("Wire protocol handles trailing newline in decode")
    func wireProtocolDecodeWithNewline() throws {
        let request = DaemonRequest.ping
        var data = try DaemonWireProtocol.encode(request)
        // Add extra newline
        data.append(0x0A)

        let decoded = try DaemonWireProtocol.decode(DaemonRequest.self, from: data)
        if case .ping = decoded {
            // Success
        } else {
            Issue.record("Expected ping request")
        }
    }
}

// MARK: - Daemon Config Tests

@Suite("DaemonConfig Tests")
struct DaemonConfigTests {
    @Test("Default config has expected values")
    func defaultConfig() {
        let config = DaemonConfig.default

        #expect(config.responseTimeoutMs == 200)
        #expect(config.maxConcurrentRequests == 4)
        #expect(config.preloadProvider == true)
    }

    @Test("Config encodes and decodes")
    func configEncoding() throws {
        let config = DaemonConfig(
            responseTimeoutMs: 500,
            maxConcurrentRequests: 8,
            preloadProvider: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DaemonConfig.self, from: data)

        #expect(decoded.responseTimeoutMs == 500)
        #expect(decoded.maxConcurrentRequests == 8)
        #expect(decoded.preloadProvider == false)
    }

    @Test("Config uses snake_case keys")
    func configCodingKeys() throws {
        let config = DaemonConfig.default
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("response_timeout_ms"))
        #expect(json.contains("max_concurrent_requests"))
        #expect(json.contains("preload_provider"))
    }
}

// MARK: - Daemon Paths Tests

@Suite("DaemonPaths Tests")
struct DaemonPathsTests {
    @Test("Socket path is in home directory")
    func socketPathLocation() {
        let socketPath = DaemonPaths.socketPath.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        #expect(socketPath.hasPrefix(home))
        #expect(socketPath.contains(".clai"))
        #expect(socketPath.hasSuffix("clai.sock"))
    }

    @Test("PID file path is in socket directory")
    func pidFilePath() {
        let pidPath = DaemonPaths.pidFile.path
        let socketDir = DaemonPaths.socketDirectory.path

        #expect(pidPath.hasPrefix(socketDir))
        #expect(pidPath.hasSuffix("daemon.pid"))
    }

    @Test("Log file path is in socket directory")
    func logFilePath() {
        let logPath = DaemonPaths.logFile.path
        let socketDir = DaemonPaths.socketDirectory.path

        #expect(logPath.hasPrefix(socketDir))
        #expect(logPath.hasSuffix("daemon.log"))
    }
}

// MARK: - Daemon Status Tests

@Suite("DaemonStatusInfo Tests")
struct DaemonStatusInfoTests {
    @Test("Uptime formatted for seconds")
    func uptimeSeconds() {
        let status = DaemonStatusInfo(
            isRunning: true,
            socketExists: true,
            pid: 1234,
            processRunning: true,
            uptime: 45,
            provider: "ollama"
        )

        #expect(status.uptimeFormatted == "45s")
    }

    @Test("Uptime formatted for minutes")
    func uptimeMinutes() {
        let status = DaemonStatusInfo(
            isRunning: true,
            socketExists: true,
            pid: 1234,
            processRunning: true,
            uptime: 125, // 2m 5s
            provider: "ollama"
        )

        #expect(status.uptimeFormatted == "2m 5s")
    }

    @Test("Uptime formatted for hours")
    func uptimeHours() {
        let status = DaemonStatusInfo(
            isRunning: true,
            socketExists: true,
            pid: 1234,
            processRunning: true,
            uptime: 3725, // 1h 2m 5s
            provider: "ollama"
        )

        #expect(status.uptimeFormatted == "1h 2m 5s")
    }

    @Test("Uptime nil when not running")
    func uptimeNil() {
        let status = DaemonStatusInfo(
            isRunning: false,
            socketExists: false,
            pid: nil,
            processRunning: false,
            uptime: nil,
            provider: nil
        )

        #expect(status.uptimeFormatted == nil)
    }
}

// MARK: - Response Type Tests

@Suite("DaemonResult Tests")
struct DaemonResultTests {
    @Test("CompletionSuggestion stores values")
    func completionSuggestion() {
        let suggestion = CompletionSuggestion(
            completion: "git rebase",
            description: "Reapply commits on top of another base",
            score: 0.95
        )

        #expect(suggestion.completion == "git rebase")
        #expect(suggestion.description == "Reapply commits on top of another base")
        #expect(suggestion.score == 0.95)
    }

    @Test("ExplanationResult stores values")
    func explanationResult() {
        let result = ExplanationResult(
            explanation: "Lists files in long format",
            isDestructive: false,
            warnings: ["Shows hidden files"]
        )

        #expect(result.explanation == "Lists files in long format")
        #expect(result.isDestructive == false)
        #expect(result.warnings == ["Shows hidden files"])
    }

    @Test("CommandSuggestion stores values")
    func commandSuggestion() {
        let suggestion = CommandSuggestion(
            command: "tar -czvf archive.tar.gz folder/",
            explanation: "Compress folder with gzip"
        )

        #expect(suggestion.command == "tar -czvf archive.tar.gz folder/")
        #expect(suggestion.explanation == "Compress folder with gzip")
    }

    @Test("DaemonErrorResponse error codes")
    func errorCodes() {
        #expect(DaemonErrorResponse.ErrorCode.providerUnavailable.rawValue == "providerUnavailable")
        #expect(DaemonErrorResponse.ErrorCode.timeout.rawValue == "timeout")
        #expect(DaemonErrorResponse.ErrorCode.invalidRequest.rawValue == "invalidRequest")
        #expect(DaemonErrorResponse.ErrorCode.internalError.rawValue == "internalError")
    }
}

// MARK: - Daemon Error Tests

@Suite("DaemonError Tests")
struct DaemonErrorTests {
    @Test("Error descriptions are meaningful")
    func errorDescriptions() {
        #expect(DaemonError.alreadyRunning.errorDescription?.contains("already running") == true)
        #expect(DaemonError.notRunning.errorDescription?.contains("not running") == true)
        #expect(DaemonError.timeout.errorDescription?.contains("timed out") == true)
        #expect(DaemonError.invalidResponse.errorDescription?.contains("Invalid") == true)
    }

    @Test("Socket errors include errno info")
    func socketErrorsWithErrno() {
        let socketError = DaemonError.socketCreationFailed(errno: 13)
        #expect(socketError.errorDescription?.contains("socket") == true)

        let bindError = DaemonError.bindFailed(errno: 48)
        #expect(bindError.errorDescription?.contains("bind") == true)

        let listenError = DaemonError.listenFailed(errno: 22)
        #expect(listenError.errorDescription?.contains("listen") == true)

        let connectError = DaemonError.connectionFailed(errno: 61)
        #expect(connectError.errorDescription?.contains("connect") == true)
    }
}
