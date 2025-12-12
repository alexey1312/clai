# Design: clai CLI Architecture

## Context

Creating an LLM-powered CLI help assistant that provides intelligent explanations for command-line tools. Must work offline by default (FoundationModel) with graceful fallback to cloud providers.

## Goals / Non-Goals

### Goals
- Zero-config experience on macOS 26+ (FoundationModel just works)
- Sub-second response for simple queries (local inference)
- Privacy-first: no data leaves device by default
- Extensible provider system via AnyLanguageModel

### Non-Goals
- Not a general-purpose LLM chat interface
- Not a shell replacement or command executor
- Not supporting Windows (Swift toolchain limitation)

### Platform Constraints
| Platform | Available Providers |
|----------|---------------------|
| macOS 26+ (Apple Silicon) | FoundationModel, MLX, Ollama, Cloud |
| macOS 15+ (Apple Silicon) | MLX, Ollama, Cloud |
| macOS (Intel) | Ollama, Cloud |
| Linux | Ollama, Cloud |

**Linux Strategy**: Detect platform at runtime, skip MLX/FoundationModel checks, prioritize Ollama → Cloud fallback.

**Ollama Installation** (user responsibility, clai shows instructions):
- macOS: `brew install ollama` or download from ollama.ai
- Linux: `curl -fsSL https://ollama.ai/install.sh | sh`
- After install: `ollama pull llama3.2` (or configured model)
- clai detects Ollama by checking `localhost:11434/api/tags`

## Decisions

### D1: Use AnyLanguageModel for provider abstraction

**Decision**: Depend on `mattt/anylanguagemodel` package

**Rationale**:
- Unified API across FoundationModel, Ollama, Anthropic, OpenAI
- Trait-based dependencies keep binary size minimal
- Active maintenance, Swift 6 compatible
- `@Generable` macro simplifies structured output

**Alternatives considered**:
- Direct FoundationModel API: Locks to Apple only, no fallback
- Manual multi-provider: Duplicates AnyLanguageModel's work

### D2: Provider priority chain

**Decision**: FoundationModel → MLX (auto-download) → Ollama → Anthropic → OpenAI

**Rationale**:
- FoundationModel: Free, offline, private (best UX on macOS 26+)
- MLX: Free, offline, auto-downloads from HuggingFace (Apple Silicon only)
- Ollama: Free, offline, user-managed models (requires separate install)
- Anthropic/OpenAI: Paid cloud fallback for complex queries

**MLX Auto-Download** (via AnyLanguageModel):
- Default model: `mlx-community/Qwen3-4B-4bit` (~2.5GB)
- Qwen3-4B supports thinking/non-thinking modes, excellent for explanations
- Cached in `~/.cache/huggingface/` for subsequent runs
- Progress shown via Noora progress bar during download

**Download triggers** (user consent required):
1. **First run**: If no local provider available, prompt user:
   ```
   No local LLM found. Download Qwen3-4B (~2.5GB) for offline use?
   [Y]es / [N]o, use cloud / [S]maller model (0.6B, ~400MB)
   ```
2. **Fallback moment**: When FoundationModel unavailable and MLX not cached:
   ```
   FoundationModel unavailable. Download local model or use cloud?
   [D]ownload Qwen3-4B / [C]loud (requires API key) / [S]kip
   ```
3. **Explicit command**: `clai --setup` to pre-download model
4. **User declines**: Remember choice in config, use cloud or show setup instructions

**Configuration**:
```swift
enum Provider: String, CaseIterable {
    case foundation  // Default on macOS 26+
    case mlx         // Auto-download, Apple Silicon only
    case ollama      // Local, requires Ollama server
    case anthropic   // Cloud fallback
    case openai      // Cloud fallback
}
```

