# Implementation Tasks

## 1. Background Daemon
- [ ] 1.1 Create `DaemonCommand` with start/stop/status subcommands
- [ ] 1.2 Implement Unix domain socket server for IPC
- [ ] 1.3 Add model preloading on daemon start (warm cache)
- [ ] 1.4 Implement graceful shutdown and signal handling
- [ ] 1.5 Add health check endpoint for shell plugins
- [ ] 1.6 Create launchd plist for macOS auto-start (optional)

## 2. Shell Plugin Infrastructure
- [ ] 2.1 Design plugin protocol (JSON over Unix socket)
- [ ] 2.2 Create base shell plugin template
- [ ] 2.3 Implement `clai completions install [shell]` command
- [ ] 2.4 Add plugin uninstall functionality

## 3. Zsh Integration
- [ ] 3.1 Create `_clai_complete` zle widget for autocompletion
- [ ] 3.2 Implement `_clai_explain` widget (Ctrl+X Ctrl+E)
- [ ] 3.3 Implement `_clai_suggest` widget (Ctrl+X Ctrl+S)
- [ ] 3.4 Add completion caching for common commands
- [ ] 3.5 Test with popular zsh frameworks (oh-my-zsh, prezto)

## 4. Bash Integration
- [ ] 4.1 Create completion function using `complete -F`
- [ ] 4.2 Implement readline bindings for explain/suggest
- [ ] 4.3 Test with bash 4.x and 5.x

## 5. Fish Integration
- [ ] 5.1 Create fish completion functions
- [ ] 5.2 Implement key bindings via `bind` command
- [ ] 5.3 Test fish 3.x compatibility

## 6. Testing
- [ ] 6.1 Unit tests for daemon socket communication
- [ ] 6.2 Integration tests for shell plugin protocol
- [ ] 6.3 Performance benchmarks (latency < 200ms goal)
- [ ] 6.4 Manual testing on macOS and Linux

## 7. Documentation
- [ ] 7.1 Update README with shell integration section
- [ ] 7.2 Add troubleshooting guide for common issues
- [ ] 7.3 Document daemon configuration options
