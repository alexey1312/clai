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

    local request='{"explain":{"command":"'"${cmd//\"/\\\"}"'"}}'
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
    task="${task#\#}"
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

    local request='{"suggest":{"task":"'"${task//\"/\\\"}"'"}}'
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

# AI-powered completion function
_clai_complete() {
    local cmd="${LBUFFER}"

    if ! _clai_daemon_available; then
        return 1  # Fall back to default completion
    fi

    local request='{"complete":{"partial":"'"${cmd//\"/\\\"}"'","shell":"zsh"}}'
    local response
    response=$(_clai_request "$request")

    if [[ -z "$response" ]]; then
        return 1  # Fall back to default completion
    fi

    # Parse completions from JSON response
    local completions=()
    while IFS= read -r line; do
        local comp
        comp=$(echo "$line" | grep -o '"completion":"[^"]*"' | cut -d'"' -f4 2>/dev/null)
        local desc
        desc=$(echo "$line" | grep -o '"description":"[^"]*"' | cut -d'"' -f4 2>/dev/null)
        if [[ -n "$comp" ]]; then
            if [[ -n "$desc" ]]; then
                completions+=("$comp:$desc")
            else
                completions+=("$comp")
            fi
        fi
    done <<< "$response"

    if [[ ${#completions[@]} -eq 0 ]]; then
        return 1  # Fall back to default completion
    fi

    _describe 'clai suggestions' completions
}

# Register widgets
zle -N _clai_explain_widget
zle -N _clai_suggest_widget

# Bind hotkeys
bindkey '^X^E' _clai_explain_widget
bindkey '^X^S' _clai_suggest_widget

# Optional: Add clai completions to the completion system
# Uncomment below to enable AI completions on TAB
# compdef _clai_complete -default-
