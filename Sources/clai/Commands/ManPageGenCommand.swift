import ArgumentParser
import Foundation

/// Command to generate man page for clai
struct ManPageGenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "man-page",
        abstract: "Generate man page for clai",
        discussion: """
        Generates a man page in mdoc format from the CLI's help information.

        Examples:
          clai man-page                 Output to stdout
          clai man-page -o clai.1       Write to file
          clai man-page > man/clai.1    Redirect to file

        To view the generated man page:
          man ./clai.1
        """
    )

    @Option(name: .shortAndLong, help: "Output file path (use '-' for stdout)")
    var output: String = "-"

    @Option(help: "Man page section number")
    var section: Int = 1

    func run() throws {
        let toolInfo = try getDumpHelp()
        let generator = ManPageGenerator(command: toolInfo.command, section: section)
        let manPage = generator.generate()

        if output == "-" {
            print(manPage)
        } else {
            let outputURL = URL(fileURLWithPath: output)
            let parentDir = outputURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try manPage.write(to: outputURL, atomically: true, encoding: .utf8)
            print("Man page written to \(outputURL.path)")
        }
    }
}

// MARK: - Man Page Generator

private struct ManPageGenerator {
    let command: CommandInfoV0
    let section: Int

    func generate() -> String {
        var lines: [String] = []

        lines.append(contentsOf: buildHeader())
        lines.append(contentsOf: buildNameSection())
        lines.append(contentsOf: buildSynopsisSection())
        lines.append(contentsOf: buildDescriptionSection())
        lines.append(contentsOf: buildOptionsSection())
        lines.append(contentsOf: buildCommandsSection())
        lines.append(contentsOf: buildEnvironmentSection())
        lines.append(contentsOf: buildFilesSection())
        lines.append(contentsOf: buildExamplesSection())
        lines.append(contentsOf: buildFooterSections())

        return lines.joined(separator: "\n")
    }

