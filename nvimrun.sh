#!/usr/bin/env bash

# nvimrun - Control Neovim instances in tmux sessions
# Allows starting nvim in background, feeding keys, executing lua, and capturing screen

# Default session name
DEFAULT_SESSION="nvim_test"

# Start a new nvim instance in a tmux session
# Usage: nvimrun_start [session_name] [width] [height]
nvimrun_start() {
    local session="${1:-$DEFAULT_SESSION}"
    local width="${2:-80}"
    local height="${3:-24}"
    
    # Check if session already exists
    if tmux has-session -t "$session" 2>/dev/null; then
        echo "Session '$session' already exists. Use nvimrun_stop first." >&2
        return 1
    fi
    
    # Create new detached tmux session with nvim (no config)
    tmux new-session -d -s "$session" -x "$width" -y "$height" "nvim -u NONE"
    
    # Wait a bit for nvim to start
    sleep 0.2
    
    echo "Started nvim in session '$session' (${width}x${height})"
}

# Stop and kill a nvim session
# Usage: nvimrun_stop [session_name]
nvimrun_stop() {
    local session="${1:-$DEFAULT_SESSION}"
    
    if ! tmux has-session -t "$session" 2>/dev/null; then
        echo "Session '$session' does not exist." >&2
        return 1
    fi
    
    tmux kill-session -t "$session"
    echo "Stopped session '$session'"
}

# Send keys to nvim
# Usage: nvimrun_keys [session_name] key1 key2 ...
nvimrun_keys() {
    local session="${1:-$DEFAULT_SESSION}"
    shift
    
    if ! tmux has-session -t "$session" 2>/dev/null; then
        echo "Session '$session' does not exist." >&2
        return 1
    fi
    
    tmux send-keys -t "$session" "$@"
}

# Execute lua code in nvim
# Usage: nvimrun_lua [session_name] "lua code"
nvimrun_lua() {
    local session="${1:-$DEFAULT_SESSION}"
    local lua_code="${2}"
    
    if [ -z "$lua_code" ]; then
        echo "No lua code provided" >&2
        return 1
    fi
    
    if ! tmux has-session -t "$session" 2>/dev/null; then
        echo "Session '$session' does not exist." >&2
        return 1
    fi
    
    # Send the lua command
    tmux send-keys -t "$session" ":lua ${lua_code}" Enter
}

# Capture and display the current screen
# Usage: nvimrun_screen [session_name] [--color]
nvimrun_screen() {
    local session="${1:-$DEFAULT_SESSION}"
    local color_flag=""
    
    # Check for --color flag
    if [ "$1" = "--color" ]; then
        session="${2:-$DEFAULT_SESSION}"
        color_flag="-e"
    elif [ "$2" = "--color" ]; then
        color_flag="-e"
    fi
    
    if ! tmux has-session -t "$session" 2>/dev/null; then
        echo "Session '$session' does not exist." >&2
        return 1
    fi
    
    tmux capture-pane -t "$session" -p $color_flag
}

# Wait for a pattern to appear on screen
# Usage: nvimrun_wait [session_name] "pattern" [timeout]
nvimrun_wait() {
    local session="${1:-$DEFAULT_SESSION}"
    local pattern="${2}"
    local timeout="${3:-5}"
    
    if [ -z "$pattern" ]; then
        echo "No pattern provided" >&2
        return 1
    fi
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if nvimrun_screen "$session" | grep -q "$pattern"; then
            return 0
        fi
        sleep 0.1
        elapsed=$((elapsed + 1))
    done
    
    echo "Timeout waiting for pattern: $pattern" >&2
    return 1
}

# Execute a vim command
# Usage: nvimrun_cmd [session_name] "vim command"
nvimrun_cmd() {
    local session="${1:-$DEFAULT_SESSION}"
    local cmd="${2}"
    
    if [ -z "$cmd" ]; then
        echo "No command provided" >&2
        return 1
    fi
    
    nvimrun_keys "$session" Escape ":${cmd}" Enter
}

# Main function for CLI usage
nvimrun() {
    local command="$1"
    shift
    
    case "$command" in
        start)
            nvimrun_start "$@"
            ;;
        stop)
            nvimrun_stop "$@"
            ;;
        keys)
            nvimrun_keys "$@"
            ;;
        lua)
            nvimrun_lua "$@"
            ;;
        screen)
            nvimrun_screen "$@"
            ;;
        wait)
            nvimrun_wait "$@"
            ;;
        cmd)
            nvimrun_cmd "$@"
            ;;
        *)
            echo "Usage: nvimrun {start|stop|keys|lua|screen|wait|cmd} [args...]"
            echo ""
            echo "Commands:"
            echo "  start [session] [width] [height]  - Start nvim in tmux session"
            echo "  stop [session]                    - Stop nvim session"
            echo "  keys [session] key1 key2...       - Send keys to nvim"
            echo "  lua [session] 'code'              - Execute lua code"
            echo "  screen [session] [--color]        - Capture current screen (with ANSI colors)"
            echo "  wait [session] 'pattern' [timeout] - Wait for pattern on screen"
            echo "  cmd [session] 'command'           - Execute vim command"
            return 1
            ;;
    esac
}

# If script is executed directly, run main function
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    nvimrun "$@"
fi