# Tasks: clai CLI Implementation

## 1. Project Setup
- [x] 1.1 Create Package.swift with dependencies (ArgumentParser, AnyLanguageModel, Noora, SQLite.swift)
- [x] 1.2 Configure trait-based imports for AnyLanguageModel providers
- [x] 1.3 Set up CI workflow (macOS + Linux)
- [x] 1.4 Add README.md with installation instructions
- [x] 1.5 Run `make lint` before commits (swift-format lint --strict --recursive .)

## 2. Core CLI Structure
- [x] 2.1 Implement main.swift with ArgumentParser command structure
- [x] 2.2 Define subcommands: `explain`, `suggest`, `examples`, `man`
- [x] 2.3 Add flags: `--provider`, `--json`, `--verbose`, `--no-cache`
- [x] 2.4 Implement `--version` and `--help`
- [x] 2.5 Implement `--setup` command for pre-downloading MLX model
- [x] 2.6 Add `--stream` flag for streaming output
- [x] 2.7 Add `--no-cache` flag to bypass response cache
- [x] 2.8 Add `--verbose` flag for diagnostic output

## 3. Context Gathering
- [x] 3.1 Implement `--help` output capture for target commands
- [x] 3.2 Implement `man` page extraction
- [x] 3.3 Implement `tldr` page lookup (optional)
- [x] 3.4 Create ContextGatherer protocol for testability

## 4. Provider Management
- [x] 4.1 Implement ProviderManager with fallback chain
- [x] 4.2 Add FoundationModel provider (macOS 26+)
- [x] 4.3 Add MLX provider with HuggingFace download
- [x] 4.4 Implement MLX model download progress (Noora progress bar)
- [x] 4.5 Add Apple Silicon detection for MLX availability
- [x] 4.6 Implement user consent prompt for MLX download (Noora prompt)
- [x] 4.7 Add "smaller model" option (Qwen3-0.6B) in consent dialog
- [x] 4.8 Remember user's download preference in config
- [x] 4.9 Add Ollama provider with configurable host/model
- [x] 4.10 Add Anthropic provider with API key from env
- [x] 4.11 Add OpenAI provider with API key from env
- [x] 4.12 Implement provider availability detection chain
- [x] 4.13 Add Linux platform detection (skip MLX/FoundationModel)
- [x] 4.14 Show "install Ollama" suggestion on Linux without local provider
- [x] 4.15 Display platform-specific Ollama installation instructions
- [x] 4.16 Remind user to run `ollama pull <model>` after installation

## 5. ClaiEngine Core
- [x] 5.1 Implement prompt templates for each mode (explain, suggest, examples, man)
- [x] 5.2 Build context injection into prompts
- [x] 5.3 Implement response parsing and formatting
- [x] 5.4 Add JSON output mode

## 6. Configuration
- [x] 6.1 Define Config struct with Codable
- [x] 6.2 Implement YAML parsing for ~/.config/clai/config.yaml
- [x] 6.3 Add environment variable overrides
- [x] 6.4 Implement config validation

## 7. Terminal UI (Noora)
- [x] 7.1 Create UI.swift wrapper for Noora components
- [x] 7.2 Implement progress spinner for LLM inference
- [x] 7.3 Add success/warning/error alerts for provider status
- [x] 7.4 Implement styled text output for explanations and examples
- [x] 7.5 Add interactive prompts for provider selection (when multiple available)
- [x] 7.6 Implement step indicators for multi-stage operations
- [x] 7.7 Implement streaming output with Noora progress

## 8. Testing
- [x] 8.1 Unit tests for ContextGatherer
- [x] 8.2 Unit tests for prompt construction
- [x] 8.3 Integration tests with mock LLM responses
- [x] 8.4 End-to-end tests with real providers (manual/CI)

## 9. Documentation
- [x] 9.1 Write comprehensive README
- [x] 9.2 Add man page for clai itself
- [x] 9.3 Create example usage guide (in README)
- [x] 9.4 Document configuration options (in README)

## 10. Shell Integration
- [x] 10.1 Generate Zsh completions
- [x] 10.2 Generate Bash completions
- [x] 10.3 Generate Fish completions
- [x] 10.4 Add installation instructions for completions

## 11. Caching (SQLite.swift)
- [x] 11.1 Add SQLite.swift dependency to Package.swift
- [x] 11.2 Create SQLite cache schema (responses table)
- [x] 11.3 Implement cache key generation (command + provider + model hash)
- [x] 11.4 Add cache lookup before LLM call
- [x] 11.5 Implement cache write after successful response
- [x] 11.6 Add 7-day TTL expiration logic
- [x] 11.7 Implement `--no-cache` flag handling

## 12. Error Handling
- [x] 12.1 Define error types enum (ClaiError)
- [x] 12.2 Implement network failure recovery for downloads
- [x] 12.3 Add partial download resume support
- [x] 12.4 Create user-friendly error messages with Noora alerts
