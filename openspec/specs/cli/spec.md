# cli Specification

## Purpose
TBD - created by archiving change add-clai-cli. Update Purpose after archive.
## Requirements
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

### Requirement: Interactive Chat Mode
The system SHALL provide an interactive conversation mode with context preservation.

#### Scenario: Start chat session
- **GIVEN** clai is installed and a provider is available
- **WHEN** user runs `clai chat`
- **THEN** system enters interactive mode
- **AND** displays welcome message with instructions
- **AND** shows numbered prompt awaiting input

#### Scenario: Start chat with initial message
- **GIVEN** clai is installed and a provider is available
- **WHEN** user runs `clai chat "explain git rebase"`
- **THEN** system enters interactive mode
- **AND** immediately processes the initial message
- **AND** awaits follow-up input

#### Scenario: Context preservation across turns
- **GIVEN** user is in chat mode
- **GIVEN** user previously asked about git rebase
- **WHEN** user asks "how do I abort it?"
- **THEN** system understands reference to previous context
- **AND** responds about git rebase --abort specifically

#### Scenario: Exit with command
- **GIVEN** user is in chat mode
- **WHEN** user types `/exit` or `/quit` or `/q`
- **THEN** system exits chat mode gracefully
- **AND** displays goodbye message

#### Scenario: Exit with Ctrl+D
- **GIVEN** user is in chat mode
- **WHEN** user presses Ctrl+D (EOF)
- **THEN** system exits chat mode gracefully

#### Scenario: Clear conversation history
- **GIVEN** user is in chat mode with existing history
- **WHEN** user types `/clear`
- **THEN** system clears conversation history
- **AND** confirms history cleared
- **AND** continues in chat mode

#### Scenario: Show conversation history
- **GIVEN** user is in chat mode with existing history
- **WHEN** user types `/history`
- **THEN** system displays previous messages
- **AND** shows role (user/assistant) for each message

#### Scenario: Show help
- **GIVEN** user is in chat mode
- **WHEN** user types `/help`
- **THEN** system displays available commands
- **AND** shows keyboard shortcuts

#### Scenario: Unknown command
- **GIVEN** user is in chat mode
- **WHEN** user types `/unknown`
- **THEN** system shows warning about unknown command
- **AND** suggests `/help` for available commands

#### Scenario: Empty input
- **GIVEN** user is in chat mode
- **WHEN** user presses Enter without input
- **THEN** system ignores empty input
- **AND** shows prompt again

#### Scenario: Non-TTY environment
- **GIVEN** clai is invoked in non-interactive environment
- **WHEN** user runs `clai chat`
- **THEN** system shows error requiring interactive terminal
- **AND** exits with non-zero status

### Requirement: Chat History Token Management
The system SHALL manage conversation history within token limits.

#### Scenario: Long conversation
- **GIVEN** user is in chat mode
- **GIVEN** conversation exceeds token budget
- **WHEN** user sends a new message
- **THEN** system truncates older messages to fit within budget
- **AND** preserves most recent context
- **AND** continues conversation normally

### Requirement: History Indexing
The system SHALL index shell command history for semantic search while keeping all data local.

#### Scenario: First-time consent
- **GIVEN** clai is installed
- **GIVEN** history index does not exist
- **WHEN** user runs `clai recall "any query"`
- **THEN** system prompts for consent to index history
- **AND** explains that all data stays local
- **AND** proceeds only if user confirms

#### Scenario: Manual index build
- **GIVEN** clai is installed
- **WHEN** user runs `clai history index`
- **THEN** system parses shell history files (zsh, bash, or fish)
- **AND** builds searchable index in `~/.clai/history/`
- **AND** shows progress bar during indexing
- **AND** reports number of commands indexed

#### Scenario: Incremental indexing
- **GIVEN** history index already exists
- **WHEN** user runs `clai history index`
- **THEN** system only indexes new commands since last run
- **AND** completes faster than full reindex

#### Scenario: Unsupported shell
- **GIVEN** user's shell history format is not recognized
- **WHEN** user runs `clai history index`
- **THEN** system shows error with supported shells list
- **AND** suggests manual history file path option

### Requirement: Recall Command
The system SHALL provide natural language search over command history.

#### Scenario: Semantic search
- **GIVEN** history index exists
- **WHEN** user runs `clai recall "how did I compress that folder"`
- **THEN** system searches index using semantic matching
- **AND** returns relevant commands ranked by relevance
- **AND** shows timestamp if available

