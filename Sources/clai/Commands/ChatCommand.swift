import ArgumentParser
import Foundation

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

struct ChatCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chat",
        abstract: "Start an interactive chat session",
        discussion: """
        Opens an interactive conversation with the CLI assistant.
        Context is preserved across messages, allowing follow-up questions.

        Examples:
          clai chat                        Start interactive session
          clai chat "explain git rebase"   Start with an initial question

        Commands during chat:
          /exit, /quit, /q    Exit the chat session
          /clear              Clear conversation history
          /history            Show conversation history
          /help               Show available commands
        """
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Optional initial message to start the conversation")
    var initialMessage: [String] = []

    mutating func run() async throws {
        // Require TTY for interactive mode
        guard isatty(STDIN_FILENO) != 0 else {
            throw ValidationError("Chat mode requires an interactive terminal")
        }

        let terminal = TerminalUI(verbose: options.verbose)
        let engine = ClaiEngine(options: options)
        let session = ChatSession()

        // Show welcome message
        showWelcome(terminal: terminal)

        // If initial message provided, process it first
        if !initialMessage.isEmpty {
            let message = initialMessage.joined(separator: " ")
            try await processMessage(message, engine: engine, session: session, terminal: terminal)
        }

        // Main chat loop
        while true {
            // Show prompt
            showPrompt(messageCount: session.count, terminal: terminal)

            // Read input
            guard let input = readLine() else {
                // EOF (Ctrl+D)
                print()
                showGoodbye(terminal: terminal)
                break
            }

            let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty input
            if trimmedInput.isEmpty {
                continue
            }

            // Handle special commands
            if trimmedInput.hasPrefix("/") {
                let shouldContinue = handleCommand(trimmedInput, session: session, terminal: terminal)
                if !shouldContinue {
                    break
                }
                continue
            }

            // Process the message
            do {
                try await processMessage(trimmedInput, engine: engine, session: session, terminal: terminal)
            } catch {
                terminal.showError("Error: \(error.localizedDescription)")
                terminal.showInfo("You can try again or type /exit to quit.")
            }
        }
    }

    private func showWelcome(terminal: TerminalUI) {
        print()
        terminal.showHeader("clai chat")
        print("\(Theme.muted)Interactive CLI assistant with conversation memory\(Theme.reset)")
        print()
        print("Type your questions about CLI commands. Use \(Theme.accent)/help\(Theme.reset) for commands.")
        print("Press \(Theme.accent)Ctrl+D\(Theme.reset) or type \(Theme.accent)/exit\(Theme.reset) to quit.")
        print()
    }

    private func showPrompt(messageCount: Int, terminal: TerminalUI) {
        let turnNumber = (messageCount / 2) + 1
        print("\(Theme.accent)[\(turnNumber)]\(Theme.reset) \(Theme.bold)>\(Theme.reset) ", terminator: "")
        fflush(nil)
    }

    private func showGoodbye(terminal: TerminalUI) {
        print("\(Theme.muted)Goodbye!\(Theme.reset)")
    }

    /// Handle slash commands, returns false if should exit
    private func handleCommand(_ command: String, session: ChatSession, terminal: TerminalUI) -> Bool {
        let cmd = command.lowercased()

        switch cmd {
        case "/exit", "/quit", "/q":
            showGoodbye(terminal: terminal)
            return false

        case "/clear":
            session.clear()
            terminal.showSuccess("Conversation cleared")
            return true

        case "/history":
            showHistory(session: session, terminal: terminal)
            return true

        case "/help":
            showHelp(terminal: terminal)
            return true

        default:
            terminal.showWarning("Unknown command: \(command)")
            terminal.showInfo("Type /help to see available commands.")
            return true
        }
    }

    private func showHistory(session: ChatSession, terminal: TerminalUI) {
        let messages = session.messages
        if messages.isEmpty {
            terminal.showInfo("No conversation history yet.")
            return
        }

        print()
        terminal.showHeader("Conversation History")
        print()

        for (index, message) in messages.enumerated() {
            let roleLabel = message.role == .user
                ? "\(Theme.accent)You\(Theme.reset)"
                : "\(Theme.green)Assistant\(Theme.reset)"

            let turnNumber = (index / 2) + 1
            let preview = String(message.content.prefix(100))
                .replacingOccurrences(of: "\n", with: " ")
            let suffix = message.content.count > 100 ? "..." : ""

            print("[\(turnNumber)] \(roleLabel): \(preview)\(suffix)")
        }
        print()
    }

    private func showHelp(terminal: TerminalUI) {
        print()
        terminal.showHeader("Chat Commands")
        print()
        printCmd("/exit", "/quit", "/q", description: "Exit the chat session")
        printCmd("/clear", description: "Clear conversation history")
        printCmd("/history", description: "Show conversation history")
        printCmd("/help", description: "Show this help message")
        print()
        print("  \(Theme.muted)Ctrl+D\(Theme.reset)              Exit the chat session")
        print()
    }

    private func printCmd(_ cmds: String..., description: String) {
        let formatted = cmds
            .map { "\(Theme.accent)\($0)\(Theme.reset)" }
            .joined(separator: ", ")
        let padding = String(repeating: " ", count: max(0, 20 - cmds.joined().count))
        print("  \(formatted)\(padding)\(description)")
    }

    private func processMessage(
        _ message: String,
        engine: ClaiEngine,
        session: ChatSession,
        terminal: TerminalUI
    ) async throws {
        // Add user message to history
        session.addUserMessage(message)

        // Get recent history for context (excluding the current message which we just added)
        let historyForPrompt = Array(session.getRecentHistory().dropLast())

        print() // Blank line before response

        // Generate response
        let (response, providerName) = try await engine.chat(message: message, history: historyForPrompt)

        // Add response to history
        session.addAssistantMessage(response)

        // Show response (only if not already streamed)
        if !options.stream {
            terminal.showResponse(response, format: options.json ? .json : .plain)
        }

        terminal.showProviderAttribution(providerName)
    }
}
