# MCP Neovim/Tmux Documentation

MCP (Model Context Protocol) server for controlling Neovim instances in tmux sessions. This tool enables AI assistants to interact with Neovim, record sessions, and analyze user interactions.

## Table of Contents

1. [Features](#features)
2. [Installation](#installation)
3. [Available Commands](#available-commands)
4. [Environment Variables](#environment-variables)
5. [Usage Examples](#usage-examples)
6. [Recording and Analysis](#recording-and-analysis)
7. [Troubleshooting](#troubleshooting)

## Features

- **Remote Neovim Control**: Start, stop, and interact with Neovim instances in tmux sessions
- **Keystroke Simulation**: Send keystrokes and commands to Neovim
- **Screen Capture**: Capture current Neovim screen content with optional ANSI colors
- **Session Recording**: Record Neovim sessions using asciinema with input capture
- **AI-Powered Analysis**: Analyze recordings using configurable AI models
- **Flexible Configuration**: Support for multiple AI backends through environment variables

## Installation

### Using Nix Flakes

```bash
# Clone the repository
git clone https://github.com/aetherall/mcp-nvim-tmux.git
cd mcp-nvim-tmux

# Install using nix
nix profile install .

# Or run directly
nix run .
```

### Manual Installation

```bash
# Install dependencies
npm install

# Run the MCP server
npm start
```

### Required Dependencies

- Node.js 20+
- tmux
- Neovim
- asciinema
- jq (for JSON parsing)
- ollama or other AI tool (optional, for analysis)

## Available Commands

### nvim_start

Start a new Neovim session in a tmux session.

**Parameters:**
- `session` (optional): Session name (default: auto-generated)
- `width` (optional): Terminal width (default: 80)
- `height` (optional): Terminal height (default: 24)
- `record` (optional): Enable asciinema recording (default: false)

**Example:**
```javascript
{
  "name": "nvim_start",
  "arguments": {
    "session": "my_session",
    "width": 120,
    "height": 40,
    "record": true
  }
}
```

### nvim_stop

Stop a Neovim session.

**Parameters:**
- `session`: Session name to stop

**Example:**
```javascript
{
  "name": "nvim_stop",
  "arguments": {
    "session": "my_session"
  }
}
```

### nvim_keys

Send keystrokes to Neovim. Use this for special keys, navigation, and vim commands.

**Parameters:**
- `session`: Target session name
- `keys`: Array of keys to send

**Special Key Notation:**
- `Enter` - Return/Enter key
- `Tab` - Tab key
- `Space` - Space key (useful between other keys)
- `Escape` or `Esc` - Escape key
- `BSpace` or `BS` - Backspace
- `Delete` or `Del` - Delete key
- `Up`, `Down`, `Left`, `Right` - Arrow keys
- `Home`, `End` - Home/End keys
- `PageUp`, `PageDown` - Page navigation
- `C-x` - Ctrl+x (e.g., `C-w` for Ctrl+w)
- `M-x` - Alt+x (e.g., `M-a` for Alt+a)
- `F1` through `F12` - Function keys

**Examples:**

Basic text entry (not recommended - use nvim_type instead):
```javascript
{
  "name": "nvim_keys",
  "arguments": {
    "session": "my_session",
    "keys": ["i", "Hello", "Space", "World", "Escape"]
  }
}
```

Navigation and editing:
```javascript
// Delete current line
{
  "name": "nvim_keys",
  "arguments": {
    "session": "my_session",
    "keys": ["d", "d"]
  }
}

// Navigate windows
{
  "name": "nvim_keys",
  "arguments": {
    "session": "my_session",
    "keys": ["C-w", "l"]  // Move to right window
  }
}

// Search
{
  "name": "nvim_keys",
  "arguments": {
    "session": "my_session",
    "keys": ["/", "pattern", "Enter"]
  }
}

// Save and quit
{
  "name": "nvim_keys",
  "arguments": {
    "session": "my_session",
    "keys": ["Escape", ":", "w", "q", "Enter"]
  }
}
```

### nvim_cmd

Execute a Vim command.

**Parameters:**
- `session`: Target session name
- `command`: Vim command to execute

**Example:**
```javascript
{
  "name": "nvim_cmd",
  "arguments": {
    "session": "my_session",
    "command": "w test.txt"
  }
}
```

### nvim_lua

Execute Lua code in Neovim.

**Parameters:**
- `session`: Target session name
- `code`: Lua code to execute

**Example:**
```javascript
{
  "name": "nvim_lua",
  "arguments": {
    "session": "my_session",
    "code": "vim.api.nvim_buf_set_lines(0, 0, -1, false, {'Hello from Lua'})"
  }
}
```

### nvim_lua_file

Execute multiline Lua code (avoids escaping issues).

**Parameters:**
- `session`: Target session name
- `code`: Multiline Lua code

**Example:**
```javascript
{
  "name": "nvim_lua_file",
  "arguments": {
    "session": "my_session",
    "code": "local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)\nfor i, line in ipairs(lines) do\n  print(i, line)\nend"
  }
}
```

### nvim_screen

Capture the current screen content.

**Parameters:**
- `session`: Target session name
- `color` (optional): Include ANSI color codes (default: false)

**Example:**
```javascript
{
  "name": "nvim_screen",
  "arguments": {
    "session": "my_session",
    "color": true
  }
}
```

### nvim_wait

Wait for a pattern to appear on screen.

**Parameters:**
- `session`: Target session name
- `pattern`: Pattern to wait for
- `timeout` (optional): Timeout in seconds (default: 5)

**Example:**
```javascript
{
  "name": "nvim_wait",
  "arguments": {
    "session": "my_session",
    "pattern": "-- INSERT --",
    "timeout": 10
  }
}
```

### nvim_edit

Open a file at a specific line.

**Parameters:**
- `session`: Target session name
- `file`: File path to open
- `line` (optional): Line number to jump to

**Example:**
```javascript
{
  "name": "nvim_edit",
  "arguments": {
    "session": "my_session",
    "file": "/path/to/file.txt",
    "line": 42
  }
}
```

### nvim_type

Type literal text without any special key interpretation. Perfect for inserting code, URLs, or any text with special characters.

**Parameters:**
- `session`: Target session name
- `text`: Text to type literally

**Key Features:**
- All characters are typed exactly as provided
- No shell expansion ($HOME stays as $HOME)
- Special characters work perfectly: !, @, #, $, %, ^, &, *, (), {}, [], |, \, `, ~
- Quotes don't need escaping: "double" and 'single' work as-is
- Newlines in the text create actual new lines
- Tabs create actual indentation

**Examples:**

Insert code with special characters:
```javascript
{
  "name": "nvim_type",
  "arguments": {
    "session": "my_session",
    "text": "echo \"Hello $USER!\" && echo 'Path: $HOME' | grep -E '^Path:'"
  }
}
```

Multi-line text with indentation:
```javascript
{
  "name": "nvim_type",
  "arguments": {
    "session": "my_session",
    "text": "function example() {\n\tconst value = \"test\";\n\treturn value !== null;\n}"
  }
}
```

Complex shell command:
```javascript
{
  "name": "nvim_type",
  "arguments": {
    "session": "my_session",
    "text": "docker run -it --rm -v $(pwd):/app -e NODE_ENV=production node:latest"
  }
}
```

URL with special characters:
```javascript
{
  "name": "nvim_type",
  "arguments": {
    "session": "my_session",
    "text": "https://example.com/search?q=vim+tips&filter=recent#results"
  }
}
```

### nvim_recordings

List available asciinema recordings.

**Parameters:** None

**Example:**
```javascript
{
  "name": "nvim_recordings",
  "arguments": {}
}
```

### nvim_play

Play an asciinema recording.

**Parameters:**
- `pattern`: Recording file name or pattern to match

**Example:**
```javascript
{
  "name": "nvim_play",
  "arguments": {
    "pattern": "test_session"
  }
}
```

### nvim_cat

Display recording in AI-readable format with input/output timeline.

**Parameters:**
- `pattern`: Recording file name or pattern to match

**Example:**
```javascript
{
  "name": "nvim_cat",
  "arguments": {
    "pattern": "test_session"
  }
}
```

### nvim_analyze

Analyze a recording using AI to explain what happened.

**Parameters:**
- `pattern`: Recording file name or pattern to match
- `summarize` (optional): Provide brief summary instead of detailed analysis (default: false)

**Example:**
```javascript
{
  "name": "nvim_analyze",
  "arguments": {
    "pattern": "test_session",
    "summarize": true
  }
}
```

## Environment Variables

### MCP_NVIM_TMUX_CMD

Command template for AI analysis. Default: `ollama run $MODEL`

The template can include `$MODEL` which will be replaced with the appropriate model.

**Examples:**
```bash
# Use Google's Gemini
export MCP_NVIM_TMUX_CMD='gemini --model $MODEL analyze'

# Use OpenAI's GPT
export MCP_NVIM_TMUX_CMD='openai complete --model $MODEL'

# Use a custom script
export MCP_NVIM_TMUX_CMD='my-ai-script --model $MODEL --prompt'
```

### MCP_NVIM_TMUX_MODEL

Default model for all AI operations. Used when specific models aren't set.

**Example:**
```bash
export MCP_NVIM_TMUX_MODEL='llama3.2'
```

### MCP_NVIM_TMUX_ANALYZE_MODEL

Model specifically for analysis operations.

**Example:**
```bash
export MCP_NVIM_TMUX_ANALYZE_MODEL='qwen3:8b'
```

### MCP_NVIM_TMUX_SUMMARIZE_MODEL

Model specifically for summarization operations.

**Example:**
```bash
export MCP_NVIM_TMUX_SUMMARIZE_MODEL='llama3.2:1b'
```

### NVIMRUN_PROMPTS_DIR

Directory containing prompt templates (default: `./prompts`).

**Example:**
```bash
export NVIMRUN_PROMPTS_DIR='/path/to/custom/prompts'
```

## Usage Examples

### Basic Text Editing

```javascript
// Start a session
await mcp.call("nvim_start", { session: "edit_session" });

// Open a file
await mcp.call("nvim_edit", { session: "edit_session", file: "hello.txt" });

// Insert some text
await mcp.call("nvim_keys", { 
  session: "edit_session", 
  keys: ["i", "Hello, World!", "Escape"] 
});

// Save the file
await mcp.call("nvim_cmd", { session: "edit_session", command: "w" });

// Stop the session
await mcp.call("nvim_stop", { session: "edit_session" });
```

### Recording and Analysis

```javascript
// Start a recording session
await mcp.call("nvim_start", { 
  session: "demo", 
  record: true 
});

// Perform some actions
await mcp.call("nvim_keys", { 
  session: "demo", 
  keys: ["i", "Testing recording", "Escape", ":w test.txt", "Enter"] 
});

// Stop the session
await mcp.call("nvim_stop", { session: "demo" });

// List recordings
const recordings = await mcp.call("nvim_recordings", {});

// Analyze the recording
const analysis = await mcp.call("nvim_analyze", { 
  pattern: "demo",
  summarize: false 
});

// Get a summary
const summary = await mcp.call("nvim_analyze", { 
  pattern: "demo",
  summarize: true 
});
```

### Advanced Lua Scripting

```javascript
// Execute complex Lua code
await mcp.call("nvim_lua_file", {
  session: "lua_session",
  code: `
    -- Create a new buffer
    local buf = vim.api.nvim_create_buf(false, true)
    
    -- Set some content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      'Line 1',
      'Line 2',
      'Line 3'
    })
    
    -- Set buffer in current window
    vim.api.nvim_win_set_buf(0, buf)
  `
});
```

## Recording and Analysis

### Recording Sessions

Sessions are recorded using asciinema when the `record` flag is set. Recordings capture:
- Terminal output (what appears on screen)
- User input (keystrokes and commands)
- Timing information
- Terminal dimensions

Recordings are stored in `~/.nvimrun/recordings/`.

### Analyzing Recordings

The analyze feature uses AI to explain what happened in a recording:

1. **Detailed Analysis**: Provides step-by-step breakdown of user actions
2. **Summary Mode**: Gives a concise 3-5 sentence summary

The analysis covers:
- Initial Neovim state
- User inputs and their purpose
- Mode changes (Normal/Insert/Visual/Command)
- Errors or unexpected behavior
- Whether the user achieved their goal

### Custom AI Models

You can use different models for different tasks:

```bash
# High-quality model for analysis
export MCP_NVIM_TMUX_ANALYZE_MODEL='qwen3:8b'

# Fast model for summaries
export MCP_NVIM_TMUX_SUMMARIZE_MODEL='llama3.2:1b'

# Run analysis with custom models
./nvimrun.sh analyze session_name summarize
```

## Troubleshooting

### Common Issues

#### 1. Session Already Exists

**Error:** "Session 'name' already exists"

**Solution:** Stop the existing session first:
```javascript
await mcp.call("nvim_stop", { session: "name" });
```

#### 2. Pattern Not Found

**Error:** "Pattern not found within X seconds"

**Solution:** Increase the timeout or check the pattern:
```javascript
await mcp.call("nvim_wait", { 
  session: "name", 
  pattern: "INSERT", 
  timeout: 10 
});
```

#### 3. Recording Not Found

**Error:** "No recording matching 'pattern' found"

**Solution:** List available recordings:
```javascript
const recordings = await mcp.call("nvim_recordings", {});
```

#### 4. AI Analysis Fails

**Error:** "Analysis failed"

**Solution:** Check if AI tool is installed and accessible:
```bash
# Check ollama
which ollama
ollama list

# Set custom command if needed
export MCP_NVIM_TMUX_CMD='your-ai-tool $MODEL'
```

### Debug Mode

Enable debug output by running commands directly:

```bash
# Test nvimrun directly
./nvimrun.sh start test_session
./nvimrun.sh screen test_session
./nvimrun.sh stop test_session

# Test with verbose output
MCP_DEBUG=1 npm start
```

### Path Issues

If tools aren't found in the MCP environment, ensure they're in your PATH before starting the MCP server:

```bash
# Add to PATH if needed
export PATH="$PATH:/path/to/ollama/bin"

# Then start MCP server
npm start
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details.