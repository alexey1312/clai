import Foundation

/// Represents a message in a chat conversation
struct ChatMessage: Sendable {
    enum Role: String, Sendable {
        case user
        case assistant
    }

    let role: Role
    let content: String
    let timestamp: Date

    init(role: Role, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// Manages a chat session with conversation history
final class ChatSession: @unchecked Sendable {
    private(set) var messages: [ChatMessage] = []
    private let maxHistoryTokens: Int

    /// Initialize a chat session
    /// - Parameter maxHistoryTokens: Approximate max tokens to keep in history (default 4000)
    init(maxHistoryTokens: Int = 4000) {
        self.maxHistoryTokens = maxHistoryTokens
    }

    /// Add a user message to the session
    func addUserMessage(_ content: String) {
        messages.append(ChatMessage(role: .user, content: content))
    }

    /// Add an assistant message to the session
    func addAssistantMessage(_ content: String) {
        messages.append(ChatMessage(role: .assistant, content: content))
    }

    /// Get recent messages that fit within token budget
    /// Uses rough estimate of 4 chars per token
    func getRecentHistory() -> [ChatMessage] {
        let charsPerToken = 4
        let maxChars = maxHistoryTokens * charsPerToken
        var totalChars = 0
        var result: [ChatMessage] = []

        // Walk backwards through messages, collecting until we hit the limit
        for message in messages.reversed() {
            let messageChars = message.content.count + 20 // +20 for role prefix overhead
            if totalChars + messageChars > maxChars, !result.isEmpty {
                break
            }
            result.insert(message, at: 0)
            totalChars += messageChars
        }

        return result
    }

    /// Clear all messages
    func clear() {
        messages.removeAll()
    }

    /// Number of messages in history
    var count: Int {
        messages.count
    }
}
