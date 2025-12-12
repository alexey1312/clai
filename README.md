# clai

[![CI](https://github.com/alexey1312/clai/actions/workflows/ci.yml/badge.svg)](https://github.com/alexey1312/clai/actions/workflows/ci.yml)
[![Release](https://github.com/alexey1312/clai/actions/workflows/release.yml/badge.svg)](https://github.com/alexey1312/clai/actions/workflows/release.yml)
[![License](https://img.shields.io/github/license/alexey1312/clai.svg)](LICENSE)

LLM-powered CLI help assistant. Get instant explanations, suggestions, and examples for command-line tools using local
or cloud language models.

Local-first, privacy-friendly.

## Why clai?

- **Instant help**: No more searching Stack Overflow or man pages
- **Plain language**: Get explanations in human-readable format
- **Privacy-first**: Prefers local models, cloud APIs are optional
- **Fast**: Response caching for repeated queries

## Features

- ✨ **explain** - Understand what a command does in plain language
- 💡 **suggest** - Get command suggestions for natural language tasks
- 📚 **examples** - See practical usage examples for any command
- 📖 **man** - Get AI-summarized man pages
- 🗂️ **cache** - View stats and clear response cache
- 🤖 **models** - Manage local MLX and Ollama models

### Provider Support

- 🍎 **FoundationModel** - Apple's on-device model (macOS 26+)
- 🧠 **MLX** - Local inference on Apple Silicon
- 🦙 **Ollama** - Local inference server
- 🤖 **Anthropic** - Claude API
- 🔮 **OpenAI** - GPT API

### Developer Experience

- ⚡ Smart provider auto-selection
- 💾 Response caching (7-day TTL)
- 📊 Streaming output support
- 🔇 JSON output mode for scripting

## Quick Start

### 1. Install clai

```bash
# Using mise
mise use -g ubi:alexey1312/clai

# Or build from source
git clone https://github.com/alexey1312/clai.git
cd clai
swift build -c release
cp .build/release/clai /usr/local/bin/
```

### 2. (Optional) Set Up a Provider

clai automatically selects the best available provider. For local inference without API keys:

```bash
# Install Ollama
brew install ollama

# Start the server
ollama serve

# Pull a model
ollama pull llama3.2
```

For cloud providers:

```bash
export ANTHROPIC_API_KEY="your-key-here"
# or
export OPENAI_API_KEY="your-key-here"
```

### 3. Use clai

```bash
# Explain a command
clai explain "git rebase -i HEAD~3"

# Get command suggestions
clai suggest "find files larger than 100MB"

# Show examples
clai examples tar

# Summarize a man page
clai man grep
```

## Usage

### Commands

| Command   | Description                             | Example                                |
| --------- | --------------------------------------- | -------------------------------------- |
| `explain` | Understand what a command does          | `clai explain "chmod 755 script.sh"`   |
| `suggest` | Get commands for a task                 | `clai suggest "compress a folder"`     |
| `examples`| Show practical usage examples           | `clai examples rsync`                  |
| `man`     | AI-summarized man page                  | `clai man awk`                         |
| `cache`   | Manage response cache                   | `clai cache stats`                     |
| `models`  | Manage local models                     | `clai models list`                     |

### Options

```
--provider <provider>  Use specific provider (foundation, mlx, ollama, anthropic, openai)
--json                 Output in JSON format
--verbose              Show diagnostic information
--stream               Stream the response
--no-cache             Skip response cache
```

## Providers

clai automatically selects the best available provider in this order:

1. **FoundationModel** - Apple's on-device model (macOS 26+, experimental)
2. **MLX** - Local inference on Apple Silicon via `MLXLLM`
3. **Ollama** - Local inference server (prefers llama3.2, qwen3)
4. **Anthropic** - Claude API (uses claude-3-5-haiku)
5. **OpenAI** - GPT API (uses gpt-4o-mini)

Override with `--provider`:

```bash
clai explain "ls -la" --provider ollama
clai suggest "search in files" --provider anthropic
```

## Configuration

clai can be configured via `~/.config/clai/config.yaml`:

```yaml
provider:
  default: ollama        # Default provider
  fallback:              # Fallback chain
    - foundation
    - mlx
    - ollama
    - anthropic
    - openai

mlx:
  model_id: mlx-community/Qwen3-4B-4bit
  download_consented: false
  prefer_small_model: false

ollama:
  model: llama3.2
  host: http://localhost:11434

anthropic:
  api_key_env: ANTHROPIC_API_KEY
  model: claude-3-5-haiku-20241022

openai:
  api_key_env: OPENAI_API_KEY
  model: gpt-4o-mini

cache:
  enabled: true
  ttl_days: 7
```

### Environment Variable Overrides

```bash
CLAI_PROVIDER=ollama       # Override default provider
CLAI_MLX_MODEL=...         # Override MLX model
CLAI_OLLAMA_MODEL=...      # Override Ollama model
CLAI_OLLAMA_HOST=...       # Override Ollama host
CLAI_CACHE_ENABLED=true    # Enable/disable caching
```

## Shell Completions

Generate completion scripts for your shell:

```bash
# Zsh
clai completions zsh > ~/.zsh/completions/_clai
# Add to .zshrc: fpath=(~/.zsh/completions $fpath)

# Bash
clai completions bash > /etc/bash_completion.d/clai
# Or for user install:
clai completions bash > ~/.local/share/bash-completion/completions/clai

# Fish
clai completions fish > ~/.config/fish/completions/clai.fish
```

## Model Management

Manage local MLX and Ollama models with the `models` command:

```bash
# Interactive model management (TUI)
clai models

# List all models (non-interactive)
clai models list
```

**Interactive mode** allows you to:
- View downloaded and available MLX models
- Set default model for inference
- Download new MLX models from curated list
- Delete MLX models to free disk space

**Curated MLX models** (optimized for Apple Silicon):
| Model | Size | Description |
|-------|------|-------------|
| Qwen3-0.6B | ~400MB | Fastest, minimal memory |
| DeepSeek-R1-1.5B | ~1GB | Good reasoning ability |
| Qwen3-4B | ~2.5GB | Best balance (recommended) |
| DeepSeek-R1-7B | ~4GB | High quality, more memory |

## Caching

Responses are cached in `~/Library/Caches/clai/` with a 7-day TTL.

```bash
# View cache statistics
clai cache stats

# Clear all cached responses
clai cache clear
```

- Cache key: SHA256 of command + mode + provider
- Bypass with `--no-cache` flag
- SQLite-based storage

## Requirements

- **Swift 6.1+** (for building from source)
- **macOS 14.0+**

## Development

Uses [mise](https://mise.jdx.dev/) for task running:

```bash
mise run build              # Debug build
mise run build:release      # Release build
mise run test               # Run all tests
mise run lint               # SwiftLint strict mode
mise run format             # Format with SwiftFormat
mise run format:check       # Check formatting (CI)
mise run clean              # Clean build artifacts
mise run setup              # Install pre-commit hooks
```

Or use Swift directly:

```bash
swift build                 # Build
swift test                  # Test
swift run clai explain ls   # Run the CLI
```

## License

MIT License. See [LICENSE](LICENSE) for details.

---

**[Report issues](https://github.com/alexey1312/clai/issues)**
