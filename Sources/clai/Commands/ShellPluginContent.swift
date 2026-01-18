import Foundation

// MARK: - Shell Plugin Status

/// Status of a shell plugin installation
struct ShellPluginStatus {
    let shell: ShellType
    let installed: Bool
    let path: String
}

// MARK: - Embedded Plugin Content

/// Shell plugin scripts embedded in the binary
enum ShellPluginContent {
    static func content(for shell: ShellType) -> String {
        switch shell {
        case .zsh: zshPlugin
        case .bash: bashPlugin
        case .fish: fishPlugin
        }
    }
}

// MARK: - Zsh Plugin

private let zshPlugin = """
# clai shell integration for zsh
# Provides AI-powered autocompletion and hotkeys
#
# Hotkeys:
#   Ctrl+X Ctrl+E - Explain command at cursor
#   Ctrl+X Ctrl+S - Suggest command from natural language

# Socket path for daemon communication
CLAI_SOCKET="${HOME}/.clai/clai.sock"

# Timeout for daemon responses (ms)
CLAI_TIMEOUT="${CLAI_TIMEOUT:-200}"

# Check if daemon is available
_clai_daemon_available() {
    [[ -S "$CLAI_SOCKET" ]]
}

# Send request to daemon and get response
_clai_request() {
    local request="$1"
    local timeout="${2:-$CLAI_TIMEOUT}"

    if ! _clai_daemon_available; then
        return 1
    fi

    # Use timeout with nc (netcat) for Unix socket communication
    echo "$request" | timeout "${timeout}ms" nc -U "$CLAI_SOCKET" 2>/dev/null
}

# Explain command at cursor (Ctrl+X Ctrl+E)
_clai_explain_widget() {
    local cmd="$BUFFER"

    if [[ -z "$cmd" ]]; then
        zle -M "clai: Type a command first, then press Ctrl+X Ctrl+E to explain"
        return
    fi

    if ! _clai_daemon_available; then
        # Fall back to direct clai call
        zle -M "$(clai explain "$cmd" 2>/dev/null | head -5)"
        return
    fi

    local request='{"explain":{"command":"'"${cmd//\\"/\\\\\\"}"'"}}'
    local response
    response=$(_clai_request "$request" 1000)

    if [[ -n "$response" ]]; then
        # Parse JSON response and display
        local explanation
        explanation=$(echo "$response" | grep -o '"explanation":"[^"]*"' | cut -d'"' -f4 2>/dev/null)
        if [[ -n "$explanation" ]]; then
            zle -M "$explanation"
        else
            zle -M "$(clai explain "$cmd" 2>/dev/null | head -5)"
        fi
    else
        zle -M "$(clai explain "$cmd" 2>/dev/null | head -5)"
    fi
}

# Suggest command from natural language (Ctrl+X Ctrl+S)
_clai_suggest_widget() {
    local task="$BUFFER"

    # Remove leading # or comment markers
    task="${task#\\#}"
    task="${task## }"

    if [[ -z "$task" ]]; then
        zle -M "clai: Type a task description (e.g., '# find large files'), then press Ctrl+X Ctrl+S"
        return
    fi

    if ! _clai_daemon_available; then
        # Fall back to direct clai call
        local suggestion
        suggestion=$(clai suggest "$task" 2>/dev/null | head -1)
        if [[ -n "$suggestion" ]]; then
            BUFFER="$suggestion"
            CURSOR=${#BUFFER}
        fi
        return
    fi

    local request='{"suggest":{"task":"'"${task//\\"/\\\\\\"}"'"}}'
    local response
    response=$(_clai_request "$request" 1000)

    if [[ -n "$response" ]]; then
        # Parse JSON response and replace buffer
        local command
        command=$(echo "$response" | grep -o '"command":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null)
        if [[ -n "$command" ]]; then
            BUFFER="$command"
            CURSOR=${#BUFFER}
            local explanation
            explanation=$(echo "$response" | grep -o '"explanation":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null)
            if [[ -n "$explanation" ]]; then
                zle -M "$explanation"
            fi
        fi
    else
        # Fall back to direct clai call
        local suggestion
        suggestion=$(clai suggest "$task" 2>/dev/null | head -1)
        if [[ -n "$suggestion" ]]; then
            BUFFER="$suggestion"
            CURSOR=${#BUFFER}
        fi
    fi
}

# Register widgets
zle -N _clai_explain_widget
zle -N _clai_suggest_widget

# Bind hotkeys
bindkey '^X^E' _clai_explain_widget
bindkey '^X^S' _clai_suggest_widget
"""

