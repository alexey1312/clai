# Change: Add Command History Intelligence

## Why
Users frequently forget complex commands they've used before or repeat similar patterns without realizing they could be optimized. Shell history is a goldmine of personal workflow data that clai can leverage to provide personalized, context-aware assistance — all while keeping data completely local.

## What Changes
- Add `clai recall "<query>"` command to search personal command history with natural language
- Add `clai improve "<command>"` command to suggest optimizations based on usage patterns
- Add `clai history` subcommand group for history management (index, stats, clear)
- Implement local vector index for semantic history search
- Create history analyzer for pattern detection and recommendations

## Impact
- Affected specs: `cli`
- Affected code:
  - `Sources/clai/Commands/RecallCommand.swift` (new)
  - `Sources/clai/Commands/ImproveCommand.swift` (new)
  - `Sources/clai/Commands/HistoryCommand.swift` (new)
  - `Sources/clai/History/` (new module)
  - `Sources/clai/History/HistoryIndexer.swift`
  - `Sources/clai/History/VectorStore.swift`
  - `Sources/clai/History/PatternAnalyzer.swift`
- New dependencies: Local embedding model or simple TF-IDF for vector search

## Privacy
- **All data stays local** — no history sent to cloud providers
- History index stored in `~/.clai/history/`
- Users can clear index at any time with `clai history clear`
- Opt-in indexing with explicit consent

## Success Metrics
- % of users who enable history indexing
- Recall command usage frequency
- "Aha moments" — qualitative feedback on useful recalls
- Time saved by using improved aliases
