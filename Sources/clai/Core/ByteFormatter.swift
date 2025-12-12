import Foundation

/// Utility for formatting byte sizes
enum ByteFormatter {
    /// Format size in human-readable format (e.g., "2.5 GB", "400 MB")
    static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter.string(fromByteCount: bytes)
    }
}
