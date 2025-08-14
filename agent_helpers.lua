-- Agent helpers for nvimrun MCP tool
-- This file is loaded before any user run.lua to provide better output handling

-- Store the original print function in case users need it
_G.original_print = print

-- Override print() to avoid "Press ENTER" prompts
_G.print = function(...)
    local args = {...}
    local msg = table.concat(vim.tbl_map(tostring, args), '\t')
    -- Use vim.notify for non-blocking output
    vim.notify(msg, vim.log.levels.INFO)
end

-- Alternative: Override print() to use nvim_echo (shows immediately in command area)
-- _G.print = function(...)
--     local args = {...}
--     local msg = table.concat(vim.tbl_map(tostring, args), '\t')
--     vim.api.nvim_echo({{msg, 'Normal'}}, false, {})
-- end

-- Demonstration that print() no longer causes prompts
print('Agent helpers loaded - print() now uses vim.notify()')

-- Method 2: Use vim.api.nvim_echo() with nowait flag
vim.api.nvim_echo({
    {'Message 1: ', 'Normal'},
    {'This uses nvim_echo\n', 'String'},
    {'Message 2: ', 'Normal'},
    {'Multiple lines without prompts!\n', 'Comment'},
    {'Message 3: ', 'Normal'},
    {'Works great for agent output', 'Type'}
}, false, {})

-- Method 3: Create a helper function for agent output
function agent_print(...)
    local args = {...}
    local msg = table.concat(vim.tbl_map(tostring, args), ' ')
    -- Use vim.notify for async non-blocking output
    vim.notify(msg, vim.log.levels.INFO)
end

-- Method 4: Batch messages and show all at once
local messages = {}
function batch_print(msg)
    table.insert(messages, msg)
end

function flush_messages()
    if #messages > 0 then
        vim.api.nvim_echo(
            vim.tbl_map(function(m) return {m .. '\n', 'Normal'} end, messages),
            false, {}
        )
        messages = {}
    end
end

-- Example usage
agent_print('Agent initialized successfully')
batch_print('Processing item 1...')
batch_print('Processing item 2...')
batch_print('Processing item 3...')
flush_messages()  -- Shows all at once without prompts

-- Method 5: Create a dedicated output buffer (best for agents)
function setup_agent_output()
    -- Create a new buffer for agent output
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_name(buf, 'Agent Output')
    
    -- Split window and show the buffer
    vim.cmd('split')
    vim.api.nvim_win_set_buf(0, buf)
    vim.cmd('resize 10')  -- Set output window to 10 lines
    
    -- Create output function that writes to buffer
    _G.agent_output = function(...)
        local args = {...}
        local msg = table.concat(vim.tbl_map(tostring, args), ' ')
        local lines = vim.split(msg, '\n')
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
        -- Auto-scroll to bottom
        local win = vim.fn.bufwinid(buf)
        if win ~= -1 then
            vim.api.nvim_win_set_cursor(win, {vim.api.nvim_buf_line_count(buf), 0})
        end
    end
    
    return buf
end

-- Example: Set up the output buffer (uncomment to use)
-- setup_agent_output()
-- agent_output('This goes to the dedicated buffer!')
-- agent_output('No "Press ENTER" prompts needed!')
-- for i = 1, 20 do
--     agent_output('Line ' .. i .. ': Processing...')
-- end
