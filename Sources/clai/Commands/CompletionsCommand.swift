import ArgumentParser
import Foundation

/// Command to manage shell completions and plugins
struct CompletionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "completions",
        abstract: "Manage shell completions and AI plugins",
        discussion: """
        Generate shell completion scripts and install AI-powered shell plugins.

        Subcommands:
          generate    Generate basic shell completion script
          install     Install AI-powered shell plugin with hotkeys
          uninstall   Remove installed shell plugin
          list        Show installed plugins

        Examples:
          clai completions generate zsh > ~/.zsh/completions/_clai
          clai completions install zsh
          clai completions list
        """,
        subcommands: [
            GenerateSubcommand.self,
            InstallSubcommand.self,
            UninstallSubcommand.self,
            ListSubcommand.self,
        ],
        defaultSubcommand: ListSubcommand.self
    )
}

// MARK: - Shell Type

enum ShellType: String, ExpressibleByArgument, CaseIterable {
    case zsh
    case bash
    case fish

    var configFile: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .zsh:
            return home.appendingPathComponent(".zshrc")
        case .bash:
            return home.appendingPathComponent(".bashrc")
        case .fish:
            return home.appendingPathComponent(".config/fish/config.fish")
        }
    }

    var pluginDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .zsh, .bash:
            return home.appendingPathComponent(".clai/plugins")
        case .fish:
            return home.appendingPathComponent(".config/fish/conf.d")
        }
    }

    var pluginFile: URL {
        switch self {
        case .zsh:
            pluginDirectory.appendingPathComponent("clai.zsh")
        case .bash:
            pluginDirectory.appendingPathComponent("clai.bash")
        case .fish:
            pluginDirectory.appendingPathComponent("clai.fish")
        }
    }

    var sourceLine: String {
        switch self {
        case .zsh:
            "source ~/.clai/plugins/clai.zsh"
        case .bash:
            "source ~/.clai/plugins/clai.bash"
        case .fish:
            "" // Fish auto-loads from conf.d
        }
    }
}

// MARK: - Generate Subcommand

extension CompletionsCommand {
    struct GenerateSubcommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "generate",
            abstract: "Generate basic shell completion script"
        )

        @Argument(help: "The shell to generate completions for (zsh, bash, fish)")
        var shell: ShellType

        func run() throws {
            let script: String = switch shell {
            case .zsh:
                Clai.completionScript(for: .zsh)
            case .bash:
                Clai.completionScript(for: .bash)
            case .fish:
                Clai.completionScript(for: .fish)
            }

            print(script)
        }
    }
}

// MARK: - Install Subcommand

