# Specification: clai CLI

## ADDED Requirements

### Requirement: Command Explanation
The system SHALL explain CLI commands in plain language when invoked with a command name.

#### Scenario: Basic command explanation
- **GIVEN** clai is installed and a provider is available
- **WHEN** user runs `clai git rebase`
- **THEN** system outputs a plain-language explanation of `git rebase`
- **AND** includes common use cases and gotchas

#### Scenario: Complex command with arguments
- **GIVEN** clai is installed and a provider is available
- **WHEN** user runs `clai --explain "find . -name '*.swift' -exec rm {} \;"`
- **THEN** system breaks down each argument and explains its purpose
- **AND** warns about destructive operations if applicable

### Requirement: Command Suggestion
The system SHALL suggest appropriate CLI commands based on natural language descriptions.

#### Scenario: Simple task suggestion
- **GIVEN** clai is installed and a provider is available
- **WHEN** user runs `clai --suggest "find large files in current directory"`
- **THEN** system outputs one or more commands that accomplish the task
- **AND** explains what each suggested command does

#### Scenario: No suitable command found
- **GIVEN** clai is installed and a provider is available
- **WHEN** user runs `clai --suggest "impossible task that no CLI can do"`
- **THEN** system indicates no direct CLI solution exists
- **AND** may suggest alternative approaches

### Requirement: Usage Examples
The system SHALL provide practical usage examples for CLI commands.

#### Scenario: Command examples
- **GIVEN** clai is installed and a provider is available
- **WHEN** user runs `clai --examples tar`
- **THEN** system outputs common tar usage patterns
- **AND** examples are copy-pasteable with realistic arguments

### Requirement: Man Page Summarization
The system SHALL summarize man pages in plain language.

#### Scenario: Summarize man page
- **GIVEN** clai is installed and a provider is available
- **GIVEN** man page exists for the command
- **WHEN** user runs `clai --man rsync`
- **THEN** system outputs a concise summary of rsync's purpose and key options
- **AND** highlights the most commonly used flags

#### Scenario: Man page not found
- **GIVEN** clai is installed
- **WHEN** user runs `clai --man nonexistent-command`
- **THEN** system indicates man page not found
- **AND** falls back to LLM knowledge if available

### Requirement: Provider Fallback Chain
The system SHALL automatically fall back through configured providers when the primary is unavailable.

#### Scenario: FoundationModel available
- **GIVEN** macOS 26+ with FoundationModel enabled
- **WHEN** user runs any clai command without `--provider` flag
- **THEN** system uses FoundationModel for inference
- **AND** no network requests are made

#### Scenario: FoundationModel unavailable, MLX cached
- **GIVEN** macOS < 26 or FoundationModel disabled
- **GIVEN** Apple Silicon Mac with MLX model already downloaded
- **WHEN** user runs any clai command
- **THEN** system uses MLX for local inference
- **AND** displays message about using local MLX model

#### Scenario: FoundationModel unavailable, Ollama available
- **GIVEN** FoundationModel and MLX unavailable
- **GIVEN** Ollama is running locally
- **WHEN** user runs any clai command
- **THEN** system falls back to Ollama
- **AND** displays message about using Ollama

#### Scenario: Local providers unavailable, cloud configured
- **GIVEN** FoundationModel, MLX, and Ollama unavailable
- **GIVEN** ANTHROPIC_API_KEY environment variable is set
- **WHEN** user runs any clai command
- **THEN** system uses Anthropic API
- **AND** displays message about using cloud provider

#### Scenario: No providers available
- **GIVEN** no providers are available or configured
- **WHEN** user runs any clai command
- **THEN** system exits with error code 1
- **AND** displays setup instructions for available providers

#### Scenario: Linux with Ollama
- **GIVEN** Linux system with Ollama running
- **WHEN** user runs any clai command
- **THEN** system uses Ollama for inference
- **AND** MLX/FoundationModel options are not shown

#### Scenario: Linux without Ollama, cloud available
- **GIVEN** Linux system without Ollama
- **GIVEN** ANTHROPIC_API_KEY is set
- **WHEN** user runs any clai command
- **THEN** system uses Anthropic API
- **AND** suggests installing Ollama for free local inference

#### Scenario: Show Ollama installation instructions
- **GIVEN** Ollama is not installed
- **GIVEN** no cloud API keys configured
- **WHEN** user runs any clai command
- **THEN** system shows platform-specific installation instructions
- **AND** shows `curl -fsSL https://ollama.ai/install.sh | sh` for Linux
- **AND** shows `brew install ollama` for macOS
- **AND** reminds to run `ollama pull <model>` after installation

### Requirement: MLX Model Download Consent
The system SHALL request user consent before downloading MLX models.

#### Scenario: First run on Apple Silicon without local model
- **GIVEN** Apple Silicon Mac without FoundationModel
- **GIVEN** MLX model not yet downloaded
- **WHEN** user runs clai for the first time
- **THEN** system prompts user with download options
- **AND** offers choices: download full model, download smaller model, use cloud, skip

#### Scenario: User accepts full model download
- **GIVEN** user is prompted for MLX download
- **WHEN** user selects "download full model"
- **THEN** system downloads Qwen3-4B (~2.5GB) with progress bar
- **AND** caches model for future use
- **AND** proceeds with the original command

