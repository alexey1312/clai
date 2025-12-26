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
mise run setup              # Install pre-commit hooks
mise run pre-commit         # Run pre-commit on all files
mise run changelog          # Generate CHANGELOG.md
mise run changelog:unreleased  # Preview unreleased changes
```

Or use Swift directly:
```bash
swift build                 # Build
swift test                  # Test
swift run clai explain ls   # Run the CLI
```

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
            ├── CacheCommand (stats, clear)
            └── ModelsCommand (list, interactive management)
                    └── Core/ModelsManager (MLX/Ollama model operations)
                    └── Core/MLXModelDiscovery (HuggingFace cache scanning)
                    └── Core/CuratedModels (recommended MLX models list)
            └── Core/ContextGatherer (fetches --help, man pages, tldr)
            └── Core/PromptBuilder (constructs prompts per operation type)
            └── Core/ClaiEngine (orchestrates generation, filters <think> tags)
            └── Providers/ProviderManager (selects available provider)
            └── Cache/ResponseCache (SQLite cache, 7-day TTL)
            └── UI/TerminalUI (Noora-based output rendering)
```

### Key Dependencies
- **AnyLanguageModel** - Unified interface for MLX, Ollama, Anthropic, OpenAI
- **ArgumentParser** - CLI command/subcommand structure
- **Noora** - Terminal UI components
- **SQLite.swift** - Response caching

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