#### Scenario: Search with time filter
- **GIVEN** history index exists
- **WHEN** user runs `clai recall "docker" --since "1 week ago"`
- **THEN** system returns only commands from the past week
- **AND** matching the search query

#### Scenario: Limit results
- **GIVEN** history index exists
- **WHEN** user runs `clai recall "git" --limit 5`
- **THEN** system returns at most 5 matching commands

#### Scenario: Exact match mode
- **GIVEN** history index exists
- **WHEN** user runs `clai recall "tar -czvf" --exact`
- **THEN** system searches for exact substring match
- **AND** ignores semantic matching

#### Scenario: No results found
- **GIVEN** history index exists
- **WHEN** user runs `clai recall "command that was never used"`
- **THEN** system indicates no matching commands found
- **AND** suggests broader search terms

#### Scenario: Index not built
- **GIVEN** history index does not exist
- **GIVEN** user previously declined consent
- **WHEN** user runs `clai recall "any query"`
- **THEN** system reminds user to run `clai history index`
- **AND** does not prompt for consent again in same session

### Requirement: Improve Command
The system SHALL suggest optimizations based on command usage patterns.

#### Scenario: Alias candidate detection
- **GIVEN** history index exists
- **GIVEN** user frequently uses `docker ps -a --format "{{.Names}}"`
- **WHEN** user runs `clai improve "docker ps -a --format \"{{.Names}}\""`
- **THEN** system recognizes high frequency usage
- **AND** suggests alias: `alias dps='docker ps -a --format "{{.Names}}"'`

#### Scenario: Flag suggestions
- **GIVEN** history index exists
- **GIVEN** user mostly uses `ls -la` but occasionally `ls`
- **WHEN** user runs `clai improve "ls"`
- **THEN** system notes common flag patterns
- **AND** suggests: "You typically use `ls -la`. Consider making it default."

#### Scenario: Show frequent commands
- **GIVEN** history index exists
- **WHEN** user runs `clai improve --frequent`
- **THEN** system shows top 10 most frequent long commands
- **AND** suggests aliases for each

#### Scenario: No improvement suggestions
- **GIVEN** history index exists
- **WHEN** user runs `clai improve "ls"`
- **GIVEN** command is already simple/optimal
- **THEN** system indicates no improvements suggested
- **AND** shows current usage statistics

### Requirement: History Statistics
The system SHALL provide statistics about the command history index.

#### Scenario: Show index stats
- **GIVEN** history index exists
- **WHEN** user runs `clai history stats`
- **THEN** system shows total commands indexed
- **AND** shows index size on disk
- **AND** shows last indexed timestamp
- **AND** shows breakdown by shell

#### Scenario: Index does not exist
- **GIVEN** history index does not exist
- **WHEN** user runs `clai history stats`
- **THEN** system indicates no index exists
- **AND** suggests running `clai history index`

### Requirement: History Clear
The system SHALL allow users to delete their history index for privacy.

#### Scenario: Clear index
- **GIVEN** history index exists
- **WHEN** user runs `clai history clear`
- **THEN** system prompts for confirmation
- **AND** deletes all index files in `~/.clai/history/`
- **AND** confirms deletion

#### Scenario: Force clear without confirmation
- **GIVEN** history index exists
- **WHEN** user runs `clai history clear --yes`
- **THEN** system deletes index without prompting
- **AND** confirms deletion

#### Scenario: Clear non-existent index
- **GIVEN** history index does not exist
- **WHEN** user runs `clai history clear`
- **THEN** system indicates no index to clear

### Requirement: Background Daemon
The system SHALL provide a background daemon for low-latency shell integration.

#### Scenario: Start daemon
- **GIVEN** clai is installed
- **WHEN** user runs `clai daemon start`
- **THEN** daemon starts and listens on Unix socket at `~/.clai/clai.sock`
- **AND** preloads the configured LLM provider for warm responses
- **AND** exits cleanly if another daemon instance is already running

#### Scenario: Stop daemon
- **GIVEN** daemon is running
- **WHEN** user runs `clai daemon stop`
- **THEN** daemon shuts down gracefully
- **AND** removes the socket file

#### Scenario: Daemon status
- **GIVEN** clai is installed
- **WHEN** user runs `clai daemon status`
- **THEN** system shows whether daemon is running
- **AND** displays uptime if running
- **AND** shows provider being used

