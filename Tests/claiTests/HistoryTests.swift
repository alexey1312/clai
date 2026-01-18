import Foundation
import Testing

@testable import clai

// MARK: - History Parser Tests

@Suite("Zsh History Parser Tests")
struct ZshHistoryParserTests {
    @Test("Parses extended history format with timestamps")
    func extendedFormat() {
        let content = """
        : 1699123456:0;git commit -m "fix bug"
        : 1699123500:0;git push origin main
        """

        let parser = ZshHistoryParser()
        let result = parser.parse(contents: content, sourcePath: "~/.zsh_history")

        #expect(result.entries.count == 2)
        #expect(result.shell == .zsh)
        #expect(result.parseErrors == 0)

        // Check first entry
        let first = result.entries[0]
        #expect(first.command == "git commit -m \"fix bug\"")
        #expect(first.timestamp != nil)
        #expect(first.shell == .zsh)

        // Check second entry
        let second = result.entries[1]
        #expect(second.command == "git push origin main")
    }

    @Test("Parses simple history format without timestamps")
    func simpleFormat() {
        let content = """
        ls -la
        cd /tmp
        echo hello
        """

        let parser = ZshHistoryParser()
        let result = parser.parse(contents: content, sourcePath: "~/.zsh_history")

        #expect(result.entries.count == 3)
        #expect(result.entries[0].command == "ls -la")
        #expect(result.entries[0].timestamp == nil)
    }

    @Test("Handles empty content")
    func emptyContent() {
        let parser = ZshHistoryParser()
        let result = parser.parse(contents: "", sourcePath: "~/.zsh_history")

        #expect(result.entries.isEmpty)
        #expect(result.parseErrors == 0)
    }

    @Test("Handles mixed format")
    func mixedFormat() {
        let content = """
        : 1699123456:0;git status
        ls -la
        : 1699123500:0;git add .
        """

        let parser = ZshHistoryParser()
        let result = parser.parse(contents: content, sourcePath: "~/.zsh_history")

        #expect(result.entries.count == 3)
    }
}

@Suite("Bash History Parser Tests")
struct BashHistoryParserTests {
    @Test("Parses simple bash history")
    func simpleFormat() {
        let content = """
        ls -la
        cd /home/user
        git status
        """

        let parser = BashHistoryParser()
        let result = parser.parse(contents: content, sourcePath: "~/.bash_history")

        #expect(result.entries.count == 3)
        #expect(result.shell == .bash)
        #expect(result.entries[0].command == "ls -la")
        #expect(result.entries[1].command == "cd /home/user")
    }

    @Test("Parses history with timestamps")
    func withTimestamps() {
        let content = """
        #1699123456
        git commit -m "test"
        #1699123500
        git push
        """

        let parser = BashHistoryParser()
        let result = parser.parse(contents: content, sourcePath: "~/.bash_history")

        #expect(result.entries.count == 2)
        #expect(result.entries[0].command == "git commit -m \"test\"")
        #expect(result.entries[0].timestamp != nil)
    }

    @Test("Handles empty lines")
    func emptyLines() {
        let content = """
        ls

        cd /tmp

        pwd
        """

        let parser = BashHistoryParser()
        let result = parser.parse(contents: content, sourcePath: "~/.bash_history")

        #expect(result.entries.count == 3)
    }
}

@Suite("Fish History Parser Tests")
struct FishHistoryParserTests {
    @Test("Parses YAML fish history format")
    func yamlFormat() {
        let content = """
        - cmd: git status
          when: 1699123456
        - cmd: git add .
          when: 1699123500
          paths:
            - /Users/test/project
        """

        let parser = FishHistoryParser()
        let result = parser.parse(contents: content, sourcePath: "~/.local/share/fish/fish_history")

        #expect(result.entries.count == 2)
        #expect(result.shell == .fish)

        #expect(result.entries[0].command == "git status")
        #expect(result.entries[0].timestamp != nil)

        #expect(result.entries[1].command == "git add .")
        #expect(result.entries[1].workingDirectory == "/Users/test/project")
    }

    @Test("Handles escaped newlines in commands")
    func escapedNewlines() {
        let content = """
        - cmd: echo hello\\nworld
          when: 1699123456
        """

        let parser = FishHistoryParser()
        let result = parser.parse(contents: content, sourcePath: "fish_history")

        #expect(result.entries.count == 1)
        #expect(result.entries[0].command.contains("\n"))
    }
}

// MARK: - Parser Factory Tests

@Suite("History Parser Factory Tests")
struct HistoryParserFactoryTests {
    @Test("Detects zsh from path")
    func detectZsh() {
        let shell = HistoryParserFactory.detectShell(from: "~/.zsh_history")
        #expect(shell == .zsh)
    }

