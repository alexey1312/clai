import Foundation
import Testing

@testable import clai

@Suite("Thinking Tag Filter Tests")
struct ThinkingTagFilterTests {
    @Test("Filter removes complete think tags")
    func removeCompleteTags() {
        let filter = ThinkingTagStreamFilter()
        let result = filter.process("<think>reasoning here</think>actual content")
        #expect(result == "actual content")
    }

    @Test("Filter handles think tags at start")
    func thinkTagsAtStart() {
        let filter = ThinkingTagStreamFilter()
        let result = filter.process("<think>internal</think>visible text")
        #expect(result == "visible text")
    }

    @Test("Filter handles content before think tag")
    func contentBeforeThinkTag() {
        let filter = ThinkingTagStreamFilter()
        let result = filter.process("before<think>hidden</think>after")
        #expect(result == "beforeafter")
    }

    @Test("Filter handles streaming chunks")
    func streamingChunks() {
        let filter = ThinkingTagStreamFilter()

        var output = ""
        output += filter.process("<thi")
        output += filter.process("nk>hidden content")
        output += filter.process("</think>visible")
        output += filter.flush()

        #expect(output == "visible")
    }

    @Test("Filter handles multiple think tags")
    func multipleThinkTags() {
        let filter = ThinkingTagStreamFilter()
        let result = filter.process("<think>first</think>middle<think>second</think>end")
        #expect(result == "middleend")
    }

    @Test("Filter handles no think tags")
    func noThinkTags() {
        let filter = ThinkingTagStreamFilter()
        let result = filter.process("just normal content")
        #expect(result == "just normal content")
    }

    @Test("Filter flush returns buffered partial tag")
    func flushReturnsPartialTag() {
        let filter = ThinkingTagStreamFilter()
        _ = filter.process("text<thi") // partial tag gets buffered
        let remaining = filter.flush()
        #expect(remaining == "<thi") // should return the partial tag
    }

    @Test("Filter flush is empty when no buffered content")
    func flushEmptyWhenNoBuffer() {
        let filter = ThinkingTagStreamFilter()
        _ = filter.process("just normal content")
        let remaining = filter.flush()
        #expect(remaining.isEmpty)
    }
}
