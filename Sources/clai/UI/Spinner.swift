import Foundation

/// A simple CLI spinner for indicating ongoing operations
final class Spinner: Sendable {
    private let task: Task<Void, Never>

    init(message: String) {
        task = Task {
            let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
            var index = 0

            // Hide cursor
            print("\u{001B}[?25l", terminator: "")
            safeFlush()

            // Animation loop
            while !Task.isCancelled {
                let frame = frames[index % frames.count]
                // Use Theme.accent for the spinner, default color for message
                print("\r\(Theme.accent)\(frame)\(Theme.reset) \(message)", terminator: "")
                safeFlush()

                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
                index += 1
            }

            // Cleanup: clear line and show cursor
            print("\r\u{001B}[K", terminator: "")
            print("\u{001B}[?25h", terminator: "")
            safeFlush()
        }
    }

    func stop() {
        task.cancel()
    }
}

/// Flush stdout in a concurrency-safe manner using FileHandle
/// This avoids Swift 6 concurrency errors with global `stdout` variable on Linux
@inline(__always)
private func safeFlush() {
    try? FileHandle.standardOutput.synchronize()
}
