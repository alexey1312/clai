import Foundation

/// Utility for formatting byte sizes
enum ByteFormatter: Sendable {
    // Using nonisolated(unsafe) because ByteCountFormatter is not Sendable,
    // but we protect all access with NSLock.
    private nonisolated(unsafe) static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter
    }()

    private static let lock = NSLock()

    /// Format size in human-readable format (e.g., "2.5 GB", "400 MB")
    static func format(_ bytes: Int64) -> String {
        lock.lock()
        defer { lock.unlock() }
        return formatter.string(fromByteCount: bytes)
    }
}
