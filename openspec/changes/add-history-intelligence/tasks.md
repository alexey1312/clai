# Implementation Tasks

## 1. History Parsing
- [ ] 1.1 Implement parser for `.zsh_history` format (extended history)
- [ ] 1.2 Implement parser for `.bash_history` format
- [ ] 1.3 Implement parser for fish history (`~/.local/share/fish/fish_history`)
- [ ] 1.4 Extract timestamps, working directories where available
- [ ] 1.5 Handle edge cases (multiline commands, escape sequences)

## 2. Vector Index
- [ ] 2.1 Evaluate embedding options (local model vs TF-IDF)
- [ ] 2.2 Implement simple TF-IDF vectorizer as baseline
- [ ] 2.3 Create SQLite-based vector store with FTS5
- [ ] 2.4 Implement incremental indexing (only new entries)
- [ ] 2.5 Add index compression/compaction

## 3. Recall Command
- [ ] 3.1 Create `RecallCommand` with natural language query
- [ ] 3.2 Implement semantic search against history index
- [ ] 3.3 Display results with timestamps and context
- [ ] 3.4 Add `--limit` flag for result count
- [ ] 3.5 Add `--since` flag for time filtering
- [ ] 3.6 Support exact match mode with `--exact`

## 4. Improve Command
- [ ] 4.1 Create `ImproveCommand` for command optimization
- [ ] 4.2 Implement frequency analysis (how often command is used)
- [ ] 4.3 Detect alias candidates (long commands used repeatedly)
- [ ] 4.4 Suggest flags based on common patterns
- [ ] 4.5 Integrate with LLM for intelligent suggestions

## 5. History Management
- [ ] 5.1 Create `clai history index` command (manual trigger)
- [ ] 5.2 Create `clai history stats` command (index statistics)
- [ ] 5.3 Create `clai history clear` command (delete index)
- [ ] 5.4 Add automatic background indexing (optional)
- [ ] 5.5 Implement consent flow for first-time indexing

## 6. Pattern Analysis
- [ ] 6.1 Detect frequently repeated commands
- [ ] 6.2 Identify command sequences (A then B pattern)
- [ ] 6.3 Suggest shell functions for complex patterns
- [ ] 6.4 Track command evolution (how usage changes over time)

## 7. Testing
- [ ] 7.1 Unit tests for history parsers
- [ ] 7.2 Unit tests for vector search accuracy
- [ ] 7.3 Integration tests for recall command
- [ ] 7.4 Performance tests with large history files (>100k entries)

## 8. Documentation
- [ ] 8.1 Update README with history commands section
- [ ] 8.2 Document privacy guarantees
- [ ] 8.3 Add troubleshooting guide for indexing issues
