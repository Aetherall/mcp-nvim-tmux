# @aetherall/mcp-nvim-tmux

## WARNING: THIS WAS VIBECODED WITH A SINGLE PROMPT, DO NOT EXPECT MAINTENANCE OR SUPPORT, DOCUMENTATION AND FEATURES MAY BE HALLUCINATED

An MCP (Model Context Protocol) server that enables AI agents to control Neovim instances running in tmux sessions. Includes a standalone bash script for direct usage.

## Features

- Start/stop Neovim in detached tmux sessions
- Send keystrokes to simulate user input  
- Execute Vim commands
- Execute Lua code
- Capture screen content (with optional ANSI colors)
- Wait for patterns to appear on screen

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

# Send keys
./nvimrun.sh keys my_session i "Hello World" Escape

# Execute vim command
./nvimrun.sh cmd my_session "w hello.txt"

# Capture screen
./nvimrun.sh screen my_session

# Stop session
./nvimrun.sh stop my_session
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

1. **Escaping**: When using `nvimrun.sh lua`, be careful with quotes and special characters
2. **Timing**: Some operations need time to complete. Use `sleep` or the `wait` command
3. **Clean Config**: nvimrun starts Neovim with `-u NONE` to avoid loading user configs

## Examples

### Create and edit a Python file
```bash
./nvimrun.sh start dev
./nvimrun.sh keys dev i "def main():" Escape o "    print('Hello')" Escape
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
- `nvim_start` - Start a new Neovim session
- `nvim_stop` - Stop a Neovim session
- `nvim_keys` - Send keystrokes
- `nvim_insert` - Insert text at cursor
- `nvim_cmd` - Execute Vim commands
- `nvim_lua` - Execute simple Lua code
- `nvim_lua_file` - Execute complex Lua code (multiline safe)
- `nvim_screen` - Capture screen content
- `nvim_edit` - Open file at specific line
- `nvim_wait` - Wait for pattern on screen

## Troubleshooting

- **Session exists error**: Use `nvimrun.sh stop <session>` first
- **Lua errors**: Check for special characters that need escaping
- **Screen not updating**: Add small delays with `sleep 0.5`