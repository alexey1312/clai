# CLAUDE.md

<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

## TOON Format Convention

Use TOON (Token-Oriented Object Notation) for all tabular data in this file. TOON reduces token usage by 30-60% by declaring fields once in array headers.

```toon
format:
  syntax: name[count]{field1,field2,...}:
  indent: 2 spaces for rows
  delimiter: comma between values

example[2]{id,name,status}:
  1,Build command,active
  2,Test command,active
```

When adding lists of items (modules, commands, files, etc.), always use TOON tables instead of markdown tables or lists.

**Exception:** OpenSpec `tasks.md` — task items MUST use markdown checklists (`- [ ]`) for openspec parsing.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

Uses [mise](https://mise.jdx.dev/) for task running. All output is piped through `xcsift` for cleaner formatting.

```bash
mise run build              # Debug build
mise run build:release      # Release build
mise run test               # Run all tests
mise run test:filter Name   # Run single test (e.g., mise run test:filter ClaiTests)
mise run lint               # SwiftLint strict mode
mise run format             # Format with SwiftFormat
mise run format:check       # Check formatting (CI)
mise run clean              # Clean build artifacts
mise run setup              # Show git hooks status
mise run pre-commit         # Run pre-commit on all files
mise run changelog          # Generate CHANGELOG.md
mise run changelog:unreleased  # Preview unreleased changes
mise run docs               # Generate CLI docs (stdout)
mise run docs:file          # Generate docs to docs/CLI.md
mise run manpage            # Generate man page (stdout)
mise run manpage:file       # Generate man page to man/clai.1
```

Or use Swift directly:
```bash
swift build                 # Build
swift test                  # Test
swift run clai explain ls   # Run the CLI
```

## Important Rules

**MUST run `mise run lint` after completing any code changes.** This ensures code style compliance before committing. The pre-commit hooks will reject non-compliant code, so always lint before finishing a task.

## Conventional Commits

This project enforces [Conventional Commits](https://www.conventionalcommits.org/) via `hk` pre-commit hooks.

**Format:** `<type>(<scope>): <description>`

**Types:**
- `feat` — New feature
- `fix` — Bug fix
- `docs` — Documentation only
- `style` — Formatting, no code change
- `refactor` — Code change without fix/feature
- `perf` — Performance improvement
- `test` — Adding/updating tests
- `build` — Build system or dependencies
- `ci` — CI configuration
- `chore` — Maintenance tasks
- `revert` — Revert previous commit

**Examples:**
```
feat: add MLX provider support
fix(cache): handle empty response correctly
docs: update README with installation steps
refactor(providers): extract common interface
```

**Breaking changes:** Add `!` after type/scope: `feat!: remove deprecated API`

## Architecture

**clai** is an LLM-powered CLI help assistant built with Swift 6.1 and ArgumentParser.

### Provider Chain (Sources/clai/Providers/)
The system uses a fallback chain to find the first available LLM provider:
1. **FoundationModel** - Apple's on-device model (macOS 26+, not yet stable)
2. **MLX** - Local inference on Apple Silicon via `MLXLLM`
3. **Ollama** - Local inference server (prefers llama3.2, qwen3)
4. **Anthropic** - Claude API (uses claude-3-5-haiku)
5. **OpenAI** - GPT API (uses gpt-4o-mini)

All providers implement `LLMProvider` protocol with `generate()` and `generateStreaming()`. User can override with `--provider`.

### Command Flow
```
Clai.swift (entry point, ArgumentParser)
    └── Commands/
            ├── ExplainCommand, SuggestCommand, ExamplesCommand, ManCommand
            ├── ChatCommand (interactive conversation with history)
            ├── CacheCommand (stats, clear)
            ├── CompletionsCommand (install/uninstall shell plugins)
            ├── DaemonCommand (start/stop/status background daemon)
            ├── ModelsCommand (list, interactive management)
            ├── DocsCommand (generate markdown documentation)
            └── ManPageGenCommand (generate man pages)
    └── Daemon/
            ├── DaemonServer (Unix socket server, request routing)
            ├── DaemonClient (client for shell plugins)
            └── DaemonProtocol (JSON wire protocol, request/response types)
    └── Core/
            ├── ModelsManager (MLX/Ollama model operations)
            ├── MLXModelDiscovery (HuggingFace cache scanning)
            ├── CuratedModels (recommended MLX models list)
            ├── ContextGatherer (fetches --help, man pages, tldr)
            ├── PromptBuilder (constructs prompts per operation type)
            ├── ChatMessage (conversation history management)
            └── ClaiEngine (orchestrates generation, filters <think> tags)
    └── Providers/ProviderManager (selects available provider)
    └── Cache/ResponseCache (SQLite cache, 7-day TTL)
    └── UI/TerminalUI (Noora-based output rendering)
```

### Key Dependencies
- **AnyLanguageModel** - Unified interface for MLX, Ollama, Anthropic, OpenAI
- **ArgumentParser** - CLI command/subcommand structure
- **Noora** - Terminal UI components
- **SQLite.swift** - Response caching

### Noora UI Guidelines

**Noora** is Tuist's terminal UI library. Use it for interactive CLI components on macOS (not available on Linux).

**When to use Noora components (via TerminalUI wrapper):**
- `yesOrNoChoicePrompt` — Yes/no questions with arrow key navigation
- `singleChoicePrompt` — Single selection from list with filtering
- `success()`, `warning()`, `error()` — Styled alert messages

**Use Noora directly (no wrapper needed):**
- `progressBarStep` — Progress bars for downloads (see ProviderManager.swift)

**Implementation pattern:**
```swift
#if os(Linux)
    // Fallback to simple print/readLine for Linux
#else
    // Use Noora components
    noora.yesOrNoChoicePrompt(question: "Continue?", defaultAnswer: false)
#endif
```

**Keep custom implementations for:**
- `Spinner` — Works on Linux, simple use case
- `showInfo()` — Plain text output (not alerts)
- Markdown rendering — Custom implementation in `showStyledResponse()`

**Reference:** https://github.com/tuist/Noora

### Data Flow
1. User runs `clai explain "git rebase -i"`
2. `ContextGatherer` fetches `--help` and man page content concurrently
3. `PromptBuilder` constructs provider prompt with gathered context
4. `ProviderManager` finds first available provider from chain
5. `ResponseCache` checks for cached response (keyed by command+mode+provider SHA256)
6. Provider generates response (streaming or batch)
7. `ClaiEngine` filters `<think>` tags from streaming output (for reasoning models)
8. `TerminalUI` renders markdown output

### Model Management
- `clai models` — Interactive TUI for managing local models
- `clai models list` — Non-interactive list of MLX and Ollama models
- MLX models are discovered from `~/.cache/huggingface/hub/` (mlx-community only)
- Curated list of recommended models in `CuratedModels.swift`

### Cache Management
- `clai cache stats` — Show cache statistics (entries, size, path)
- `clai cache clear` — Clear all cached responses
- Cache stored in `~/Library/Caches/clai/clai_cache.sqlite`

### Shell Integration
Background daemon with Unix socket IPC for low-latency AI assistance directly in the shell.

**Daemon Commands:**
- `clai daemon start` — Start background daemon
- `clai daemon stop` — Stop daemon (graceful shutdown)
- `clai daemon status` — Check daemon status (PID, uptime, provider)
- `clai daemon run` — Run in foreground (for debugging)

**Shell Plugin Installation:**
```bash
clai completions install zsh    # Install zsh plugin
clai completions install bash   # Install bash plugin
clai completions install fish   # Install fish plugin
clai completions uninstall zsh  # Remove plugin
clai completions list           # Show installed plugins
```

**Hotkeys (after plugin install):**
- `Ctrl+X Ctrl+E` — Explain command at cursor
- `Ctrl+X Ctrl+S` — Suggest command from natural language task

**Architecture:**
- Socket: `~/.clai/clai.sock` (Unix domain socket)
- PID file: `~/.clai/daemon.pid`
- Log file: `~/.clai/daemon.log`
- Plugins: `~/.clai/plugins/` (zsh/bash) or `~/.config/fish/conf.d/` (fish)

**Protocol:** JSON over Unix socket with newline delimiter
```json
// Request types
{"ping": {}}
{"complete": {"partial": "git reb", "shell": "zsh"}}
{"explain": {"command": "find . -name '*.swift'"}}
{"suggest": {"task": "compress folder"}}

// Response types
{"pong": {"uptimeSeconds": 123.4, "provider": "ollama", "providerReady": true}}
{"success": {"completions": [{"completion": "git rebase", "description": "...", "score": 1.0}]}}
{"success": {"explanation": {"explanation": "...", "isDestructive": false, "warnings": []}}}
{"error": {"message": "...", "code": "providerUnavailable"}}
```

### History Intelligence
Local semantic search over your shell history (zsh, bash, fish). All data stays local.

**Quick Start:**
```bash
clai recall "compress folder"    # Auto-indexes on first use
clai improve --aliases           # Suggests aliases based on usage
```

**Search Commands:**
- `clai recall "<query>"` — Natural language search
  - `--limit N` — Max results (default 10)
  - `--since "1 week ago"` — Time filter
  - `--exact` — Exact match (grep-like)
  - `--json` — JSON output

**Optimization:**
- `clai improve --frequent` — Most used commands
- `clai improve --aliases` — Alias candidates
- `clai improve "<cmd>"` — Analyze specific command
- `clai improve "<cmd>" --llm` — AI-powered suggestions

**Management:**
- `clai history stats` — Index statistics
- `clai history index --full` — Rebuild index
- `clai history clear` — Delete index (privacy)

**Privacy:** All data in `~/Library/Application Support/clai/history/`. Nothing sent to cloud.

## OpenSpec

For planning proposals and architectural changes, consult `/openspec/AGENTS.md`.

<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->
