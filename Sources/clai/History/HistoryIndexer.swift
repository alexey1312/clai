import Foundation

/// Orchestrates history parsing and indexing from multiple shell history files
final class HistoryIndexer: Sendable {
    private let store: HistoryStore

    init(store: HistoryStore) {
        self.store = store
    }

    /// Index all available shell history files
    /// - Parameter incremental: If true, only index new entries since last index
    /// - Parameter progress: Callback for progress updates (0.0 to 1.0)
    /// - Returns: Combined result of all indexing operations
    func indexAll(
        incremental: Bool = true,
        progress: (@Sendable (Double, String) -> Void)? = nil
    ) async throws -> CombinedIndexResult {
        let historyPaths = HistoryParserFactory.defaultHistoryPaths()
        var results: [ShellIndexResult] = []
        let totalPaths = Double(historyPaths.count)

        for (index, (path, shell)) in historyPaths.enumerated() {
            let baseProgress = Double(index) / totalPaths
            let progressStep = 1.0 / totalPaths

            progress?(baseProgress, "Checking \(shell.rawValue) history...")

            // Check if file exists
            guard FileManager.default.fileExists(atPath: path) else {
                continue
            }

            do {
                let result = try await indexFile(
                    at: path,
                    shell: shell,
                    incremental: incremental
                ) { fileProgress in
                    progress?(
                        baseProgress + fileProgress * progressStep,
                        "Indexing \(shell.rawValue) history..."
                    )
                }
                results.append(result)
            } catch {
                // Log but continue with other shells
                results.append(ShellIndexResult(
                    shell: shell,
                    path: path,
                    result: nil,
                    error: error.localizedDescription
                ))
            }
        }

        progress?(1.0, "Done")

        return CombinedIndexResult(results: results)
    }

    /// Index a specific history file
    func indexFile(
        at path: String,
        shell: HistoryEntry.Shell,
        incremental: Bool = true,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ShellIndexResult {
        // Read file contents
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        progress?(0.2)

        // Get last indexed timestamp for incremental indexing
        var lastIndexed: Date?
        if incremental {
            lastIndexed = try store.lastIndexedTimestamp(for: shell)
        }

        // Parse history
        let parser = HistoryParserFactory.parser(for: shell)
        let parsed = parser.parse(contents: contents, sourcePath: path)
        progress?(0.5)

        // Filter for incremental indexing
        var entriesToIndex = parsed.entries
        if let lastIndexed {
            entriesToIndex = entriesToIndex.filter { entry in
                guard let entryTimestamp = entry.timestamp else {
                    // Include entries without timestamps (we can't tell if they're new)
                    return true
                }
                return entryTimestamp > lastIndexed
            }
        }

        progress?(0.7)

        // Index entries
        let result = try store.index(entries: entriesToIndex)
        progress?(1.0)

        return ShellIndexResult(
            shell: shell,
            path: path,
            result: result,
            error: nil,
            totalParsed: parsed.entries.count,
            parseErrors: parsed.parseErrors
        )
    }
}

/// Result of indexing a single shell's history
struct ShellIndexResult: Sendable {
    let shell: HistoryEntry.Shell
    let path: String
    let result: IndexResult?
    let error: String?
    var totalParsed: Int = 0
    var parseErrors: Int = 0

    var wasIndexed: Bool {
        result != nil
    }
}

/// Combined result of indexing all shells
struct CombinedIndexResult: Sendable {
    let results: [ShellIndexResult]

    var totalInserted: Int {
        results.compactMap(\.result?.inserted).reduce(0, +)
    }

    var totalUpdated: Int {
        results.compactMap(\.result?.updated).reduce(0, +)
    }

    var totalParsed: Int {
        results.map(\.totalParsed).reduce(0, +)
    }

    var shellsIndexed: [HistoryEntry.Shell] {
        results.filter(\.wasIndexed).map(\.shell)
    }

    var errors: [String] {
        results.compactMap(\.error)
    }

    var hasErrors: Bool {
        !errors.isEmpty
    }
}
