#!/usr/bin/env bash

# nvimrun - Control Neovim instances in tmux sessions
# Allows starting nvim in background, feeding keys, executing lua, and capturing screen

# Default session name
DEFAULT_SESSION="nvim_test"

# Start a new nvim instance in a tmux session
# Usage: nvimrun_start [session_name] [width] [height] [--record]
nvimrun_start() {
    local session="$DEFAULT_SESSION"
    local width="80"
    local height="24"
    local record=false
    
    # Parse arguments
    local args=()
    for arg in "$@"; do
        if [ "$arg" = "--record" ]; then
            record=true
        else
            args+=("$arg")
        fi
    done
    
    # Assign positional parameters
    [ ${#args[@]} -ge 1 ] && session="${args[0]}"
    [ ${#args[@]} -ge 2 ] && width="${args[1]}"
    [ ${#args[@]} -ge 3 ] && height="${args[2]}"
    
    # Check if session already exists
    if tmux has-session -t "$session" 2>/dev/null; then
        echo "Session '$session' already exists. Use nvimrun_stop first." >&2
        return 1
    fi
    
    # Create recordings directory if needed
    local recordings_dir="$HOME/.nvimrun/recordings"
    if $record; then
        mkdir -p "$recordings_dir"
    fi
    
    # Create new detached tmux session with nvim (optionally wrapped in asciinema)
    if $record; then
        local cast_file="$recordings_dir/${session}_$(date +%Y%m%d_%H%M%S).cast"
        tmux new-session -d -s "$session" -x "$width" -y "$height" \
            "asciinema rec --stdin -q '$cast_file' -c 'nvim -u NONE'"
        echo "Recording to: $cast_file"
    else
        tmux new-session -d -s "$session" -x "$width" -y "$height" "nvim -u NONE"
    fi
    
    # Prevent terminal resize when clients attach
    tmux set-option -t "$session" window-size manual 2>/dev/null || true
    
    # Wait a bit for nvim to start
    sleep 0.2
    
    if $record; then
        echo "Started nvim in session '$session' (${width}x${height}) [RECORDING]"
    else
        echo "Started nvim in session '$session' (${width}x${height})"
    fi
    echo "To watch in another terminal: tmux attach -t '$session' -r -x $width -y $height"
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

# Type literal text into nvim (no special key interpretation)
# Usage: nvimrun_type [session_name] "text to type"
#    or: echo "text" | nvimrun_type [session_name] -
nvimrun_type() {
    local session="${1:-$DEFAULT_SESSION}"
    local text="${2}"
    
    # If second argument is "-", read from stdin
    if [ "$text" = "-" ]; then
        text=$(cat)
    elif [ -z "$text" ]; then
        # If no text argument, try reading from stdin if available
        if [ ! -t 0 ]; then
            text=$(cat)
        else
            echo "No text provided" >&2
            return 1
        fi
    fi
    
    if ! tmux has-session -t "$session" 2>/dev/null; then
        echo "Session '$session' does not exist." >&2
        return 1
    fi
    
    # Use -l flag for literal text (no special key interpretation)
    tmux send-keys -l -t "$session" "$text"
}

# List available recordings
# Usage: nvimrun_recordings
nvimrun_recordings() {
    local recordings_dir="$HOME/.nvimrun/recordings"
    
    if [ ! -d "$recordings_dir" ]; then
        echo "No recordings directory found."
        return 0
    fi
    
    local recordings=$(ls -1t "$recordings_dir"/*.cast 2>/dev/null)
    
    if [ -z "$recordings" ]; then
        echo "No recordings found."
        return 0
    fi
    
    echo "Available recordings:"
    echo "$recordings" | while read -r file; do
        local basename=$(basename "$file")
        local size=$(du -h "$file" | cut -f1)
        local date=$(stat -c %y "$file" 2>/dev/null || stat -f %Sm "$file" 2>/dev/null)
        echo "  $basename ($size) - $date"
    done
}

# Play a recording
# Usage: nvimrun_play <recording_file_or_session_pattern>
nvimrun_play() {
    local pattern="$1"
    local recordings_dir="$HOME/.nvimrun/recordings"
    
    if [ -z "$pattern" ]; then
        echo "Usage: nvimrun play <recording_file_or_pattern>" >&2
        return 1
    fi
    
    # If it's a full path and exists, play it
    if [ -f "$pattern" ]; then
        asciinema play "$pattern"
        return $?
    fi
    
    # Otherwise, look for it in recordings directory
    local found=$(find "$recordings_dir" -name "*${pattern}*" -type f 2>/dev/null | head -1)
    
    if [ -z "$found" ]; then
        echo "No recording matching '$pattern' found." >&2
        return 1
    fi
    
    echo "Playing: $found"
    asciinema play "$found"
}

# Analyze recording with AI model
# Usage: nvimrun_analyze <recording_file_or_session_pattern> [summarize]
# 
# Environment variables:
#   MCP_NVIM_TMUX_CMD - Command template (default: "ollama run $MODEL")
#   MCP_NVIM_TMUX_MODEL - Default model for all operations
#   MCP_NVIM_TMUX_ANALYZE_MODEL - Model for analysis step
#   MCP_NVIM_TMUX_SUMMARIZE_MODEL- Model for summarization step
#
# Examples:
#   nvimrun analyze session1
#   nvimrun analyze session1 summarize
#   MCP_NVIM_TMUX_ANALYZE_MODEL=qwen3:8b nvimrun analyze session1
#   MCP_NVIM_TMUX_CMD='gemini --model $MODEL' nvimrun analyze session1
nvimrun_analyze() {
    local pattern="$1"
    local summarize="${2:-false}"
    local recordings_dir="$HOME/.nvimrun/recordings"
    
    if [ -z "$pattern" ]; then
        echo "Usage: nvimrun analyze <recording_file_or_pattern> [summarize]" >&2
        return 1
    fi
    
    # Get the AI command template from environment or use default
    local ai_cmd_template="${MCP_NVIM_TMUX_CMD:-ollama run \$MODEL}"
    
    # Get the appropriate model based on operation
    local model
    if [ "$summarize" = "summarize" ]; then
        model="${MCP_NVIM_TMUX_SUMMARIZE_MODEL:-${MCP_NVIM_TMUX_MODEL:-qwen3:8b}}"
    else
        model="${MCP_NVIM_TMUX_ANALYZE_MODEL:-${MCP_NVIM_TMUX_MODEL:-qwen3:8b}}"
    fi
    
    # Export MODEL for interpolation in the template
    export MODEL="$model"
    
    # Interpolate the command with environment variables
    local ai_cmd=$(eval "echo \"$ai_cmd_template\"")
    
    # Get the recording output
    local recording_output=$(nvimrun_cat "$pattern" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$recording_output" ]; then
        echo "Failed to get recording data" >&2
        return 1
    fi
    
    # Read the analysis prompt
    local prompt_file="${NVIMRUN_PROMPTS_DIR:-$(dirname "$0")/prompts}/analyze_recording.txt"
    if [ ! -f "$prompt_file" ]; then
        # Use inline prompt if file doesn't exist
        local prompt="You are analyzing a Neovim terminal recording. Provide a step-by-step breakdown of the user's actions.

The recording format shows:
- Timeline events with timestamps [X.XXs]
- INPUT: user keystrokes and commands
- OUTPUT: terminal responses and screen updates
- Final screen state showing the result

Analyze what happened by explaining:
1. Initial state when Neovim started
2. Each user input and its purpose
3. Any mode changes (Normal/Insert/Visual/Command)
4. Errors or unexpected behavior
5. Whether the user achieved their goal

Focus on Vim-specific details like:
- Mode transitions (i for insert, Esc for normal, : for command)
- Commands executed (like :w, :q, etc.)
- Text entered or edited
- File operations

Be concise but thorough. Explain what the user was trying to do and what actually happened.
Dont focus on the actual text content, but rather how the nvim interface responded to their actions.


RECORDING DATA:"
    else
        local prompt=$(cat "$prompt_file")
    fi
    
    # Combine prompt with recording data
    local full_prompt="${prompt}
${recording_output}"
    
    # Run the analysis
    if [ "$summarize" = "summarize" ]; then
        # Two-step process: analyze then summarize
        # First run analysis with analyze model
        MODEL="${MCP_NVIM_TMUX_ANALYZE_MODEL:-${MCP_NVIM_TMUX_MODEL:-qwen3:8b}}"
        local analyze_cmd=$(eval "echo \"$ai_cmd_template\"")
        local analysis=$(eval "$analyze_cmd" <<< "$full_prompt" 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "Analysis failed" >&2
            return 1
        fi
        
        # Then summarize with summarize model
        MODEL="${MCP_NVIM_TMUX_SUMMARIZE_MODEL:-${MCP_NVIM_TMUX_MODEL:-qwen3:8b}}"
        local summarize_cmd=$(eval "echo \"$ai_cmd_template\"")
        local summary_prompt="Summarize this Neovim session analysis: $analysis"
        eval "$summarize_cmd" <<< "$summary_prompt" 2>/dev/null
    else
        # Just run the analysis
        eval "$ai_cmd" <<< "$full_prompt" 2>/dev/null
    fi
}

# Display recording as plain text (for non-interactive AI/viewing)
# Usage: nvimrun_cat <recording_file_or_session_pattern>
nvimrun_cat() {
    local pattern="$1"
    local recordings_dir="$HOME/.nvimrun/recordings"
    
    if [ -z "$pattern" ]; then
        echo "Usage: nvimrun cat <recording_file_or_pattern>" >&2
        return 1
    fi
    
    # Find the recording file
    local file=""
    if [ -f "$pattern" ]; then
        file="$pattern"
    else
        file=$(find "$recordings_dir" -name "*${pattern}*" -type f 2>/dev/null | head -1)
    fi
    
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo "No recording matching '$pattern' found." >&2
        return 1
    fi
    
    echo "=== Recording: $(basename "$file") ==="
    
    # Parse header
    local header=$(head -1 "$file")
    local width=$(echo "$header" | sed -n 's/.*"width": *\([0-9]*\).*/\1/p')
    local height=$(echo "$header" | sed -n 's/.*"height": *\([0-9]*\).*/\1/p')
    echo "Terminal size: ${width}x${height}"
    echo ""
    
    # Check if we have jq for better JSON parsing
    if command -v jq >/dev/null 2>&1; then
        echo "=== Session Timeline ==="
        echo ""
        
        # Parse events with jq
        tail -n +2 "$file" | while IFS= read -r line; do
            local timestamp=$(echo "$line" | jq -r '.[0]' 2>/dev/null)
            local event_type=$(echo "$line" | jq -r '.[1]' 2>/dev/null)
            local data=$(echo "$line" | jq -r '.[2]' 2>/dev/null)
            
            if [ -n "$timestamp" ] && [ "$timestamp" != "null" ]; then
                LC_NUMERIC=C printf "[%6.2fs] " "$timestamp"
                
                case "$event_type" in
                    "i")
                        echo "INPUT: $data"
                        ;;
                    "o")
                        # For output, show a preview (first 80 chars, single line)
                        local preview=$(echo "$data" | sed 's/\\[nt]/  /g; s/\\u001b\[[0-9;]*[a-zA-Z]//g' | tr -d '\n' | cut -c1-80)
                        if [ ${#preview} -eq 80 ]; then
                            echo "OUTPUT: ${preview}..."
                        else
                            echo "OUTPUT: $preview"
                        fi
                        ;;
                    "m")
                        echo "MARKER: $data"
                        ;;
                    "r")
                        echo "RESIZE: $data"
                        ;;
                esac
            fi
        done
        
        echo ""
        echo "=== Final Screen State ==="
        echo ""
    fi
    
    # Always show the final rendered output using asciinema cat
    if command -v script >/dev/null 2>&1; then
        # Linux version
        script -q -c "asciinema cat '$file'" /dev/null 2>/dev/null | sed 's/\r$//'
    else
        # Fallback to basic output
        echo "Note: Install 'script' command for better output rendering"
        echo ""
        # Just show raw events as fallback
        tail -n +2 "$file" | head -20
        echo "... (truncated)"
    fi
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
        cmd)
            nvimrun_cmd "$@"
            ;;
        type)
            nvimrun_type "$@"
            ;;
        recordings)
            nvimrun_recordings
            ;;
        play)
            nvimrun_play "$@"
            ;;
        cat)
            nvimrun_cat "$@"
            ;;
        analyze)
            nvimrun_analyze "$@"
            ;;
        *)
            echo "Usage: nvimrun {start|stop|keys|lua|type|screen|cmd|recordings|play|cat|analyze} [args...]"
            echo ""
            echo "Commands:"
            echo "  start [session] [width] [height] [--record] - Start nvim in tmux session"
            echo "  stop [session]                              - Stop nvim session"
            echo "  keys [session] key1 key2...                 - Send keys to nvim"
            echo "  lua [session] 'code'                        - Execute lua code"
            echo "  type [session] 'text'                       - Type literal text (no key interpretation)"
            echo "  screen [session] [--color]                  - Capture current screen (with ANSI colors)"
            echo "  cmd [session] 'command'                     - Execute vim command"
            echo "  recordings                                  - List available recordings"
            echo "  play <recording_or_pattern>                 - Play a recording"
            echo "  cat <recording_or_pattern>                  - Display recording as text"
            echo "  analyze <recording_or_pattern> [summarize]  - Analyze recording with AI"
            return 1
            ;;
    esac
}

# If script is executed directly, run main function
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    nvimrun "$@"
fi