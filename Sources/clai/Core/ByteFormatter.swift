import Foundation

/// Utility for formatting byte sizes
enum ByteFormatter {
    // Reusing the formatter avoids repeated allocation overhead.
    // Protected by a lock for thread safety.
    private nonisolated(unsafe) static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useGB, .useMB]
        return f
    }()

    private static let lock = NSLock()

    /// Format size in human-readable format (e.g., "2.5 GB", "400 MB")
    static func format(_ bytes: Int64) -> String {
        lock.lock()
        defer { lock.unlock() }
        return formatter.string(fromByteCount: bytes)
    }
}
