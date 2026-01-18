import ArgumentParser
import Foundation

/// Command to generate CLI documentation in Markdown format
struct DocsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "docs",
        abstract: "Generate CLI documentation in Markdown",
        discussion: """
        Generates comprehensive Markdown documentation from the CLI's help information.

        Examples:
          clai docs                     Output to stdout
          clai docs --output docs/      Write to docs/CLI.md
          clai docs -o README.md        Write to specific file
        """
    )

    @Option(name: .shortAndLong, help: "Output file or directory (use '-' for stdout)")
    var output: String = "-"

    func run() throws {
        let toolInfo = try getDumpHelp()
        let markdown = toolInfo.command.toMarkdown()

        if output == "-" {
            print(markdown)
        } else {
            let outputURL = if output.hasSuffix("/") || FileManager.default.isDirectory(atPath: output) {
                URL(fileURLWithPath: output).appendingPathComponent("CLI.md")
            } else {
                URL(fileURLWithPath: output)
            }

            // Create parent directories if needed
            let parentDir = outputURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

            try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
            print("Documentation written to \(outputURL.path)")
        }
    }
}

// MARK: - Tool Info Types (matches ArgumentParser's --experimental-dump-help output)

struct ToolInfoV0: Codable {
    let command: CommandInfoV0
    let serializationVersion: Int
}

struct CommandInfoV0: Codable {
    let commandName: String
    let abstract: String?
    let discussion: String?
    let shouldDisplay: Bool
    let arguments: [ArgumentInfoV0]?
    let subcommands: [CommandInfoV0]?
    let superCommands: [String]?
    let defaultSubcommand: String?
}

struct ArgumentInfoV0: Codable {
    let kind: String // "flag", "option", "positional"
    let shouldDisplay: Bool
    let isOptional: Bool
    let isRepeating: Bool
    let names: [NameInfoV0]?
    let preferredName: NameInfoV0?
    let valueName: String?
    let abstract: String?
    let defaultValue: String?
    let allValues: [String]?
}

struct NameInfoV0: Codable {
    let kind: String // "short", "long", "longWithSingleDash"
    let name: String
}

// MARK: - Dump Help Execution

func getDumpHelp() throws -> ToolInfoV0 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
    process.arguments = ["--experimental-dump-help"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()

    guard process.terminationStatus == 0 else {
        throw DocsError.dumpHelpFailed
    }

    return try JSONDecoder().decode(ToolInfoV0.self, from: data)
}

enum DocsError: Error, LocalizedError {
    case dumpHelpFailed

    var errorDescription: String? {
        switch self {
        case .dumpHelpFailed:
            "Failed to get help information from --experimental-dump-help"
        }
    }
}

// MARK: - Markdown Generation

extension CommandInfoV0 {
    func toMarkdown(level: Int = 1) -> String {
        var lines: [String] = []
        let heading = String(repeating: "#", count: level)

        lines.append(contentsOf: buildMarkdownHeader(heading: heading))
        lines.append(contentsOf: buildMarkdownUsage())
        lines.append(contentsOf: buildMarkdownArguments())
        lines.append(contentsOf: buildMarkdownSubcommands(level: level))

        return lines.joined(separator: "\n")
    }

    private func buildMarkdownHeader(heading: String) -> [String] {
        var lines: [String] = []

        let fullName = (superCommands ?? []).joined(separator: " ") +
            (superCommands?.isEmpty == false ? " " : "") + commandName
        lines.append("\(heading) \(fullName)")
        lines.append("")

        if let abstract, !abstract.isEmpty {
            lines.append(abstract)
            lines.append("")
        }

        if let discussion, !discussion.isEmpty {
            lines.append(discussion)
            lines.append("")
        }

        return lines
    }

    private func buildMarkdownUsage() -> [String] {
        ["**Usage:**", "```", buildUsageLine(), "```", ""]
    }

    private func buildMarkdownArguments() -> [String] {
        var lines: [String] = []
        let displayableArgs = (arguments ?? []).filter(\.shouldDisplay)

        let positionals = displayableArgs.filter { $0.kind == "positional" }
        let options = displayableArgs.filter { $0.kind == "option" }
        let flags = displayableArgs.filter { $0.kind == "flag" }

        lines.append(contentsOf: formatArgSection("**Arguments:**", args: positionals))
        lines.append(contentsOf: formatArgSection("**Options:**", args: options))
        lines.append(contentsOf: formatArgSection("**Flags:**", args: flags))

        return lines
    }

    private func formatArgSection(_ title: String, args: [ArgumentInfoV0]) -> [String] {
        guard !args.isEmpty else { return [] }
        var lines = [title, ""]
        for arg in args {
            lines.append(arg.toMarkdown())
        }
        lines.append("")
        return lines
    }

    private func buildMarkdownSubcommands(level: Int) -> [String] {
        guard let subcommands, !subcommands.isEmpty else { return [] }
        let displayableSubcommands = subcommands.filter(\.shouldDisplay)
        guard !displayableSubcommands.isEmpty else { return [] }

        var lines = ["---", ""]
        for subcommand in displayableSubcommands {
            lines.append(subcommand.toMarkdown(level: level + 1))
        }
        return lines
    }

    private func buildUsageLine() -> String {
        var parts: [String] = []

        if let superCommands, !superCommands.isEmpty {
            parts.append(contentsOf: superCommands)
        }
        parts.append(commandName)

        let hasOptions = (arguments ?? []).contains { $0.kind == "option" || $0.kind == "flag" }
        if hasOptions {
            parts.append("[options]")
        }

        let positionals = (arguments ?? []).filter { $0.kind == "positional" && $0.shouldDisplay }
        for arg in positionals {
            let name = "<\(arg.valueName ?? "arg")>"
            parts.append(arg.isOptional ? "[\(name)]" : name)
            if arg.isRepeating {
                parts.append("...")
            }
        }

        if let subcommands, !subcommands.isEmpty {
            if let defaultSub = defaultSubcommand {
                parts.append("[subcommand] (default: \(defaultSub))")
            } else {
                parts.append("<subcommand>")
            }
        }

        return parts.joined(separator: " ")
    }
}

extension ArgumentInfoV0 {
    func toMarkdown() -> String {
        var parts: [String] = []

        // Build name string
        let nameStr: String = if let names, !names.isEmpty {
            names.map { name in
                switch name.kind {
                case "short":
                    "-\(name.name)"
                case "long", "longWithSingleDash":
                    "--\(name.name)"
                default:
                    name.name
                }
            }.joined(separator: ", ")
        } else {
            valueName ?? "arg"
        }

        parts.append("- `\(nameStr)`")

        // Add value placeholder for options
        if kind == "option", let valueName {
            parts[0] = "- `\(nameStr) <\(valueName)>`"
        }

        // Add description
        if let abstract, !abstract.isEmpty {
            parts.append(" — \(abstract)")
        }

        // Add default value
        if let defaultValue, !defaultValue.isEmpty {
            parts.append(" (default: `\(defaultValue)`)")
        }

        // Add allowed values
        if let allValues, !allValues.isEmpty {
            parts.append(" Values: \(allValues.map { "`\($0)`" }.joined(separator: ", "))")
        }

        return parts.joined()
    }
}

// MARK: - FileManager Extension

extension FileManager {
    func isDirectory(atPath path: String) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}
