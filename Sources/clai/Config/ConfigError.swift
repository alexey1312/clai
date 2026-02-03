import Foundation

/// Errors that can occur during configuration loading
enum ConfigError: Error, LocalizedError {
    case directoryCreationFailed(path: String, underlying: Error)
    case fileCreationFailed(path: String, underlying: Error)
    case fileReadFailed(path: String, underlying: Error)
    case yamlParsingFailed(problem: String, line: Int, column: Int, snippet: String?)
    case yamlDecodingFailed(field: String, message: String)

    var errorDescription: String? {
        switch self {
        case let .directoryCreationFailed(path, underlying):
            "Failed to create config directory '\(path)': \(underlying.localizedDescription)"
        case let .fileCreationFailed(path, underlying):
            "Failed to create config file '\(path)': \(underlying.localizedDescription)"
        case let .fileReadFailed(path, underlying):
            "Failed to read config file '\(path)': \(underlying.localizedDescription)"
        case let .yamlParsingFailed(problem, line, column, snippet):
            if let snippet {
                "Config syntax error at line \(line), column \(column): \(problem)\n\(snippet)"
            } else {
                "Config syntax error at line \(line), column \(column): \(problem)"
            }
        case let .yamlDecodingFailed(field, message):
            "Config error in '\(field)': \(message)"
        }
    }
}