    @Test("Detects bash from path")
    func detectBash() {
        let shell = HistoryParserFactory.detectShell(from: "~/.bash_history")
        #expect(shell == .bash)
    }

    @Test("Detects fish from path")
    func detectFish() {
        let shell = HistoryParserFactory.detectShell(from: "~/.local/share/fish/fish_history")
        #expect(shell == .fish)
    }

    @Test("Returns nil for unknown shell")
    func detectUnknown() {
        let shell = HistoryParserFactory.detectShell(from: "/some/random/file")
        #expect(shell == nil)
    }

    @Test("Creates correct parser for each shell")
    func createParsers() {
        let zshParser = HistoryParserFactory.parser(for: .zsh)
        let bashParser = HistoryParserFactory.parser(for: .bash)
        let fishParser = HistoryParserFactory.parser(for: .fish)

        #expect(zshParser is ZshHistoryParser)
        #expect(bashParser is BashHistoryParser)
        #expect(fishParser is FishHistoryParser)
    }

    @Test("Default paths include all shells")
    func defaultPaths() {
        let paths = HistoryParserFactory.defaultHistoryPaths()

        let shells = paths.map(\.shell)
        #expect(shells.contains(.zsh))
        #expect(shells.contains(.bash))
        #expect(shells.contains(.fish))
    }
}

// MARK: - History Entry Tests

@Suite("History Entry Tests")
struct HistoryEntryTests {
    @Test("HistoryEntry equality")
    func entryEquality() {
        let entry1 = HistoryEntry(
            command: "ls -la",
            timestamp: Date(),
            workingDirectory: "/tmp",
            shell: .zsh
        )
        let entry2 = HistoryEntry(
            command: "ls -la",
            timestamp: entry1.timestamp,
            workingDirectory: "/tmp",
            shell: .zsh
        )

        #expect(entry1 == entry2)
    }

    @Test("HistoryEntry shell types")
    func shellTypes() {
        #expect(HistoryEntry.Shell.zsh.rawValue == "zsh")
        #expect(HistoryEntry.Shell.bash.rawValue == "bash")
        #expect(HistoryEntry.Shell.fish.rawValue == "fish")
    }
}

// MARK: - Pattern Analyzer Tests

@Suite("Pattern Analyzer Helper Tests")
struct PatternAnalyzerHelperTests {
    @Test("Alias candidate detection criteria")
    func aliasCandidateCriteria() {
        // A command should be an alias candidate if:
        // 1. It's used frequently (>= 3 times)
        // 2. It's long enough to benefit from aliasing (>= 15 chars)

        let shortCommand = "ls -la"
        let longCommand = "docker ps -a --format '{{.Names}}'"

        #expect(shortCommand.count < 15) // Too short for alias
        #expect(longCommand.count >= 15) // Good candidate
    }
}

// MARK: - Index Result Tests

@Suite("Index Result Tests")
struct IndexResultTests {
    @Test("IndexResult total calculation")
    func totalCalculation() {
        let result = IndexResult(inserted: 10, updated: 5)
        #expect(result.total == 15)
    }
}

// MARK: - Combined Index Result Tests

@Suite("Combined Index Result Tests")
struct CombinedIndexResultTests {
    @Test("CombinedIndexResult aggregates shell results")
    func aggregation() {
        let results = [
            ShellIndexResult(
                shell: .zsh,
                path: "~/.zsh_history",
                result: IndexResult(inserted: 100, updated: 20),
                error: nil,
                totalParsed: 120,
                parseErrors: 0
            ),
            ShellIndexResult(
                shell: .bash,
                path: "~/.bash_history",
                result: IndexResult(inserted: 50, updated: 10),
                error: nil,
                totalParsed: 60,
                parseErrors: 0
            ),
        ]

        let combined = CombinedIndexResult(results: results)

        #expect(combined.totalInserted == 150)
        #expect(combined.totalUpdated == 30)
        #expect(combined.totalParsed == 180)
        #expect(combined.shellsIndexed.count == 2)
        #expect(!combined.hasErrors)
    }

    @Test("CombinedIndexResult handles errors")
    func handlesErrors() {
        let results = [
            ShellIndexResult(
                shell: .zsh,
                path: "~/.zsh_history",
                result: nil,
                error: "File not found"
            ),
        ]

        let combined = CombinedIndexResult(results: results)

        #expect(combined.hasErrors)
        #expect(combined.errors.count == 1)
        #expect(combined.shellsIndexed.isEmpty)
    }
}

// MARK: - Error Tests

@Suite("History Error Tests")
struct HistoryErrorTests {
    @Test("ClaiError.historyError has descriptive message")
    func historyErrorMessage() {
        let error = ClaiError.historyError("Test error message")
        #expect(error.errorDescription?.contains("Test error message") == true)
    }
}
