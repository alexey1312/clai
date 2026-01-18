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
- 💬 **chat** - Interactive conversation with context memory
- 🔍 **recall** - Search command history with natural language
- ⚡ **improve** - Get optimization suggestions for commands
- 📊 **history** - Manage local history index
- 🗂️ **cache** - View stats and clear response cache
- 🤖 **models** - Manage local MLX and Ollama models
- 📄 **docs** - Generate CLI documentation in Markdown
- 📘 **man-page** - Generate man page for clai

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
# Using Homebrew (recommended)
brew tap alexey1312/clai
brew install clai

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

# Start interactive chat
clai chat
```

## Usage

### Commands

| Command    | Description                             | Example                                |
| ---------- | --------------------------------------- | -------------------------------------- |
| `explain`  | Understand what a command does          | `clai explain "chmod 755 script.sh"`   |
| `suggest`  | Get commands for a task                 | `clai suggest "compress a folder"`     |
| `examples` | Show practical usage examples           | `clai examples rsync`                  |
| `man`      | AI-summarized man page                  | `clai man awk`                         |
| `chat`     | Interactive conversation session        | `clai chat`                            |
| `recall`   | Search history with natural language    | `clai recall "compress folder"`        |
| `improve`  | Get command optimization suggestions    | `clai improve --aliases`               |
| `history`  | Manage history index                    | `clai history stats`                   |
| `cache`    | Manage response cache                   | `clai cache stats`                     |
| `models`   | Manage local models                     | `clai models list`                     |
| `docs`     | Generate Markdown documentation         | `clai docs -o docs/CLI.md`             |
| `man-page` | Generate man page                       | `clai man-page -o man/clai.1`          |

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

## Chat Mode

Start an interactive conversation with context memory:

```bash
# Start interactive session
clai chat

# Start with an initial question
clai chat "explain git rebase"
```

**In-session commands:**
- `/exit`, `/quit`, `/q` — Exit the chat session
- `/clear` — Clear conversation history
- `/history` — Show conversation history
- `/help` — Show available commands
- `Ctrl+D` — Exit the session

Chat mode preserves context across messages, allowing natural follow-up questions:

```
[1] > explain git rebase
[assistant explains rebase]

[2] > how do I abort it?
[assistant explains git rebase --abort, referencing the previous context]

[3] > show me an example
[assistant shows example based on the ongoing conversation]
```

## History Intelligence

Search and analyze your shell history with natural language. All data stays local — nothing is sent to cloud providers.

### Quick Start

```bash
# First, index your history (one-time setup)
clai history index

# Search with natural language
clai recall "how did I compress that folder"
clai recall "docker commands" --limit 20
clai recall "git" --since "1 week ago"

# Get optimization suggestions
clai improve --aliases
clai improve "docker ps -a --format '{{.Names}}'"
```

### Privacy

- **All data stays local** — history index is stored in `~/Library/Application Support/clai/history/`
- **Explicit consent** — first use prompts for permission
- **Easy cleanup** — `clai history clear` deletes everything

### Commands

#### `clai recall`

Search your command history using natural language:

```bash
clai recall "compress folder"           # Semantic search
clai recall "tar" --exact               # Exact match
clai recall "git" --since "1 week ago"  # Time filter
clai recall "docker" --limit 20         # More results
clai recall "kubectl" --json            # JSON output
```

**Options:**
- `--limit <n>` — Maximum results (default: 10)
- `--since <date>` — Filter by time ("1 week ago", "2024-01-01", "yesterday")
- `--exact` — Use exact string matching instead of semantic search
- `--json` — Output as JSON for scripting

#### `clai improve`

Get optimization suggestions based on your usage patterns:

```bash
clai improve --aliases                  # Show alias candidates
clai improve --frequent                 # Show most used commands
clai improve "docker ps -a --format..." # Analyze specific command
clai improve "git status" --llm         # Use LLM for suggestions
```

**Options:**
- `--aliases` — Show commands that would benefit from aliases
- `--frequent` — Show most frequently used commands
- `--min-frequency <n>` — Minimum usage count for suggestions (default: 3)
- `--llm` — Use LLM for intelligent suggestions

#### `clai history`

Manage the history index:

```bash
clai history index                      # Build/update index
clai history index --full               # Rebuild from scratch
clai history stats                      # Show statistics
clai history stats --json               # JSON output
clai history clear                      # Delete index
```

### Supported Shells

- **zsh** — Extended history format with timestamps (`~/.zsh_history`)
- **bash** — Standard format with optional timestamps (`~/.bash_history`)
- **fish** — YAML format with paths (`~/.local/share/fish/fish_history`)

### Example Output

```
$ clai recall "compress folder"

Found 3 commands:

[1] tar -czvf archive.tar.gz ./folder
    Jan 15, 2024 • used 5x

[2] zip -r backup.zip ./project
    Jan 10, 2024 • used 2x

[3] tar -cjvf docs.tar.bz2 ./docs
    Dec 28, 2023 • used 1x
```

```
$ clai improve --aliases

Alias Candidates

Commands you use frequently that could be shortened:

[1] Used 12x:
    $ docker ps -a --format '{{.Names}}'

    Suggested alias:
    alias dps='docker ps -a --format '\''{{.Names}}'\'''

[2] Used 8x:
    $ kubectl get pods -n production

    Suggested alias:
    alias kgp='kubectl get pods -n production'

Add these to your ~/.zshrc or ~/.bashrc
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

## Documentation Generation

Generate CLI documentation in various formats:

```bash
# Generate Markdown documentation
clai docs                     # Output to stdout
clai docs -o docs/CLI.md      # Write to file

# Generate man page
clai man-page                 # Output to stdout
clai man-page -o man/clai.1   # Write to file

# View generated man page
man ./man/clai.1
```

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
mise run setup              # Show git hooks status
mise run pre-commit         # Run pre-commit checks
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

## License

MIT License. See [LICENSE](LICENSE) for details.

---

**[Report issues](https://github.com/alexey1312/clai/issues)**