**Availability detection order**:
1. Check FoundationModel availability (macOS 26+ API)
2. Check Apple Silicon (`ProcessInfo.processInfo.machineHardwareName`)
3. Check Ollama server (`localhost:11434/api/tags`)
4. Check API key env vars (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`)

### D3: Command information sources

**Decision**: Multi-source context gathering

**Sources** (in order):
1. `--help` / `-h` output from the command itself
2. `man` page content (if available)
3. `tldr` pages (if installed)
4. Built-in knowledge from LLM

**Rationale**: Combining sources gives LLM accurate, command-specific context.

### D4: Output format

**Decision**: Plain text by default, optional JSON for scripting

```bash
clai git rebase
# Plain explanation

clai git rebase --json
# {"command": "git rebase", "explanation": "...", "examples": [...]}
```

### D5: Configuration file

**Decision**: Optional `~/.config/clai/config.toml`

```toml
[provider]
default = "foundation"
fallback = ["mlx", "ollama", "anthropic"]

[mlx]
# Auto-downloads from HuggingFace on first use (~2.5GB)
model_id = "mlx-community/Qwen3-4B-4bit"
# Alternative models:
# model_id = "mlx-community/Qwen3-0.6B-4bit"   # Smaller, faster (~400MB)
# model_id = "mlx-community/Qwen3-8B-4bit"     # Larger, smarter (~5GB)

[ollama]
model = "llama3.2"
host = "http://localhost:11434"

[anthropic]
api_key_env = "ANTHROPIC_API_KEY"
model = "claude-sonnet-4-20250514"

[openai]
api_key_env = "OPENAI_API_KEY"
model = "gpt-4o"
```

### D6: Use Noora for terminal UI

**Decision**: Depend on `tuist/Noora` package for all terminal UI components

**Rationale**:
- Consistent, beautiful CLI design system from Tuist team
- Built-in components: prompts, alerts, progress indicators, text styling
- Active maintenance, Swift 6 compatible
- Provides polished UX without reinventing the wheel

**Components to use**:
- **Alerts**: Success/warning/error messages for provider status, errors
- **Progress**: Spinner during LLM inference, step indicators for multi-stage operations
- **Prompts**: Interactive provider selection, confirmation dialogs
- **Text Styling**: Consistent formatting for explanations, code blocks, examples

**Example usage**:
```swift
import Noora

// Show spinner while waiting for LLM
let noora = Noora()
noora.progressStep(
    message: "Thinking...",
    successMessage: "Done",
    errorMessage: "Failed"
) {
    try await llm.generate(prompt)
}

// Alert for provider fallback
noora.warning("FoundationModel unavailable, using Ollama")

// Success message
noora.success("Explanation generated")
```

**Alternatives considered**:
- Raw ANSI codes: Error-prone, inconsistent across terminals
- Custom UI layer: Duplicates Noora's work, maintenance burden
- No styling: Poor UX, hard to distinguish sections

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      clai CLI                           │
│  (Swift ArgumentParser + Noora UI)                      │
├─────────────────────────────────────────────────────────┤
│                      Noora                              │
│  ┌──────────┬──────────┬───────────┬─────────┐         │
│  │  Alerts  │ Progress │  Prompts  │ Styling │         │
│  └──────────┴──────────┴───────────┴─────────┘         │
├─────────────────────────────────────────────────────────┤
│                   ClaiEngine                            │
│  - Context gathering (help, man, tldr)                  │
│  - Prompt construction                                  │
│  - Response formatting                                  │
├─────────────────────────────────────────────────────────┤
│                 AnyLanguageModel                        │
│  ┌──────────┬──────────┬──────────┬───────────┬───────┐│
│  │Foundation│   MLX    │  Ollama  │ Anthropic │OpenAI ││
│  │  Model   │(HF auto) │          │           │       ││
│  └──────────┴──────────┴──────────┴───────────┴───────┘│
│       ↑           ↑          ↑           ↑        ↑    │
│   macOS 26+   Apple M1+   localhost   cloud    cloud   │
└─────────────────────────────────────────────────────────┘
```

### Key Components

1. **main.swift** - CLI entry point with ArgumentParser
2. **ClaiEngine.swift** - Core logic, context gathering, prompt building
3. **ContextGatherer.swift** - Extracts help/man/tldr content
4. **ProviderManager.swift** - Handles fallback chain
5. **Config.swift** - Configuration file parsing
6. **UI.swift** - Noora-based terminal UI (alerts, progress, prompts)

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| FoundationModel unavailable (pre-macOS 26) | Auto-fallback to MLX with clear message |
| MLX first-run download (~2.5GB) | Show Noora progress bar, cache permanently, offer smaller model option |
| Intel Mac (no MLX support) | Skip MLX, fallback to Ollama or cloud |
| Ollama not installed | Skip in chain, try next provider |
| No API keys configured | Error with setup instructions |
| LLM hallucination | Include actual `--help` output in response for verification |
| Slow cloud responses | Show spinner, cache common queries |
| Disk space for MLX model | Warn user, offer `--provider cloud` override |

## Migration Plan

N/A - New project, no migration needed.

### D7: Repository structure

**Decision**: Monorepo (в текущем репозитории `clai`)

**Rationale**:
- Единая точка управления всеми CLI-инструментами
- Общие CI/CD workflows и настройки
- Возможность переиспользования кода в будущем
- Упрощённый dependency management

### D8: Response caching

**Decision**: SQLite cache with 7-day TTL via [SQLite.swift](https://github.com/stephencelis/SQLite.swift)

**Rationale**:
- Fast local lookups for repeated queries
- SQLite.swift — type-safe Swift wrapper, active maintenance
- 7-day TTL balances freshness with performance
- Cache key: hash(command + provider + model)

**Dependency**: `stephencelis/SQLite.swift`
**Cache location**: `~/.cache/clai/responses.db`

### D9: Shell integration

**Decision**: Not supported in v1.0

**Rationale**:
- `eval $(clai --suggest "...")` is dangerous (arbitrary command execution)
- Safer approach: copy-paste suggested commands
- May revisit with explicit `--exec` flag and confirmation in future version

### D10: Streaming output

**Decision**: Supported with `--stream` flag

**Rationale**:
- Better UX for slow cloud providers
- Local providers (FoundationModel, MLX) are fast enough without streaming
- Noora supports progressive text rendering
