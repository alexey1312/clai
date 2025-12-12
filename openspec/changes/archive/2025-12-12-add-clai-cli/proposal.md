# Change: Add clai - LLM-powered CLI help assistant

## Why

Command-line tools have inconsistent help interfaces (`-h`, `--help`, `-H`, `help`), and man pages are often cryptic for newcomers. With macOS 26+ introducing free, on-device FoundationModel (Apple Intelligence), there's an opportunity to create an intelligent CLI assistant that explains commands in plain language.

Inspired by [orhun/halp](https://github.com/orhun/halp) (Rust), but reimagined with LLM capabilities instead of simple flag enumeration.

## What Changes

- **NEW PROJECT**: Create `clai` - a Swift CLI tool for intelligent command-line help
- Uses [AnyLanguageModel](https://github.com/mattt/anylanguagemodel) for unified LLM access
- Uses [Noora](https://github.com/tuist/Noora) for beautiful terminal UI (alerts, progress, prompts)
- **Default provider**: FoundationModel (free, offline, private on macOS 26+)
- **Fallback chain**: FoundationModel → MLX (auto-download) → Ollama → Cloud APIs
- **MLX auto-download**: On Apple Silicon, automatically downloads Qwen3-4B (~2.5GB) from HuggingFace on first run — no manual setup required
- Built with Swift ArgumentParser + Noora (polished CLI UX)

### Core Features

1. **Command explanation** - `clai git rebase` → plain language explanation
2. **Argument breakdown** - `clai --explain "find . -name '*.swift' -exec rm {} \;"` → what each part does
3. **Command suggestion** - `clai --suggest "find large files"` → suggests `du -sh * | sort -rh`
4. **Examples** - `clai --examples git` → practical usage examples
5. **Man page summarization** - `clai --man tar` → LLM-summarized man page

## Impact

- **New project**: Standalone Swift package, potentially in same repo or separate
- **Shared infrastructure**: Reuses xcsift patterns (ArgumentParser, CI workflow)
- **Target audience**: Developers, DevOps, anyone learning CLI tools

### Platform Support

| Platform | Local Providers | Cloud Providers |
|----------|-----------------|-----------------|
| **macOS 26+ (Apple Silicon)** | FoundationModel, MLX, Ollama | Anthropic, OpenAI |
| **macOS 15+ (Apple Silicon)** | MLX, Ollama | Anthropic, OpenAI |
| **macOS (Intel)** | Ollama | Anthropic, OpenAI |
| **Linux** | Ollama | Anthropic, OpenAI |

**Linux note**: Full functionality via Ollama (free, local) or Cloud APIs. No MLX/FoundationModel support.
