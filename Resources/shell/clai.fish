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
        set -l escaped_cmd (string replace -a '"' '\\"' "$cmd")
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
    set task (string replace -r '^#\s*' '' "$task")

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
        set -l escaped_task (string replace -a '"' '\\"' "$task")
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
bind \cx\ce _clai_explain
bind \cx\cs _clai_suggest

# Alternative bindings for terminals that don't support Ctrl+X sequences
# Uncomment if the above don't work
# bind \ee _clai_explain  # Alt+E
# bind \es _clai_suggest  # Alt+S
