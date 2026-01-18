# Command History Intelligence Design

## Context
Users accumulate valuable workflow knowledge in their shell history but have no good way to search or learn from it. `history | grep` is limited to exact matches. clai can provide semantic search and intelligent analysis while keeping all data local — aligned with our privacy-first philosophy.

## Goals
- Enable natural language search over command history ("how did I compress that folder?")
- Suggest optimizations based on actual usage patterns
- Keep all history data strictly local (privacy-first)
- Support zsh, bash, and fish history formats

## Non-Goals
- Sync history across machines (privacy concern)
- Replace shell's built-in history (we augment)
- Real-time history tracking (we index on-demand or periodically)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Shell History Files                  │
│  ~/.zsh_history  ~/.bash_history  ~/.local/.../fish     │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   History Parser                         │
│  - Format detection (zsh/bash/fish)                     │
│  - Timestamp extraction                                  │
│  - Command normalization                                 │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   History Indexer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  TF-IDF     │  │   SQLite    │  │   Pattern   │     │
│  │  Vectorizer │──│   FTS5      │──│   Analyzer  │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   ~/.clai/history/                       │
│  - history.db (SQLite with FTS5)                        │
│  - vectors.bin (optional embeddings)                    │
│  - patterns.json (detected patterns cache)              │
└─────────────────────────────────────────────────────────┘
```

## Decisions

### Decision: TF-IDF over Neural Embeddings (MVP)
**Why:** Simpler, no additional model download, sufficient for command text. Can upgrade to embeddings later.
**Alternatives considered:**
- Local embedding model (sentence-transformers): More accurate but requires ~500MB model download
- LLM-based embeddings: Requires provider, latency concerns
- SQLite FTS5 alone: Good for keywords, weak for semantic search

**Future:** Optionally support local embedding model for users who want better semantic search.

### Decision: SQLite with FTS5 for Storage
**Why:**
- Built into Swift/macOS, no dependencies
- FTS5 provides good full-text search
- Incremental updates are efficient
- Portable, single-file database

### Decision: On-Demand Indexing (Default)
**Why:** User controls when indexing happens, no surprise CPU/memory usage.
**Flow:**
1. First `clai recall` prompts for consent
2. User runs `clai history index` to build index
3. Subsequent recalls use cached index
4. Optional: background indexing daemon (future)

### Decision: Privacy-First Consent Flow
**Why:** History contains sensitive data. Explicit consent required.
**Flow:**
```
$ clai recall "database migration"

⚠️  History indexing is not enabled.

clai can index your shell history to enable natural language search.
All data stays local - nothing is sent to cloud providers.

Would you like to enable history indexing? [y/N]
```

## Data Model

```sql
CREATE TABLE commands (
    id INTEGER PRIMARY KEY,
    command TEXT NOT NULL,
    timestamp INTEGER,          -- Unix timestamp if available
    working_dir TEXT,           -- Working directory if available
    shell TEXT,                 -- zsh, bash, fish
    frequency INTEGER DEFAULT 1 -- How many times seen
);

CREATE VIRTUAL TABLE commands_fts USING fts5(
    command,
    content='commands',
    content_rowid='id'
);

CREATE TABLE patterns (
    id INTEGER PRIMARY KEY,
    pattern_type TEXT,          -- 'alias_candidate', 'sequence', 'evolution'
    data JSON,
    detected_at INTEGER
);
```

## History Format Parsing

### Zsh Extended History
```
: 1699123456:0;git commit -m "fix bug"
: 1699123500:0;git push origin main
```
Format: `: timestamp:duration;command`

### Bash History
```
git commit -m "fix bug"
git push origin main
```
Plain text, one command per line. Timestamps in separate file if HISTTIMEFORMAT set.

### Fish History
```yaml
- cmd: git commit -m "fix bug"
  when: 1699123456
  paths:
    - /Users/alex/project
```
YAML format with rich metadata.

## API Design

### Recall Command
```bash
# Natural language search
clai recall "how did I compress that folder"
clai recall "database migration script"

# With filters
clai recall "docker" --limit 10
clai recall "git" --since "1 week ago"
clai recall "tar" --exact  # Exact match mode
```

### Improve Command
```bash
# Analyze specific command
clai improve "docker ps -a --format '{{.Names}}'"
# Output: You use this command frequently. Consider:
#   alias dps="docker ps -a --format '{{.Names}}'"

# Analyze by pattern
clai improve --frequent
# Output: Top alias candidates based on your usage...
```

### History Management
```bash
clai history index          # Build/update index
clai history stats          # Show index statistics
clai history clear          # Delete index (privacy)
clai history export         # Export to JSON (future)
```

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Large history files | Slow indexing | Incremental indexing, progress bar |
| Sensitive commands | Privacy leak | Local-only, explicit consent, easy clear |
| Stale index | Incorrect results | Show last indexed time, re-index prompt |
| Low recall quality | User frustration | Hybrid TF-IDF + FTS5, fallback to grep |

## Performance Targets

| Operation | Target | Notes |
|-----------|--------|-------|
| Initial index (50k commands) | < 30s | One-time |
| Incremental index | < 5s | New entries only |
| Recall query | < 500ms | With TF-IDF ranking |
| Pattern analysis | < 2s | Cached after first run |

## Migration Plan
1. Ship as opt-in feature behind consent flow
2. Start with `clai recall` for semantic search
3. Add `clai improve` for recommendations
4. Consider background indexing in future release

## Open Questions
- [ ] Should we support exporting patterns as shell aliases?
- [ ] How to handle history from multiple machines (if synced)?
- [ ] Should improve command auto-suggest based on current directory?