// MARK: - Bash Plugin

private let bashPlugin = """
# clai shell integration for bash
# Provides AI-powered hotkeys
#
# Hotkeys:
#   Ctrl+X Ctrl+E - Explain command at cursor
#   Ctrl+X Ctrl+S - Suggest command from natural language

# Socket path for daemon communication
CLAI_SOCKET="${HOME}/.clai/clai.sock"

# Timeout for daemon responses (ms)
CLAI_TIMEOUT="${CLAI_TIMEOUT:-200}"

# Check if daemon is available
_clai_daemon_available() {
    [[ -S "$CLAI_SOCKET" ]]
}

# Send request to daemon and get response
_clai_request() {
    local request="$1"
    local timeout="${2:-$CLAI_TIMEOUT}"

    if ! _clai_daemon_available; then
        return 1
    fi

    # Use timeout with nc (netcat) for Unix socket communication
    echo "$request" | timeout "${timeout}ms" nc -U "$CLAI_SOCKET" 2>/dev/null
}

# Explain command at cursor (Ctrl+X Ctrl+E)
_clai_explain() {
    local cmd="$READLINE_LINE"

    if [[ -z "$cmd" ]]; then
        echo
        echo "clai: Type a command first, then press Ctrl+X Ctrl+E to explain"
        return
    fi

    echo  # New line for output

    if ! _clai_daemon_available; then
        # Fall back to direct clai call
        clai explain "$cmd" 2>/dev/null | head -5
    else
        local request='{"explain":{"command":"'"${cmd//\\"/\\\\\\"}"'"}}'
        local response
        response=$(_clai_request "$request" 1000)

        if [[ -n "$response" ]]; then
            # Parse JSON response and display
            local explanation
            explanation=$(echo "$response" | grep -o '"explanation":"[^"]*"' | cut -d'"' -f4 2>/dev/null)
            if [[ -n "$explanation" ]]; then
                echo "$explanation"
            else
                clai explain "$cmd" 2>/dev/null | head -5
            fi
        else
            clai explain "$cmd" 2>/dev/null | head -5
        fi
    fi

    # Redraw prompt
    echo -n "${PS1@P}$READLINE_LINE"
}

# Suggest command from natural language (Ctrl+X Ctrl+S)
_clai_suggest() {
    local task="$READLINE_LINE"

    # Remove leading # or comment markers
    task="${task#\\#}"
    task="${task## }"

    if [[ -z "$task" ]]; then
        echo
        echo "clai: Type a task description (e.g., '# find large files'), then press Ctrl+X Ctrl+S"
        return
    fi

    local suggestion=""

    if ! _clai_daemon_available; then
        # Fall back to direct clai call
        suggestion=$(clai suggest "$task" 2>/dev/null | head -1)
    else
        local request='{"suggest":{"task":"'"${task//\\"/\\\\\\"}"'"}}'
        local response
        response=$(_clai_request "$request" 1000)

        if [[ -n "$response" ]]; then
            # Parse JSON response
            suggestion=$(echo "$response" | grep -o '"command":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null)
            local explanation
            explanation=$(echo "$response" | grep -o '"explanation":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null)
            if [[ -n "$explanation" ]]; then
                echo
                echo "$explanation"
            fi
        fi

        if [[ -z "$suggestion" ]]; then
            suggestion=$(clai suggest "$task" 2>/dev/null | head -1)
        fi
    fi

    if [[ -n "$suggestion" ]]; then
        READLINE_LINE="$suggestion"
        READLINE_POINT=${#READLINE_LINE}
    fi
}

# Bind hotkeys
bind -x '"\\C-x\\C-e": _clai_explain'
bind -x '"\\C-x\\C-s": _clai_suggest'
"""

