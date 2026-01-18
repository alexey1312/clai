# Change: Add Conversational Mode (Chat)

## Why
clai currently works in single Q&A mode — user asks a question, gets an answer. If the answer is incomplete or needs clarification, the user must formulate a new query from scratch. This friction limits the learning experience and makes complex explorations tedious.

## What Changes
- Add `clai chat` command for interactive conversation sessions
- Implement conversation history with context preservation across turns
- Add in-session commands (`/exit`, `/clear`, `/history`, `/help`)
- Support initial message argument for quick start

## Impact
- Affected specs: `cli`
- Affected code:
  - `Sources/clai/Commands/ChatCommand.swift` (new)
  - `Sources/clai/Core/ChatMessage.swift` (new)
  - `Sources/clai/Core/PromptBuilder.swift` (add `buildChatPrompt`)
  - `Sources/clai/Core/ClaiEngine.swift` (add `chat` method)
  - `Sources/clai/Clai.swift` (register command)

## Success Metrics
- Average session length > 3 messages
- % users using chat vs single commands
- User satisfaction improvement
