# @aetherall/mcp-nvim-tmux

An MCP (Model Context Protocol) server that enables AI agents to control Neovim instances running in tmux sessions. Features session recording, AI-powered analysis, and a standalone bash script for direct usage.

## Features

- **Session Management**: Start/stop Neovim in detached tmux sessions
- **Remote Control**: Send keystrokes, execute Vim commands and Lua code
- **Screen Capture**: Capture current screen content with optional ANSI colors
- **Pattern Matching**: Wait for specific patterns to appear on screen
- **Session Recording**: Record sessions with asciinema including user input
- **AI Analysis**: Analyze recordings with configurable AI models to understand user actions
- **Flexible Configuration**: Support for multiple AI backends through environment variables

## Installation

### Using Nix Flakes
```bash
# Run directly
nix run github:aetherall/mcp-nvim-tmux#nvimrun -- start mysession
nix run github:aetherall/mcp-nvim-tmux#mcpnvimtmux

# Install to profile
nix profile install github:aetherall/mcp-nvim-tmux#nvimrun
nix profile install github:aetherall/mcp-nvim-tmux#mcpnvimtmux

# Development shell
nix develop github:aetherall/mcp-nvim-tmux
```

### For Direct Usage
```bash
chmod +x nvimrun.sh
```

## Basic Usage

```bash
# Start a session
./nvimrun.sh start my_session 80 24

# Start with recording
./nvimrun.sh start my_session 80 24 --record

# Send keys (for navigation and special keys)
./nvimrun.sh keys my_session i              # Enter insert mode
./nvimrun.sh keys my_session Escape         # Exit to normal mode
./nvimrun.sh keys my_session dd             # Delete line
./nvimrun.sh keys my_session C-w l          # Move to right window

# Type literal text (no escaping needed!)
./nvimrun.sh type my_session "Hello World! Special chars: $HOME != $(pwd)"

# Execute vim command
./nvimrun.sh cmd my_session "w hello.txt"

# Capture screen
./nvimrun.sh screen my_session

# Stop session
./nvimrun.sh stop my_session
```

## Recording and Analysis

```bash
# List recordings
./nvimrun.sh recordings

# Play a recording
./nvimrun.sh play session_name

# Display recording in AI-readable format
./nvimrun.sh cat session_name

# Analyze recording with AI
./nvimrun.sh analyze session_name

# Get a summary of the recording
./nvimrun.sh analyze session_name summarize

# Use custom AI models
MCP_NVIM_TMUX_ANALYZE_MODEL=qwen3:8b ./nvimrun.sh analyze session_name
MCP_NVIM_TMUX_CMD='gemini --model $MODEL' ./nvimrun.sh analyze session_name
```

## Lua Code Execution

For simple Lua code:
```bash
./nvimrun.sh lua my_session 'print("Hello")'
```

For complex Lua code with special characters, use a temporary file:
```bash
# Save your Lua code to a file
cat > /tmp/script.lua << 'EOF'
print("Complex code with special chars: !@#$")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {"Line 1", "Line 2"})
EOF

# Execute it
./nvimrun.sh keys my_session ":luafile /tmp/script.lua" Enter
```

## Advanced Features

### Colored Output
```bash
./nvimrun.sh screen my_session --color > output.ansi
```

### Wait for Patterns
```bash
./nvimrun.sh wait my_session "Pattern to find" 5  # 5 second timeout
```

## Tips

1. **Text Input**: Use `type` for literal text (no escaping needed) and `keys` for special keys
2. **Special Keys**: Common keys include `Enter`, `Tab`, `Escape`, `C-w` (Ctrl+w), `Space`
3. **Timing**: Some operations need time to complete. Add small delays with `sleep 0.1`
4. **Clean Config**: nvimrun starts Neovim with `-u NONE` to avoid loading user configs

## Monitoring Sessions

When you start a session, you can watch it in real-time from another terminal:

