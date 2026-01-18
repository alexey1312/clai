# Change: Add Shell Integration with AI-Powered Autocomplete

## Why
Users must currently switch between their terminal and clai to get help. This friction reduces adoption and limits clai to explicit invocations. Shell integration brings AI assistance directly into the user's workflow, eliminating context switching and enabling real-time command suggestions.

## What Changes
- Add `clai completions install` command for one-line shell plugin installation
- Create shell plugins for zsh, bash, and fish with AI-powered autocompletion
- Implement background daemon (`clai daemon`) for low-latency responses
- Add inline explain hotkey (e.g., `Ctrl+X Ctrl+E`) to explain command at cursor
- Add suggestion hotkey (e.g., `Ctrl+X Ctrl+S`) for task-to-command suggestions

## Impact
- Affected specs: `cli`
- Affected code:
  - `Sources/clai/Commands/DaemonCommand.swift` (new)
  - `Sources/clai/Commands/CompletionsCommand.swift` (extend)
  - `Sources/clai/Daemon/` (new module)
  - Shell plugin scripts in `Resources/shell/`
- New dependencies: Unix domain sockets for IPC

## Risks
- Latency: AI completions must feel instant (<200ms) or UX suffers
- Shell compatibility: Different shell versions may behave differently
- Resource usage: Background daemon must be lightweight

## Success Metrics
- Plugin installation rate among active users
- Suggestion acceptance rate (how often users use AI suggestions)
- P95 latency for autocomplete suggestions < 200ms
