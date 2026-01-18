## ADDED Requirements

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
