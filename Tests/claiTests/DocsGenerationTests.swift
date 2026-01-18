import Foundation
import Testing

@testable import clai

// MARK: - ToolInfo Types Tests

@Suite("ToolInfo Decoding Tests")
struct ToolInfoDecodingTests {
    @Test("ToolInfoV0 decodes from JSON")
    func decodeToolInfo() throws {
        let json = """
        {
            "command": {
                "commandName": "test",
                "abstract": "Test command",
                "shouldDisplay": true
            },
            "serializationVersion": 0
        }
        """
        let data = json.data(using: .utf8)!
        let toolInfo = try JSONDecoder().decode(ToolInfoV0.self, from: data)

        #expect(toolInfo.command.commandName == "test")
        #expect(toolInfo.command.abstract == "Test command")
        #expect(toolInfo.serializationVersion == 0)
    }

    @Test("CommandInfoV0 decodes with subcommands")
    func decodeCommandWithSubcommands() throws {
        let json = """
        {
            "command": {
                "commandName": "parent",
                "abstract": "Parent command",
                "shouldDisplay": true,
                "subcommands": [
                    {
                        "commandName": "child",
                        "abstract": "Child command",
                        "shouldDisplay": true,
                        "superCommands": ["parent"]
                    }
                ]
            },
            "serializationVersion": 0
        }
        """
        let data = json.data(using: .utf8)!
        let toolInfo = try JSONDecoder().decode(ToolInfoV0.self, from: data)

        #expect(toolInfo.command.subcommands?.count == 1)
        #expect(toolInfo.command.subcommands?.first?.commandName == "child")
        #expect(toolInfo.command.subcommands?.first?.superCommands == ["parent"])
    }

    @Test("ArgumentInfoV0 decodes correctly")
    func decodeArgument() throws {
        let json = """
        {
            "command": {
                "commandName": "test",
                "shouldDisplay": true,
                "arguments": [
                    {
                        "kind": "option",
                        "shouldDisplay": true,
                        "isOptional": true,
                        "isRepeating": false,
                        "valueName": "provider",
                        "abstract": "Force specific provider",
                        "allValues": ["mlx", "ollama", "anthropic"]
                    }
                ]
            },
            "serializationVersion": 0
        }
        """
        let data = json.data(using: .utf8)!
        let toolInfo = try JSONDecoder().decode(ToolInfoV0.self, from: data)

        let arg = toolInfo.command.arguments?.first
        #expect(arg?.kind == "option")
        #expect(arg?.valueName == "provider")
        #expect(arg?.allValues == ["mlx", "ollama", "anthropic"])
    }
}

// MARK: - Markdown Generation Tests

@Suite("Markdown Generation Tests")
struct MarkdownGenerationTests {
    @Test("CommandInfoV0 generates markdown with heading")
    func markdownHeading() {
        let command = CommandInfoV0(
            commandName: "test",
            abstract: "Test command",
            discussion: nil,
            shouldDisplay: true,
            arguments: nil,
            subcommands: nil,
            superCommands: nil,
            defaultSubcommand: nil
        )

        let markdown = command.toMarkdown()
        #expect(markdown.contains("# test"))
        #expect(markdown.contains("Test command"))
    }

    @Test("CommandInfoV0 includes discussion in markdown")
    func markdownDiscussion() {
        let command = CommandInfoV0(
            commandName: "test",
            abstract: "Test command",
            discussion: "This is a detailed discussion.",
            shouldDisplay: true,
            arguments: nil,
            subcommands: nil,
            superCommands: nil,
            defaultSubcommand: nil
        )

        let markdown = command.toMarkdown()
        #expect(markdown.contains("This is a detailed discussion."))
    }

    @Test("CommandInfoV0 includes usage section")
    func markdownUsage() {
        let command = CommandInfoV0(
            commandName: "test",
            abstract: nil,
            discussion: nil,
            shouldDisplay: true,
            arguments: nil,
            subcommands: nil,
            superCommands: nil,
            defaultSubcommand: nil
        )

        let markdown = command.toMarkdown()
        #expect(markdown.contains("**Usage:**"))
        #expect(markdown.contains("```"))
    }

    @Test("CommandInfoV0 formats arguments correctly")
    func markdownArguments() {
        let command = CommandInfoV0(
            commandName: "test",
            abstract: nil,
            discussion: nil,
            shouldDisplay: true,
            arguments: [
                ArgumentInfoV0(
                    kind: "positional",
                    shouldDisplay: true,
                    isOptional: false,
                    isRepeating: false,
                    names: nil,
                    preferredName: nil,
                    valueName: "file",
                    abstract: "Input file",
                    defaultValue: nil,
                    allValues: nil
                ),
            ],
            subcommands: nil,
            superCommands: nil,
            defaultSubcommand: nil
        )

        let markdown = command.toMarkdown()
        #expect(markdown.contains("**Arguments:**"))
        #expect(markdown.contains("file"))
        #expect(markdown.contains("Input file"))
    }

