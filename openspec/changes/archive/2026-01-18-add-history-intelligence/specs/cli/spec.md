## ADDED Requirements

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