extension CompletionsCommand {
    struct InstallSubcommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "install",
            abstract: "Install AI-powered shell plugin with hotkeys"
        )

        @Argument(help: "The shell to install plugin for (zsh, bash, fish)")
        var shell: ShellType

        @Flag(name: .long, help: "Overwrite existing plugin if present")
        var force = false

        func run() throws {
            let terminal = TerminalUI()

            // Check if already installed
            if FileManager.default.fileExists(atPath: shell.pluginFile.path), !force {
                terminal.showWarning("Plugin already installed at \(shell.pluginFile.path)")
                print("Use --force to overwrite")
                return
            }

            // Create plugin directory
            let pluginDir = shell.pluginDirectory
            try FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)

            // Get plugin content from embedded resources or generate
            let pluginContent = getPluginContent(for: shell)

            // Write plugin file
            try pluginContent.write(to: shell.pluginFile, atomically: true, encoding: .utf8)

            // For zsh/bash, add source line to config file
            if shell != .fish {
                try addSourceLine(for: shell)
            }

            terminal.showSuccess("Plugin installed for \(shell.rawValue)")
            print()
            print("  Plugin: \(shell.pluginFile.path)")

            if shell != .fish {
                print("  Config: Added source line to \(shell.configFile.path)")
            }

            print()
            print(Theme.applyBold("Hotkeys:"))
            print("  Ctrl+X Ctrl+E  Explain command at cursor")
            print("  Ctrl+X Ctrl+S  Suggest command from task description")
            print()
            print("To activate, restart your shell or run:")

            switch shell {
            case .zsh:
                print("  source ~/.zshrc")
            case .bash:
                print("  source ~/.bashrc")
            case .fish:
                print("  exec fish")
            }

            print()
            print(Theme.muted + "Tip: Start the daemon for faster responses: clai daemon start" + Theme.reset)
        }

        private func getPluginContent(for shell: ShellType) -> String {
            ShellPluginContent.content(for: shell)
        }

        private func addSourceLine(for shell: ShellType) throws {
            let configFile = shell.configFile
            let sourceLine = shell.sourceLine

            guard !sourceLine.isEmpty else { return }

            var content = ""
            if FileManager.default.fileExists(atPath: configFile.path) {
                content = try String(contentsOf: configFile, encoding: .utf8)

                // Check if already sourced
                if content.contains(sourceLine) {
                    return
                }
            }

            // Add source line with marker comment
            let addition = """

            # clai shell integration
            \(sourceLine)

            """

            content += addition
            try content.write(to: configFile, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Uninstall Subcommand

extension CompletionsCommand {
    struct UninstallSubcommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "uninstall",
            abstract: "Remove installed shell plugin"
        )

        @Argument(help: "The shell to uninstall plugin for (zsh, bash, fish)")
        var shell: ShellType

        func run() throws {
            let terminal = TerminalUI()

            // Check if installed
            guard FileManager.default.fileExists(atPath: shell.pluginFile.path) else {
                terminal.showInfo("Plugin not installed for \(shell.rawValue)")
                return
            }

            // Remove plugin file
            try FileManager.default.removeItem(at: shell.pluginFile)

            // For zsh/bash, remove source line from config
            if shell != .fish {
                try removeSourceLine(for: shell)
            }

            terminal.showSuccess("Plugin uninstalled for \(shell.rawValue)")
            print()
            print("Restart your shell to complete the removal.")
        }

        private func removeSourceLine(for shell: ShellType) throws {
            let configFile = shell.configFile
            let sourceLine = shell.sourceLine

            guard !sourceLine.isEmpty,
                  FileManager.default.fileExists(atPath: configFile.path)
            else {
                return
            }

            var content = try String(contentsOf: configFile, encoding: .utf8)

            // Remove the source line and marker comment
            let pattern = "\n# clai shell integration\n\(NSRegularExpression.escapedPattern(for: sourceLine))\n"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                content = regex.stringByReplacingMatches(
                    in: content,
                    range: NSRange(content.startIndex..., in: content),
                    withTemplate: "\n"
                )
            }

            // Also try simple removal
            content = content.replacingOccurrences(of: "# clai shell integration\n\(sourceLine)", with: "")
            content = content.replacingOccurrences(of: sourceLine, with: "")

            try content.write(to: configFile, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - List Subcommand

extension CompletionsCommand {
    struct ListSubcommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "Show installed shell plugins"
        )

        @Flag(name: .long, help: "Output as JSON")
        var json = false

        func run() throws {
            let results = ShellType.allCases.map { shell in
                ShellPluginStatus(
                    shell: shell,
                    installed: FileManager.default.fileExists(atPath: shell.pluginFile.path),
                    path: shell.pluginFile.path
                )
            }

            if json {
                printJSON(results)
            } else {
                printTable(results)
            }
        }

        private func printTable(_ results: [ShellPluginStatus]) {
            print()
            print(Theme.applyBold("Shell Plugins"))
            print()

            for result in results {
                let status = result.installed
                    ? Theme.success + "installed" + Theme.reset
                    : Theme.muted + "not installed" + Theme.reset

                let name = result.shell.rawValue.padding(toLength: 6, withPad: " ", startingAt: 0)
                print("  \(name) \(status)")
            }

            print()
            print("Install with: clai completions install <shell>")
        }

        private func printJSON(_ results: [ShellPluginStatus]) {
            let output = results.map { result in
                [
                    "shell": result.shell.rawValue,
                    "installed": result.installed,
                    "path": result.path,
                ] as [String: Any]
            }

            if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
               let jsonString = String(data: data, encoding: .utf8)
            {
                print(jsonString)
            }
        }
    }
}