    private func buildHeader() -> [String] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withDashSeparatorInDate]
        let date = formatter.string(from: Date())
        let commandUpper = command.commandName.uppercased()

        return [
            ".Dd \(date)",
            ".Dt \(commandUpper) \(section)",
            ".Os",
            "",
        ]
    }

    private func buildNameSection() -> [String] {
        var lines = [".Sh NAME", ".Nm \(command.commandName)"]
        if let abstract = command.abstract {
            lines.append(".Nd \(escapeManPage(abstract))")
        }
        lines.append("")
        return lines
    }

    private func buildSynopsisSection() -> [String] {
        var lines = [".Sh SYNOPSIS", ".Nm \(command.commandName)"]

        let displayableArgs = (command.arguments ?? []).filter(\.shouldDisplay)
        let options = displayableArgs.filter { $0.kind == "option" || $0.kind == "flag" }

        for arg in options {
            if let preferred = arg.preferredName {
                let flag = preferred.kind == "short" ? "-\(preferred.name)" : "--\(preferred.name)"
                if arg.kind == "option" {
                    lines.append(".Op Fl \(flag.dropFirst()) Ar \(arg.valueName ?? "value")")
                } else {
                    lines.append(".Op Fl \(flag.dropFirst())")
                }
            }
        }

        let positionals = displayableArgs.filter { $0.kind == "positional" }
        for arg in positionals {
            let name = arg.valueName ?? "arg"
            lines.append(arg.isOptional ? ".Op Ar \(name)" : ".Ar \(name)")
        }

        if let subcommands = command.subcommands, !subcommands.isEmpty {
            lines.append(".Op Ar command")
        }

        lines.append("")
        return lines
    }

    private func buildDescriptionSection() -> [String] {
        var lines = [".Sh DESCRIPTION"]
        if let discussion = command.discussion {
            lines.append(escapeManPage(discussion))
        } else if let abstract = command.abstract {
            lines.append(escapeManPage(abstract))
        }
        lines.append("")
        return lines
    }

    private func buildOptionsSection() -> [String] {
        let displayableArgs = (command.arguments ?? []).filter(\.shouldDisplay)
        let options = displayableArgs.filter { $0.kind == "option" || $0.kind == "flag" }

        guard !options.isEmpty else { return [] }

        var lines = [".Sh OPTIONS", ".Bl -tag -width Ds"]
        for arg in options {
            lines.append(arg.toManPage())
        }
        lines.append(".El")
        lines.append("")
        return lines
    }

    private func buildCommandsSection() -> [String] {
        guard let subcommands = command.subcommands else { return [] }
        let displayableSubcommands = subcommands.filter(\.shouldDisplay)
        guard !displayableSubcommands.isEmpty else { return [] }

        var lines = [".Sh COMMANDS", ".Bl -tag -width Ds"]
        for subcmd in displayableSubcommands {
            lines.append(contentsOf: formatSubcommand(subcmd))
        }
        lines.append(".El")
        lines.append("")
        return lines
    }

    private func formatSubcommand(_ subcmd: CommandInfoV0) -> [String] {
        var lines = [".It Ic \(subcmd.commandName)"]

        if let abstract = subcmd.abstract {
            lines.append(escapeManPage(abstract))
        }
        if let discussion = subcmd.discussion {
            lines.append(".Pp")
            lines.append(escapeManPage(discussion))
        }

        let subArgs = (subcmd.arguments ?? [])
            .filter { $0.shouldDisplay && ($0.kind == "option" || $0.kind == "flag") }
        if !subArgs.isEmpty {
            lines.append(".Pp")
            lines.append("Options:")
            lines.append(".Bl -tag -width Ds -compact")
            for arg in subArgs {
                lines.append(arg.toManPage())
            }
            lines.append(".El")
        }

        if let nestedSubs = subcmd.subcommands?.filter(\.shouldDisplay), !nestedSubs.isEmpty {
            lines.append(".Pp")
            lines.append("Subcommands:")
            lines.append(".Bl -tag -width Ds -compact")
            for nested in nestedSubs {
                lines.append(".It Ic \(nested.commandName)")
                if let abstract = nested.abstract {
                    lines.append(escapeManPage(abstract))
                }
            }
            lines.append(".El")
        }

        return lines
    }

    private func buildEnvironmentSection() -> [String] {
        [
            ".Sh ENVIRONMENT",
            ".Bl -tag -width CLAI_PROVIDER",
            ".It Ev CLAI_PROVIDER",
            "Override the default LLM provider. Valid values: foundation, mlx, ollama, anthropic, openai.",
            ".It Ev CLAI_MLX_MODEL",
            "Override the MLX model identifier.",
            ".It Ev CLAI_OLLAMA_MODEL",
            "Override the Ollama model name.",
            ".It Ev CLAI_OLLAMA_HOST",
            "Override the Ollama server host URL.",
            ".It Ev CLAI_CACHE_ENABLED",
            "Enable or disable response caching (true/false).",
            ".It Ev ANTHROPIC_API_KEY",
            "API key for Anthropic Claude provider.",
            ".It Ev OPENAI_API_KEY",
            "API key for OpenAI provider.",
            ".El",
            "",
        ]
    }

    private func buildFilesSection() -> [String] {
        [
            ".Sh FILES",
            ".Bl -tag -width ~/.config/clai/config.yaml",
            ".It Pa ~/.config/clai/config.yaml",
            "User configuration file.",
            ".It Pa ~/Library/Caches/clai/clai_cache.sqlite",
            "Response cache database.",
            ".It Pa ~/.cache/huggingface/hub/",
            "MLX model cache directory.",
            ".El",
            "",
        ]
    }

    private func buildExamplesSection() -> [String] {
        [
            ".Sh EXAMPLES",
            "Explain a command:",
            ".Pp",
            ".Dl clai explain git rebase -i",
            ".Pp",
            "Suggest commands for a task:",
            ".Pp",
            ".Dl clai suggest \\(dqfind large files\\(dq",
            ".Pp",
            "Show practical examples:",
            ".Pp",
            ".Dl clai examples tar",
            ".Pp",
            "Use a specific provider:",
            ".Pp",
            ".Dl clai --provider ollama explain docker ps",
            "",
        ]
    }

    private func buildFooterSections() -> [String] {
        [
            ".Sh EXIT STATUS",
            ".Ex -std",
            "",
            ".Sh SEE ALSO",
            ".Xr man 1 ,",
            ".Xr tldr 1",
            "",
            ".Sh AUTHORS",
            "Generated by",
            ".Nm clai man-page",
            "command.",
        ]
    }
}

// MARK: - Helpers

private func escapeManPage(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\(dq")
        .replacingOccurrences(of: "'", with: "\\(aq")
        .replacingOccurrences(of: "-", with: "\\-")
}

extension ArgumentInfoV0 {
    func toManPage() -> String {
        var lines: [String] = []

        if let names, !names.isEmpty {
            let nameStrs = names.map { name -> String in
                switch name.kind {
                case "short":
                    "Fl \(name.name)"
                case "long", "longWithSingleDash":
                    "Fl \\-\(name.name)"
                default:
                    name.name
                }
            }

            if kind == "option", let valueName {
                lines.append(".It \(nameStrs.joined(separator: " , ")) Ar \(valueName)")
            } else {
                lines.append(".It \(nameStrs.joined(separator: " , "))")
            }
        } else if let valueName {
            lines.append(".It Ar \(valueName)")
        }

        if let abstract, !abstract.isEmpty {
            lines.append(escapeManPage(abstract))
        }

        if let allValues, !allValues.isEmpty {
            lines.append("Valid values: \(allValues.joined(separator: ", ")).")
        }

        if let defaultValue, !defaultValue.isEmpty {
            lines.append("Default: \(escapeManPage(defaultValue)).")
        }

        return lines.joined(separator: "\n")
    }
}
