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
        local request='{"explain":{"command":"'"${cmd//\"/\\\"}"'"}}'
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
    task="${task#\#}"
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
        local request='{"suggest":{"task":"'"${task//\"/\\\"}"'"}}'
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
bind -x '"\C-x\C-e": _clai_explain'
bind -x '"\C-x\C-s": _clai_suggest'
