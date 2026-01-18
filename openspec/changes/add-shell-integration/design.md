# Shell Integration Design

## Context
clai currently requires explicit invocation (`clai explain <cmd>`). Users want inline assistance while typing commands. This requires:
1. Low-latency responses (< 200ms for autocomplete UX)
2. Shell-native integration (zsh, bash, fish)
3. Minimal resource overhead when idle

## Goals
- Bring AI assistance directly into shell workflow
- Maintain < 200ms P95 latency for suggestions
- Support zsh, bash, and fish shells
- Work offline with local providers (MLX, Ollama)

## Non-Goals
- Windows PowerShell support (future work)
- Full shell replacement (we augment, not replace)
- Training custom models for CLI understanding

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     User's Shell                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Shell Plugin (zsh/bash/fish)                    │   │
│  │  - Intercepts TAB, hotkeys                       │   │
│  │  - Sends requests to daemon                      │   │
│  │  - Displays suggestions inline                   │   │
│  └──────────────────────┬──────────────────────────┘   │
└─────────────────────────┼───────────────────────────────┘
                          │ Unix Domain Socket
                          │ ~/.clai/clai.sock
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   clai daemon                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Socket    │  │   Request   │  │   Provider  │     │
│  │   Server    │──│   Router    │──│   Manager   │     │
│  └─────────────┘  └─────────────┘  └──────┬──────┘     │
│                                           │            │
│  ┌─────────────┐  ┌─────────────┐         │            │
│  │  Response   │  │    Model    │◄────────┘            │
│  │    Cache    │  │    Pool     │                      │
│  └─────────────┘  └─────────────┘                      │
└─────────────────────────────────────────────────────────┘
```

## Decisions

### Decision: Unix Domain Sockets for IPC
**Why:** Faster than TCP (no network stack overhead), secure (file permissions), well-supported across platforms.
**Alternatives considered:**
- Named pipes: Less flexible, platform differences
- TCP localhost: Unnecessary overhead, security concerns
- Shared memory: Complex, overkill for our use case

### Decision: Background Daemon Architecture
**Why:** Model loading is slow (1-3s for MLX). Daemon keeps model warm for instant responses.
**Alternatives considered:**
- On-demand process spawn: Too slow (model load each time)
- Shell function with cached process: Complex, unreliable

### Decision: JSON Protocol over Socket
**Why:** Simple, debuggable, language-agnostic for shell scripts.
**Format:**
```json
// Request
{"type": "complete", "input": "git reb", "cursor": 7}
{"type": "explain", "command": "find . -name '*.swift'"}
{"type": "suggest", "task": "compress folder"}

// Response
{"suggestions": ["git rebase", "git rebase -i HEAD~3"]}
{"explanation": "This command..."}
{"commands": ["tar -czvf archive.tar.gz folder/"]}
```

### Decision: Optional Daemon (Graceful Degradation)
**Why:** If daemon isn't running, shell plugins fall back to direct `clai` invocation (slower but works).

## Latency Budget

| Phase | Target | Notes |
|-------|--------|-------|
| Shell → Daemon | < 5ms | Unix socket, local |
| Request parsing | < 1ms | JSON decode |
| Cache lookup | < 5ms | In-memory LRU |
| LLM inference | < 150ms | MLX/Ollama hot |
| Response serialize | < 1ms | JSON encode |
| Daemon → Shell | < 5ms | Unix socket |
| **Total** | **< 200ms** | P95 goal |

## Shell Plugin Protocol

### Installation
```bash
# Zsh
clai completions install zsh
# Adds to ~/.zshrc:
# source ~/.clai/plugins/clai.zsh

# Bash
clai completions install bash
# Adds to ~/.bashrc:
# source ~/.clai/plugins/clai.bash

# Fish
clai completions install fish
# Copies to ~/.config/fish/conf.d/clai.fish
```

### Hotkeys (Configurable)
| Hotkey | Action | Description |
|--------|--------|-------------|
| `TAB` | Smart complete | AI-enhanced completion (falls back to default) |
| `Ctrl+X Ctrl+E` | Explain | Explain command at cursor |
| `Ctrl+X Ctrl+S` | Suggest | Convert natural language to command |

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Daemon crashes | Shell plugin hangs | Timeout (100ms), fallback to direct invocation |
| High memory usage | System slowdown | Lazy model loading, memory limits |
| Shell conflicts | User frustration | Opt-in installation, easy uninstall |
| Slow on first request | Poor UX | Model preload on daemon start |

## Migration Plan
1. Ship daemon as opt-in feature (`clai daemon start`)
2. Release shell plugins with documentation
3. Add `clai completions install` for easy setup
4. Consider auto-start via launchd/systemd in future release

## Open Questions
- [ ] Should we support custom hotkey configuration?
- [ ] How to handle multi-line commands in explain mode?
- [ ] Should daemon auto-start on shell launch?
