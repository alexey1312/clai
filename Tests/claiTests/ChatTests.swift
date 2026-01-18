import Foundation
import Testing

@testable import clai

// MARK: - Chat Session Tests

@Suite("ChatMessage Tests")
struct ChatMessageTests {
    @Test("ChatMessage stores role and content")
    func chatMessageInit() {
        let message = ChatMessage(role: .user, content: "Hello")
        #expect(message.role == .user)
        #expect(message.content == "Hello")
    }

    @Test("ChatMessage stores timestamp")
    func chatMessageTimestamp() {
        let before = Date()
        let message = ChatMessage(role: .assistant, content: "Response")
        let after = Date()

        #expect(message.timestamp >= before)
        #expect(message.timestamp <= after)
    }

    @Test("ChatMessage role enum values")
    func chatMessageRoles() {
        #expect(ChatMessage.Role.user.rawValue == "user")
        #expect(ChatMessage.Role.assistant.rawValue == "assistant")
    }
}

@Suite("ChatSession Tests")
struct ChatSessionTests {
    @Test("ChatSession starts empty")
    func chatSessionEmpty() {
        let session = ChatSession()
        #expect(session.count == 0)
        #expect(session.messages.isEmpty)
    }

    @Test("ChatSession adds user messages")
    func chatSessionAddUser() {
        let session = ChatSession()
        session.addUserMessage("Hello")

        #expect(session.count == 1)
        #expect(session.messages[0].role == .user)
        #expect(session.messages[0].content == "Hello")
    }

    @Test("ChatSession adds assistant messages")
    func chatSessionAddAssistant() {
        let session = ChatSession()
        session.addAssistantMessage("Hi there!")

        #expect(session.count == 1)
        #expect(session.messages[0].role == .assistant)
        #expect(session.messages[0].content == "Hi there!")
    }

    @Test("ChatSession maintains message order")
    func chatSessionOrder() {
        let session = ChatSession()
        session.addUserMessage("First")
        session.addAssistantMessage("Second")
        session.addUserMessage("Third")

        #expect(session.count == 3)
        #expect(session.messages[0].content == "First")
        #expect(session.messages[1].content == "Second")
        #expect(session.messages[2].content == "Third")
    }

    @Test("ChatSession clear removes all messages")
    func chatSessionClear() {
        let session = ChatSession()
        session.addUserMessage("Hello")
        session.addAssistantMessage("Hi")

        #expect(session.count == 2)

        session.clear()
        #expect(session.count == 0)
        #expect(session.messages.isEmpty)
    }

    @Test("ChatSession getRecentHistory returns messages")
    func chatSessionRecentHistory() {
        let session = ChatSession()
        session.addUserMessage("Hello")
        session.addAssistantMessage("Hi")

        let history = session.getRecentHistory()
        #expect(history.count == 2)
    }

    @Test("ChatSession getRecentHistory respects token limit")
    func chatSessionTokenLimit() {
        // Create session with small token limit
        let session = ChatSession(maxHistoryTokens: 50)

        // Add messages that exceed the limit
        session.addUserMessage("This is a somewhat long message that takes up tokens")
        session.addAssistantMessage("This is another long response message")
        session.addUserMessage("Short")

        let history = session.getRecentHistory()
        // Should return at least the last message, but not necessarily all
        #expect(!history.isEmpty)
        #expect(history.last?.content == "Short")
    }
}

@Suite("Chat Prompt Builder Tests")
struct ChatPromptBuilderTests {
    @Test("buildChatPrompt creates prompt with message")
    func chatPromptBasic() {
        let prompt = PromptBuilder.buildChatPrompt(message: "explain git", history: [])
        #expect(prompt.contains("explain git"))
        #expect(prompt.contains("CLI assistant"))
    }

    @Test("buildChatPrompt includes conversation history")
    func chatPromptWithHistory() {
        let history = [
            ChatMessage(role: .user, content: "What is git?"),
            ChatMessage(role: .assistant, content: "Git is a version control system."),
        ]

        let prompt = PromptBuilder.buildChatPrompt(message: "How do I commit?", history: history)

        #expect(prompt.contains("What is git?"))
        #expect(prompt.contains("Git is a version control system"))
        #expect(prompt.contains("How do I commit?"))
    }

    @Test("buildChatPrompt formats roles correctly")
    func chatPromptRoleFormat() {
        let history = [
            ChatMessage(role: .user, content: "question"),
            ChatMessage(role: .assistant, content: "answer"),
        ]

        let prompt = PromptBuilder.buildChatPrompt(message: "follow up", history: history)

        #expect(prompt.contains("User: question"))
        #expect(prompt.contains("Assistant: answer"))
    }

    @Test("buildChatPrompt handles empty history")
    func chatPromptEmptyHistory() {
        let prompt = PromptBuilder.buildChatPrompt(message: "Hello", history: [])
        #expect(prompt.contains("Hello"))
        #expect(!prompt.contains("Conversation so far"))
    }
}
