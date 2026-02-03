import ArgumentParser
import Foundation

struct ImproveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "improve",
        abstract: "Suggest optimizations based on usage patterns",
        discussion: """
        Analyze your command usage patterns and suggest optimizations like
        aliases, shell functions, and improved workflows.

        Examples:
          clai improve "docker ps -a --format '{{.Names}}'"
          clai improve --frequent
          clai improve --aliases
        """
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Command to analyze (optional)")
    var command: [String] = []

    @Flag(name: .long, help: "Show frequently used commands")
    var frequent = false

    @Flag(name: .long, help: "Show alias candidates based on usage")
    var aliases = false

    @Option(name: .long, help: "Minimum frequency for suggestions")
    var minFrequency: Int = 3

    @Flag(name: .long, help: "Use LLM for intelligent suggestions")
    var llm = false

    mutating func run() async throws {
        let store: HistoryStore
        do {
            store = try HistoryStore()
        } catch {
            throw ClaiError.historyError("Failed to open history store: \(error.localizedDescription)")
        }

        let terminal = TerminalUI()

        // Check consent and data, auto-index if needed
        let hasConsent = try store.hasConsent()
        let stats = try store.stats()

        if !hasConsent || stats.totalEntries == 0 {
            let indexed = try await promptAndIndex(store: store, hasConsent: hasConsent, terminal: terminal)
            if !indexed {
                return
            }
        }

        let analyzer = PatternAnalyzer(store: store)

        if aliases {
            try showAliasCandidates(analyzer: analyzer, terminal: terminal)
        } else if frequent {
            try showFrequentCommands(store: store, terminal: terminal)
        } else if !command.isEmpty {
            let commandString = command.joined(separator: " ")
            try await analyzeCommand(
                commandString,
                analyzer: analyzer,
                terminal: terminal,
                useLLM: llm
            )
        } else {
            // Default: show alias candidates
            try showAliasCandidates(analyzer: analyzer, terminal: terminal)
        }
    }

    private func showAliasCandidates(analyzer: PatternAnalyzer, terminal: TerminalUI) throws {
        let candidates = try analyzer.findAliasCandidates(minFrequency: minFrequency)

        if candidates.isEmpty {
            print("No alias candidates found with frequency >= \(minFrequency)")
            print()
            print("Tips:")
            print("  - Lower the threshold with --min-frequency 2")
            print("  - Use more commands and re-index with 'clai history index'")
            return
        }

        print()
        terminal.showHeader("Alias Candidates")
        print()
        print("Commands you use frequently that could be shortened:")
        print()

        for (index, candidate) in candidates.prefix(10).enumerated() {
            let prefix = Theme.muted + "[\(index + 1)]" + Theme.reset

            print("\(prefix) Used \(Theme.accent)\(candidate.frequency)x\(Theme.reset):")
            print("    \(Theme.muted)$\(Theme.reset) \(candidate.command)")
            print()
            print("    \(Theme.success)Suggested alias:\(Theme.reset)")
            print("    \(candidate.aliasCode)")
            print()
        }

        print(Theme.muted + "Add these to your ~/.zshrc or ~/.bashrc" + Theme.reset)
    }

    private func showFrequentCommands(store: HistoryStore, terminal: TerminalUI) throws {
        let frequent = try store.mostFrequent(limit: 20)

        if frequent.isEmpty {
            print("No commands in history")
            return
        }

        print()
        terminal.showHeader("Most Frequent Commands")
        print()

        for (index, result) in frequent.enumerated() {
            let prefix = Theme.muted + "[\(index + 1)]" + Theme.reset
            let freq = Theme.accent + "\(result.frequency)x" + Theme.reset

            print("\(prefix) \(freq) \(result.command)")
        }

        print()
    }

    private func analyzeCommand(
        _ command: String,
        analyzer: PatternAnalyzer,
        terminal: TerminalUI,
        useLLM: Bool
    ) async throws {
        print()

        let analysis = try analyzer.analyze(command: command)

        // Show frequency
        terminal.showHeader("Command Analysis")
        print()
        print("Command: \(Theme.accent)\(command)\(Theme.reset)")
        print("Used: \(analysis.frequency) time\(analysis.frequency == 1 ? "" : "s")")
        print()

        // Show suggestions
        if analysis.suggestions.isEmpty {
            print("No optimization suggestions for this command.")
            print()
            print("This might be because:")
            print("  - The command is already concise")
            print("  - It's not used frequently enough")
            print("  - It's a simple command that doesn't need optimization")
        } else {
            terminal.showHeader("Suggestions")
            print()

            for suggestion in analysis.suggestions {
                print("\(Theme.success)▸ \(suggestion.type.rawValue)\(Theme.reset)")
                print("  \(suggestion.description)")
                print()
                for line in suggestion.code.components(separatedBy: "\n") {
                    print("  \(Theme.muted)\(line)\(Theme.reset)")
                }
                print()
            }
        }

        // LLM-powered suggestions
        if useLLM {
            print()
            terminal.showHeader("AI Suggestions")
            print()

            let engine = try ClaiEngine(options: options)
            let prompt = buildImprovePrompt(command: command, analysis: analysis)

            let (response, wasStreamed) = try await generateImprovement(
                engine: engine,
                prompt: prompt,
                terminal: terminal
            )

            if !wasStreamed {
                terminal.showResponse(response, format: options.json ? .json : .plain)
            }
        }
    }

    private func buildImprovePrompt(command: String, analysis: CommandAnalysis) -> String {
        var prompt = """
        You are a shell optimization expert. Analyze this command and suggest improvements.

        Command: \(command)
        Usage frequency: \(analysis.frequency) times

        """

        if !analysis.similar.isEmpty {
            prompt += """

            Similar commands the user has run:
            \(analysis.similar.prefix(5).joined(separator: "\n"))

            """
        }

        prompt += """

        Provide practical suggestions for:
        1. Shorter aliases if the command is long
        2. Better flags or options
        3. Alternative commands that achieve the same result
        4. Shell functions for complex pipelines
        5. Any safety improvements (e.g., adding -i for interactive confirmation)

        Be concise and practical. Focus on real improvements, not theoretical ones.
        """

        return prompt
    }

    private func generateImprovement(
        engine: ClaiEngine,
        prompt: String,
        terminal: TerminalUI
    ) async throws -> (String, Bool) {
        // Use the suggest method which handles streaming appropriately
        // For now, we'll just return the prompt to be handled externally
        // This is a simplified version - the real implementation would use
        // ClaiEngine's internal generateResponse method
        ("", false)
    }

    private func promptAndIndex(
        store: HistoryStore,
        hasConsent: Bool,
        terminal: TerminalUI
    ) async throws -> Bool {
        print()
        print("clai can index your shell history to suggest optimizations.")
        print("All data stays local - nothing is sent to cloud providers.")
        print()

        let consented = await terminal.promptYesNo("Index your shell history?")

        if !consented {
            print("Cancelled. Run 'clai improve' again when ready.")
            return false
        }

        if !hasConsent {
            try store.setConsent(true)
        }

        print()
        let indexer = HistoryIndexer(store: store)
        let result = try await indexer.indexAll { progress, message in
            print("\r\u{001B}[K\(message) (\(Int(progress * 100))%)", terminator: "")
            try? FileHandle.standardOutput.synchronize()
        }
        print()
        print()

        if result.totalInserted == 0 {
            terminal.showWarning("No commands found in shell history")
            return false
        }

        let shells = result.shellsIndexed.map(\.rawValue).joined(separator: ", ")
        terminal.showSuccess("Indexed \(result.totalInserted) commands from \(shells)")
        print()

        return true
    }
}