#### Scenario: Daemon auto-recovery
- **GIVEN** daemon is running
- **WHEN** daemon receives fatal error
- **THEN** daemon logs error and attempts restart
- **AND** notifies user if repeated failures occur

### Requirement: Shell Plugin Installation
The system SHALL provide commands to install and manage shell integration plugins.

#### Scenario: Install zsh plugin
- **GIVEN** clai is installed
- **WHEN** user runs `clai completions install zsh`
- **THEN** system creates `~/.clai/plugins/clai.zsh`
- **AND** adds source line to `~/.zshrc` if not present
- **AND** displays instructions to restart shell or source file

#### Scenario: Install bash plugin
- **GIVEN** clai is installed
- **WHEN** user runs `clai completions install bash`
- **THEN** system creates `~/.clai/plugins/clai.bash`
- **AND** adds source line to `~/.bashrc` if not present

#### Scenario: Install fish plugin
- **GIVEN** clai is installed
- **WHEN** user runs `clai completions install fish`
- **THEN** system creates `~/.config/fish/conf.d/clai.fish`
- **AND** plugin is automatically loaded on next fish session

#### Scenario: Uninstall plugin
- **GIVEN** shell plugin is installed
- **WHEN** user runs `clai completions uninstall [shell]`
- **THEN** system removes plugin file
- **AND** removes source line from shell config file

#### Scenario: List installed plugins
- **GIVEN** clai is installed
- **WHEN** user runs `clai completions list`
- **THEN** system shows which shell plugins are installed
- **AND** shows status of each (active/inactive)

### Requirement: AI-Powered Autocompletion
The system SHALL provide AI-enhanced command autocompletion via shell plugins.

#### Scenario: Complete partial command
- **GIVEN** shell plugin is active and daemon is running
- **WHEN** user types `git reb` and presses TAB
- **THEN** system suggests `git rebase` and other relevant completions
- **AND** suggestions include brief descriptions

#### Scenario: Complete with context
- **GIVEN** shell plugin is active
- **WHEN** user types `docker run -` and presses TAB
- **THEN** system suggests common docker run flags
- **AND** prioritizes flags based on usage patterns

#### Scenario: Daemon unavailable fallback
- **GIVEN** shell plugin is active but daemon is not running
- **WHEN** user presses TAB for completion
- **THEN** system falls back to shell's default completion
- **AND** does not hang or produce errors

#### Scenario: Completion timeout
- **GIVEN** shell plugin is active and daemon is running
- **WHEN** daemon takes longer than 200ms to respond
- **THEN** system falls back to shell's default completion
- **AND** logs timeout for debugging

### Requirement: Inline Explain Hotkey
The system SHALL provide a hotkey to explain the command at cursor position.

#### Scenario: Explain current command
- **GIVEN** shell plugin is active and daemon is running
- **GIVEN** user has typed `find . -name "*.log" -mtime +7 -delete`
- **WHEN** user presses Ctrl+X Ctrl+E
- **THEN** system displays explanation below the prompt
- **AND** explains each flag and argument
- **AND** warns about destructive operations

#### Scenario: Explain partial command
- **GIVEN** shell plugin is active
- **GIVEN** user has typed partial command `tar -cz`
- **WHEN** user presses Ctrl+X Ctrl+E
- **THEN** system explains what is typed so far
- **AND** suggests common completions

#### Scenario: Empty command line
- **GIVEN** shell plugin is active
- **WHEN** user presses Ctrl+X Ctrl+E with empty command line
- **THEN** system shows brief help about available hotkeys

### Requirement: Inline Suggest Hotkey
The system SHALL provide a hotkey to convert natural language to commands.

#### Scenario: Suggest from description
- **GIVEN** shell plugin is active and daemon is running
- **GIVEN** user has typed `# find large files over 100MB`
- **WHEN** user presses Ctrl+X Ctrl+S
- **THEN** system replaces line with suggested command
- **AND** shows explanation of suggested command

#### Scenario: Multiple suggestions
- **GIVEN** shell plugin is active
- **GIVEN** task has multiple valid solutions
- **WHEN** user presses Ctrl+X Ctrl+S
- **THEN** system shows numbered list of suggestions
- **AND** user can select with number key

#### Scenario: No suitable command
- **GIVEN** shell plugin is active
- **GIVEN** user describes impossible task
- **WHEN** user presses Ctrl+X Ctrl+S
- **THEN** system indicates no direct CLI solution
- **AND** suggests alternative approaches if available