```bash
# Start a session (this will show the attach command)
./nvimrun.sh start my_session

# In another terminal, attach in read-only mode to watch
tmux attach -t my_session -r

# To detach from watching: Press Ctrl+b, then d
```

Other useful tmux commands:
- `tmux ls` - List all sessions
- `tmux attach -t session_name` - Attach with control (careful - may interfere with automation)
- `tmux kill-session -t session_name` - Force kill a stuck session

## Examples

### Create and edit a Python file
```bash
./nvimrun.sh start dev
./nvimrun.sh keys dev i  # Enter insert mode
./nvimrun.sh type dev "def main():\n    print('Hello, World!')\n    return 0"
./nvimrun.sh keys dev Escape  # Exit insert mode
./nvimrun.sh cmd dev "w main.py"
./nvimrun.sh stop dev
```

### Run Vim macros
```bash
./nvimrun.sh start macro_test
./nvimrun.sh keys macro_test "qa" "0dwA," Escape "q"  # Record macro
./nvimrun.sh keys macro_test "5@a"  # Run macro 5 times
./nvimrun.sh stop macro_test
```

## MCP Server Usage

### Setup with Nix
No installation needed! Use directly with `nix run`.

### Configuration for Claude Desktop


```json
{
  "mcpServers": {
    "nvim": {
      "command": "nix",
      "args": ["run", "github:aetherall/mcp-nvim-tmux"]
    }
  }
}
```

#### For Claude Code (CLI)

```bash
claude mcp add nvim -- nix run github:aetherall/mcp-nvim-tmux
```

### Available MCP Tools
- `nvim_start` - Start a new Neovim session (with optional recording)
- `nvim_stop` - Stop a Neovim session
- `nvim_keys` - Send keystrokes (for special keys like Enter, Tab, Escape, Ctrl sequences)
- `nvim_cmd` - Execute Vim commands
- `nvim_lua` - Execute simple Lua code
- `nvim_lua_file` - Execute complex Lua code (multiline safe)
- `nvim_screen` - Capture screen content
- `nvim_edit` - Open file at specific line
- `nvim_type` - Type literal text without special key interpretation (perfect for code and special chars)
- `nvim_recordings` - List available recordings
- `nvim_play` - Play a recording
- `nvim_cat` - Display recording in AI-readable format
- `nvim_analyze` - Analyze recording with AI

### Keys vs Type: When to Use Which

**Use `nvim_keys` for:**
- Navigation: `["h", "j", "k", "l"]`, `["g", "g"]`, `["G"]`
- Mode changes: `["i"]`, `["Escape"]`, `["v"]`, `[":"]`
- Special keys: `["Enter"]`, `["Tab"]`, `["C-w"]`, `["Space"]`
- Vim commands: `["d", "d"]`, `["y", "y"]`, `["p"]`

**Use `nvim_type` for:**
- Code with special characters: `"const url = 'https://example.com?id=${}';"`
- Shell commands: `"docker run -it --rm -v $(pwd):/app node"`
- Any literal text: `"Hello! This has $pecial ch@rs & quotes \"like this\""`

## Environment Variables

- `MCP_NVIM_TMUX_CMD` - AI command template (default: `ollama run $MODEL`)
- `MCP_NVIM_TMUX_MODEL` - Default model for all AI operations
- `MCP_NVIM_TMUX_ANALYZE_MODEL` - Model for analysis operations
- `MCP_NVIM_TMUX_SUMMARIZE_MODEL` - Model for summarization
- `NVIMRUN_PROMPTS_DIR` - Directory for prompt templates

## Troubleshooting

- **Session exists error**: Use `nvimrun.sh stop <session>` first
- **Lua errors**: Check for special characters that need escaping
- **Screen not updating**: Add small delays with `sleep 0.5`
- **AI analysis fails**: Ensure ollama or your AI tool is installed and in PATH
- **Recording not found**: Check pattern matches with `nvimrun.sh recordings`

## Documentation

For comprehensive documentation including all parameters and examples, see [MCP_DOCUMENTATION.md](MCP_DOCUMENTATION.md).

## License

MIT