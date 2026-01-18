import ArgumentParser
import Foundation

struct RecallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "recall",
        abstract: "Search command history with natural language",
        discussion: """
        Search your shell history using natural language queries.
        All data stays local - nothing is sent to cloud providers.

        Examples:
          clai recall "how did I compress that folder"
          clai recall "docker" --limit 10
          clai recall "git" --since "1 week ago"
          clai recall "tar -cz" --exact
        """
    )

    @Argument(help: "Natural language search query")
    var query: [String] = []

    @Option(name: .shortAndLong, help: "Maximum number of results")
    var limit: Int = 10

    @Option(name: .long, help: "Only show commands since (e.g., '1 week ago', '2024-01-01')")
    var since: String?

    @Flag(name: .long, help: "Use exact match instead of semantic search")
    var exact = false

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    mutating func run() async throws {
        let queryString = try getQueryString()
        guard let queryString else { return }

        let store = try createStore()

        // Check consent and data availability
        guard try await ensureIndexAvailable(store: store) else { return }

        // Parse since date if provided
        let sinceDate = try parseSinceDate()

        // Perform search and display
        let results = try performSearch(store: store, query: queryString, since: sinceDate)
        displayResults(results, query: queryString)
    }

    private func getQueryString() throws -> String? {
        var queryString = query.joined(separator: " ")

        if queryString.isEmpty {
            guard isatty(STDIN_FILENO) != 0 else {
                throw ValidationError("Please provide a search query")
            }

            let terminal = TerminalUI()
            terminal.showPrompt("Search history: ")

            guard let input = readLine(),
                  !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                printUsageHelp()
                return nil
            }

            queryString = input.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return queryString
    }

    private func printUsageHelp() {
        print()
        print("No query provided. Try:")
        print("  clai recall \"compress folder\"    Search for compression commands")
        print("  clai recall \"git\" --limit 20     Show more results")
        print("  clai history index                Index your history first")
    }

    private func createStore() throws -> HistoryStore {
        do {
            return try HistoryStore()
        } catch {
            throw ClaiError.historyError("Failed to open history store: \(error.localizedDescription)")
        }
    }

    private func ensureIndexAvailable(store: HistoryStore) async throws -> Bool {
        let hasConsent = try store.hasConsent()
        let stats = try store.stats()

        // If no consent or empty index, prompt and index automatically
        if !hasConsent || stats.totalEntries == 0 {
            let indexed = try await promptAndIndex(store: store, hasConsent: hasConsent)
            if !indexed {
                return false
            }
        }

        return true
    }

    private func parseSinceDate() throws -> Date? {
        guard let sinceString = since else { return nil }

        guard let date = parseDateString(sinceString) else {
            throw ValidationError(
                "Could not parse date: '\(sinceString)'. Try formats like '1 week ago', '2024-01-01'"
            )
        }
        return date
    }

    private func performSearch(store: HistoryStore, query: String, since: Date?) throws -> [SearchResult] {
        if exact {
            try store.searchExact(pattern: query, limit: limit)
        } else if let since {
            try store.search(query: query, since: since, limit: limit)
        } else {
            try store.search(query: query, limit: limit)
        }
    }

    private func displayResults(_ results: [SearchResult], query: String) {
        if json {
            printJSONResults(results)
        } else {
            printResults(results, query: query)
        }
    }

    private func promptAndIndex(store: HistoryStore, hasConsent: Bool) async throws -> Bool {
        let terminal = TerminalUI()

        print()
        print("clai can index your shell history to enable natural language search.")
        print("All data stays local - nothing is sent to cloud providers.")
        print()

        let consented = await terminal.promptYesNo("Index your shell history?")

        if !consented {
            print("Cancelled. Run 'clai recall' again when ready.")
            return false
        }

        if !hasConsent {
            try store.setConsent(true)
        }

        // Index automatically
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

    private func printResults(_ results: [SearchResult], query: String) {
        if results.isEmpty {
            print("No commands found matching '\(query)'")
            print()
            print("Tips:")
            print("  - Try different keywords")
            print("  - Use --exact for literal matching")
            print("  - Run 'clai history index' to update the index")
            return
        }

        print()
        print("Found \(results.count) command\(results.count == 1 ? "" : "s"):")
        print()

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        for (index, result) in results.enumerated() {
            let prefix = Theme.muted + "[\(index + 1)]" + Theme.reset

            // Show command
            print("\(prefix) \(Theme.accent)\(result.command)\(Theme.reset)")

            // Show metadata
            var meta: [String] = []
            if let resultTimestamp = result.timestamp {
                meta.append(dateFormatter.string(from: resultTimestamp))
            }
            if result.frequency > 1 {
                meta.append("used \(result.frequency)x")
            }
            if let dir = result.workingDirectory {
                meta.append("in \(dir)")
            }

            if !meta.isEmpty {
                print("    \(Theme.muted)\(meta.joined(separator: " • "))\(Theme.reset)")
            }

            print()
        }
    }

    private func printJSONResults(_ results: [SearchResult]) {
        let output = results.map { result -> [String: Any] in
            var dict: [String: Any] = [
                "command": result.command,
                "shell": result.shell.rawValue,
                "frequency": result.frequency,
                "score": result.score,
            ]
            if let resultTimestamp = result.timestamp {
                dict["timestamp"] = ISO8601DateFormatter().string(from: resultTimestamp)
            }
            if let dir = result.workingDirectory {
                dict["working_directory"] = dir
            }
            return dict
        }

        if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
           let jsonString = String(data: data, encoding: .utf8)
        {
            print(jsonString)
        }
    }

    /// Parse a human-readable date string
    private func parseDateString(_ string: String) -> Date? {
        let lowercased = string.lowercased().trimmingCharacters(in: .whitespaces)

        // Try different parsing strategies in order
        return parseRelativeDateAgo(lowercased)
            ?? parseNamedRelativeDate(lowercased)
            ?? parseAbsoluteDate(string)
    }

    /// Parse "N unit ago" patterns (e.g., "1 week ago", "2 days ago")
    private func parseRelativeDateAgo(_ string: String) -> Date? {
        let pattern = #"(\d+)\s*(second|minute|hour|day|week|month|year)s?\s*ago"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(
                  in: string,
                  options: [],
                  range: NSRange(string.startIndex..., in: string)
              ),
              let numberRange = Range(match.range(at: 1), in: string),
              let unitRange = Range(match.range(at: 2), in: string),
              let number = Int(string[numberRange])
        else {
            return nil
        }

        let unit = String(string[unitRange])
        let component = calendarComponent(for: unit)
        return Calendar.current.date(byAdding: component, value: -number, to: Date())
    }

    private func calendarComponent(for unit: String) -> Calendar.Component {
        switch unit {
        case "second": .second
        case "minute": .minute
        case "hour": .hour
        case "day": .day
        case "week": .weekOfYear
        case "month": .month
        case "year": .year
        default: .day
        }
    }

    /// Parse named relative dates (today, yesterday, this week, etc.)
    private func parseNamedRelativeDate(_ string: String) -> Date? {
        let now = Date()
        let calendar = Calendar.current

        switch string {
        case "today":
            return calendar.startOfDay(for: now)
        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        case "this week":
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
        case "last week":
            return parseLastWeek(calendar: calendar, now: now)
        case "this month":
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now))
        case "last month":
            return parseLastMonth(calendar: calendar, now: now)
        default:
            return nil
        }
    }

    private func parseLastWeek(calendar: Calendar, now: Date) -> Date? {
        guard let thisWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        ) else {
            return nil
        }
        return calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek)
    }

    private func parseLastMonth(calendar: Calendar, now: Date) -> Date? {
        guard let thisMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) else {
            return nil
        }
        return calendar.date(byAdding: .month, value: -1, to: thisMonth)
    }

    /// Parse absolute date formats (ISO8601 and common formats)
    private func parseAbsoluteDate(_ string: String) -> Date? {
        // Try ISO8601 first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        if let date = isoFormatter.date(from: string) {
            return date
        }

        // Try common formats
        let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "MMM d, yyyy"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }

        return nil
    }
}