// MARK: - Fish Plugin

private let fishPlugin = """
# clai shell integration for fish
# Provides AI-powered hotkeys
#
# Hotkeys:
#   Ctrl+X Ctrl+E - Explain command at cursor
#   Ctrl+X Ctrl+S - Suggest command from natural language

# Socket path for daemon communication
set -g CLAI_SOCKET "$HOME/.clai/clai.sock"

# Timeout for daemon responses (ms)
set -q CLAI_TIMEOUT; or set -g CLAI_TIMEOUT 200

# Check if daemon is available
function _clai_daemon_available
    test -S "$CLAI_SOCKET"
end

# Send request to daemon and get response
function _clai_request
    set -l request $argv[1]
    set -l timeout $argv[2]
    test -z "$timeout"; and set timeout $CLAI_TIMEOUT

    if not _clai_daemon_available
        return 1
    end

    # Use timeout with nc (netcat) for Unix socket communication
    echo "$request" | timeout (math "$timeout / 1000")"s" nc -U "$CLAI_SOCKET" 2>/dev/null
end

# Explain command at cursor (Ctrl+X Ctrl+E)
function _clai_explain
    set -l cmd (commandline)

    if test -z "$cmd"
        echo
        echo "clai: Type a command first, then press Ctrl+X Ctrl+E to explain"
        commandline -f repaint
        return
    end

    echo  # New line for output

    if not _clai_daemon_available
        # Fall back to direct clai call
        clai explain "$cmd" 2>/dev/null | head -5
    else
        set -l escaped_cmd (string replace -a '"' '\\\\"' "$cmd")
        set -l request '{"explain":{"command":"'$escaped_cmd'"}}'
        set -l response (_clai_request "$request" 1000)

        if test -n "$response"
            # Parse JSON response and display
            set -l explanation (echo "$response" | string match -r '"explanation":"([^"]*)"' | tail -1)
            if test -n "$explanation"
                echo "$explanation"
            else
                clai explain "$cmd" 2>/dev/null | head -5
            end
        else
            clai explain "$cmd" 2>/dev/null | head -5
        end
    end

    commandline -f repaint
end

# Suggest command from natural language (Ctrl+X Ctrl+S)
function _clai_suggest
    set -l task (commandline)

    # Remove leading # or comment markers
    set task (string replace -r '^#\\s*' '' "$task")

    if test -z "$task"
        echo
        echo "clai: Type a task description (e.g., '# find large files'), then press Ctrl+X Ctrl+S"
        commandline -f repaint
        return
    end

    set -l suggestion ""

    if not _clai_daemon_available
        # Fall back to direct clai call
        set suggestion (clai suggest "$task" 2>/dev/null | head -1)
    else
        set -l escaped_task (string replace -a '"' '\\\\"' "$task")
        set -l request '{"suggest":{"task":"'$escaped_task'"}}'
        set -l response (_clai_request "$request" 1000)

        if test -n "$response"
            # Parse JSON response
            set suggestion (echo "$response" | string match -r '"command":"([^"]*)"' | head -1 | tail -1)
            set -l explanation (echo "$response" | string match -r '"explanation":"([^"]*)"' | head -1 | tail -1)
            if test -n "$explanation"
                echo
                echo "$explanation"
            end
        end

        if test -z "$suggestion"
            set suggestion (clai suggest "$task" 2>/dev/null | head -1)
        end
    end

    if test -n "$suggestion"
        commandline -r "$suggestion"
        commandline -f end-of-line
    end

    commandline -f repaint
end

# Bind hotkeys
bind \\cx\\ce _clai_explain
bind \\cx\\cs _clai_suggest
"""
