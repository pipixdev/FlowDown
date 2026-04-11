@testable import FlowDown
import Testing

struct ConversationScopeTests {
    @Test
    func `model response sanitizer removes reasoning tags and trailing reasoning`() {
        let wrappedReasoning = """
        Final answer
        <think>hidden chain of thought</think>
        Visible conclusion
        """
        let trailingReasoning = "Visible answer<thinking>more hidden reasoning"

        let sanitizedWrapped = ModelResponseSanitizer.stripReasoning(from: wrappedReasoning)
        let sanitizedTrailing = ModelResponseSanitizer.stripReasoning(from: trailingReasoning)

        #expect(sanitizedWrapped.contains("Final answer"))
        #expect(sanitizedWrapped.contains("Visible conclusion"))
        #expect(!sanitizedWrapped.contains("hidden chain of thought"))
        #expect(sanitizedTrailing == "Visible answer")
    }

    @Test
    func `rewrite actions expose non empty prompts titles and icons`() {
        #expect(RewriteAction.allCases.count == 6)

        for action in RewriteAction.allCases {
            #expect(!action.title.isEmpty)
            #expect(!action.prompt.isEmpty)
            #expect(action.icon != nil)
        }
    }
}