#### Scenario: User selects smaller model
- **GIVEN** user is prompted for MLX download
- **WHEN** user selects "smaller model"
- **THEN** system downloads Qwen3-0.6B (~400MB) with progress bar
- **AND** saves preference in config file

#### Scenario: User declines download
- **GIVEN** user is prompted for MLX download
- **WHEN** user selects "use cloud" or "skip"
- **THEN** system remembers preference in config
- **AND** falls back to next available provider
- **AND** does not prompt again on subsequent runs

#### Scenario: Explicit setup command
- **GIVEN** clai is installed on Apple Silicon
- **WHEN** user runs `clai --setup`
- **THEN** system downloads configured MLX model
- **AND** shows download progress via Noora progress bar
- **AND** confirms successful installation

### Requirement: Provider Selection Override
The system SHALL allow explicit provider selection via CLI flag.

#### Scenario: Force specific provider
- **GIVEN** clai is installed
- **WHEN** user runs `clai --provider ollama git status`
- **THEN** system uses Ollama regardless of fallback chain
- **AND** fails if Ollama is unavailable (no fallback)

### Requirement: JSON Output
The system SHALL support JSON output for scripting integration.

#### Scenario: JSON output mode
- **GIVEN** clai is installed and a provider is available
- **WHEN** user runs `clai git commit --json`
- **THEN** system outputs valid JSON with structured response
- **AND** JSON includes fields: command, explanation, examples (if applicable)

### Requirement: Configuration File
The system SHALL support optional configuration via ~/.config/clai/config.toml.

#### Scenario: Custom default provider
- **GIVEN** ~/.config/clai/config.toml exists with `default = "ollama"`
- **WHEN** user runs clai without `--provider` flag
- **THEN** system uses Ollama as first choice instead of FoundationModel

#### Scenario: No configuration file
- **GIVEN** ~/.config/clai/config.toml does not exist
- **WHEN** user runs clai
- **THEN** system uses built-in defaults (FoundationModel → Ollama → Cloud)

### Requirement: Context Gathering
The system SHALL gather context from multiple sources to improve LLM responses.

#### Scenario: Include help output in context
- **GIVEN** target command supports `--help`
- **WHEN** clai explains the command
- **THEN** system captures `--help` output
- **AND** includes it in the LLM prompt for accuracy

#### Scenario: Include man page in context
- **GIVEN** man page exists for target command
- **WHEN** clai explains or summarizes the command
- **THEN** system extracts man page content
- **AND** includes relevant sections in the LLM prompt

### Requirement: Setup Command
The system SHALL provide a setup command to pre-download models and verify configuration.

#### Scenario: Pre-download MLX model
- **GIVEN** Apple Silicon Mac without cached MLX model
- **WHEN** user runs `clai --setup`
- **THEN** system downloads configured MLX model with progress bar
- **AND** verifies model integrity after download
- **AND** displays success message with model location

#### Scenario: Setup on system with FoundationModel
- **GIVEN** macOS 26+ with FoundationModel available
- **WHEN** user runs `clai --setup`
- **THEN** system confirms FoundationModel is ready
- **AND** optionally offers to download MLX as backup

### Requirement: Response Caching
The system SHALL cache LLM responses to improve performance for repeated queries.

#### Scenario: Cache hit
- **GIVEN** clai was previously run with `clai git rebase`
- **GIVEN** cache entry exists and is not expired
- **WHEN** user runs `clai git rebase` again
- **THEN** system returns cached response immediately
- **AND** does not make LLM inference call

#### Scenario: Cache bypass
- **GIVEN** cache entry exists for a query
- **WHEN** user runs `clai git rebase --no-cache`
- **THEN** system makes fresh LLM inference call
- **AND** updates cache with new response

#### Scenario: Cache expiration
- **GIVEN** cache entry is older than 7 days
- **WHEN** user runs the same query
- **THEN** system makes fresh LLM inference call
- **AND** replaces expired cache entry

### Requirement: Verbose Output
The system SHALL provide detailed diagnostic output when verbose mode is enabled.

#### Scenario: Verbose provider selection
- **GIVEN** clai is installed
- **WHEN** user runs `clai --verbose git status`
- **THEN** system displays which providers were checked
- **AND** shows which provider was selected and why
- **AND** shows context sources used (help, man, tldr)

### Requirement: Streaming Output
The system SHALL support streaming LLM responses for real-time display.

#### Scenario: Stream cloud provider response
- **GIVEN** cloud provider (Anthropic/OpenAI) is being used
- **WHEN** user runs `clai --stream git rebase`
- **THEN** system displays response tokens as they arrive
- **AND** shows typing indicator during generation

#### Scenario: Stream with local provider
- **GIVEN** local provider (FoundationModel/MLX) is being used
- **WHEN** user runs `clai --stream git rebase`
- **THEN** system displays response with streaming
- **AND** response appears faster than waiting for full completion

### Requirement: Error Handling
The system SHALL handle errors gracefully and provide actionable feedback.

#### Scenario: Network failure during MLX download
- **GIVEN** user initiated MLX model download
- **WHEN** network connection fails mid-download
- **THEN** system displays error with retry option
- **AND** preserves partial download for resume

#### Scenario: Invalid command
- **GIVEN** clai is installed
- **WHEN** user runs `clai nonexistent-command-xyz`
- **THEN** system indicates command not found on system
- **AND** still attempts to explain based on LLM knowledge
- **AND** warns that information may be inaccurate
