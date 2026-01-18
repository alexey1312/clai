# Implementation Tasks

## 1. History Parsing
- [x] 1.1 Implement parser for `.zsh_history` format (extended history)
- [x] 1.2 Implement parser for `.bash_history` format
- [x] 1.3 Implement parser for fish history (`~/.local/share/fish/fish_history`)
- [x] 1.4 Extract timestamps, working directories where available
- [x] 1.5 Handle edge cases (multiline commands, escape sequences)

## 2. Vector Index
- [x] 2.1 Evaluate embedding options (local model vs TF-IDF) - chose FTS5 with porter stemming
- [x] 2.2 Implement simple TF-IDF vectorizer as baseline - using FTS5 BM25 ranking
- [x] 2.3 Create SQLite-based vector store with FTS5
- [x] 2.4 Implement incremental indexing (only new entries)
- [x] 2.5 Add index compression/compaction - using WAL mode and triggers

## 3. Recall Command
- [x] 3.1 Create `RecallCommand` with natural language query
- [x] 3.2 Implement semantic search against history index
- [x] 3.3 Display results with timestamps and context
- [x] 3.4 Add `--limit` flag for result count
- [x] 3.5 Add `--since` flag for time filtering
- [x] 3.6 Support exact match mode with `--exact`

## 4. Improve Command
- [x] 4.1 Create `ImproveCommand` for command optimization
- [x] 4.2 Implement frequency analysis (how often command is used)
- [x] 4.3 Detect alias candidates (long commands used repeatedly)
- [x] 4.4 Suggest flags based on common patterns
- [x] 4.5 Integrate with LLM for intelligent suggestions (`--llm` flag)

## 5. History Management
- [x] 5.1 Create `clai history index` command (manual trigger)
- [x] 5.2 Create `clai history stats` command (index statistics)
- [x] 5.3 Create `clai history clear` command (delete index)
- [ ] 5.4 Add automatic background indexing (optional) - deferred to future release
- [x] 5.5 Implement consent flow for first-time indexing

## 6. Pattern Analysis
- [x] 6.1 Detect frequently repeated commands
- [ ] 6.2 Identify command sequences (A then B pattern) - deferred (requires timestamp analysis)
- [x] 6.3 Suggest shell functions for complex patterns
- [ ] 6.4 Track command evolution (how usage changes over time) - deferred to future release

## 7. Testing
- [x] 7.1 Unit tests for history parsers
- [x] 7.2 Unit tests for vector search accuracy
- [x] 7.3 Integration tests for recall command
- [ ] 7.4 Performance tests with large history files (>100k entries) - deferred

## 8. Documentation
- [x] 8.1 Update README with history commands section
- [x] 8.2 Document privacy guarantees
- [ ] 8.3 Add troubleshooting guide for indexing issues - deferred
