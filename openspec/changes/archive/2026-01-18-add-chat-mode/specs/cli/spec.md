## ADDED Requirements

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