    @Test("CommandInfoV0 formats options correctly")
    func markdownOptions() {
        let command = CommandInfoV0(
            commandName: "test",
            abstract: nil,
            discussion: nil,
            shouldDisplay: true,
            arguments: [
                ArgumentInfoV0(
                    kind: "option",
                    shouldDisplay: true,
                    isOptional: true,
                    isRepeating: false,
                    names: [NameInfoV0(kind: "long", name: "output")],
                    preferredName: NameInfoV0(kind: "long", name: "output"),
                    valueName: "path",
                    abstract: "Output path",
                    defaultValue: nil,
                    allValues: nil
                ),
            ],
            subcommands: nil,
            superCommands: nil,
            defaultSubcommand: nil
        )

        let markdown = command.toMarkdown()
        #expect(markdown.contains("**Options:**"))
        #expect(markdown.contains("--output"))
        #expect(markdown.contains("Output path"))
    }

    @Test("CommandInfoV0 formats flags correctly")
    func markdownFlags() {
        let command = CommandInfoV0(
            commandName: "test",
            abstract: nil,
            discussion: nil,
            shouldDisplay: true,
            arguments: [
                ArgumentInfoV0(
                    kind: "flag",
                    shouldDisplay: true,
                    isOptional: true,
                    isRepeating: false,
                    names: [
                        NameInfoV0(kind: "short", name: "v"),
                        NameInfoV0(kind: "long", name: "verbose"),
                    ],
                    preferredName: NameInfoV0(kind: "long", name: "verbose"),
                    valueName: "verbose",
                    abstract: "Enable verbose output",
                    defaultValue: nil,
                    allValues: nil
                ),
            ],
            subcommands: nil,
            superCommands: nil,
            defaultSubcommand: nil
        )

        let markdown = command.toMarkdown()
        #expect(markdown.contains("**Flags:**"))
        #expect(markdown.contains("-v"))
        #expect(markdown.contains("--verbose"))
    }

    @Test("CommandInfoV0 includes subcommands")
    func markdownSubcommands() {
        let command = CommandInfoV0(
            commandName: "parent",
            abstract: "Parent command",
            discussion: nil,
            shouldDisplay: true,
            arguments: nil,
            subcommands: [
                CommandInfoV0(
                    commandName: "child",
                    abstract: "Child command",
                    discussion: nil,
                    shouldDisplay: true,
                    arguments: nil,
                    subcommands: nil,
                    superCommands: ["parent"],
                    defaultSubcommand: nil
                ),
            ],
            superCommands: nil,
            defaultSubcommand: nil
        )

        let markdown = command.toMarkdown()
        #expect(markdown.contains("## parent child"))
        #expect(markdown.contains("Child command"))
    }

    @Test("ArgumentInfoV0 toMarkdown includes default value")
    func argumentMarkdownDefault() {
        let arg = ArgumentInfoV0(
            kind: "flag",
            shouldDisplay: true,
            isOptional: true,
            isRepeating: false,
            names: [NameInfoV0(kind: "long", name: "stream")],
            preferredName: nil,
            valueName: nil,
            abstract: "Enable streaming",
            defaultValue: "--stream",
            allValues: nil
        )

        let markdown = arg.toMarkdown()
        #expect(markdown.contains("default: `--stream`"))
    }

    @Test("ArgumentInfoV0 toMarkdown includes allowed values")
    func argumentMarkdownAllValues() {
        let arg = ArgumentInfoV0(
            kind: "option",
            shouldDisplay: true,
            isOptional: true,
            isRepeating: false,
            names: [NameInfoV0(kind: "long", name: "provider")],
            preferredName: nil,
            valueName: "provider",
            abstract: "Select provider",
            defaultValue: nil,
            allValues: ["mlx", "ollama", "anthropic"]
        )

        let markdown = arg.toMarkdown()
        #expect(markdown.contains("`mlx`"))
        #expect(markdown.contains("`ollama`"))
        #expect(markdown.contains("`anthropic`"))
    }
}

// MARK: - DocsError Tests

@Suite("DocsError Tests")
struct DocsErrorTests {
    @Test("DocsError has descriptive message")
    func errorDescription() {
        let error = DocsError.dumpHelpFailed
        #expect(error.errorDescription?.contains("dump-help") == true)
    }
}

// MARK: - FileManager Extension Tests

@Suite("FileManager Extension Tests")
struct FileManagerExtensionTests {
    @Test("isDirectory returns true for directories")
    func isDirectoryTrue() {
        let tempDir = FileManager.default.temporaryDirectory.path
        #expect(FileManager.default.isDirectory(atPath: tempDir))
    }

    @Test("isDirectory returns false for files")
    func isDirectoryFalse() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).txt")
        try "test".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        #expect(!FileManager.default.isDirectory(atPath: tempFile.path))
    }

    @Test("isDirectory returns false for non-existent paths")
    func isDirectoryNonExistent() {
        #expect(!FileManager.default.isDirectory(atPath: "/nonexistent/path/12345"))
    }
}
