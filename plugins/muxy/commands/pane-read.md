---
description: Read output from a specific tmux pane
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# Muxy Pane Read Command

Capture and display the output from a specific tmux pane using interactive selection.

## Your Task

### Step 1: List Sessions

Get all current tmux sessions:
```bash
tmux list-sessions -F "#{session_name}" 2>/dev/null
```

If no sessions exist:
```
No tmux sessions found.

Start a session with:
  /muxy:session <template-name>
```
Exit early.

### Step 2: Select Session

If only one session exists, use it automatically and mention it.

If multiple sessions:
- Display sessions
- Use AskUserQuestion to let user choose

### Step 3: List Windows in Session

```bash
tmux list-windows -t "{session_name}" -F "#{window_index}:#{window_name}:#{window_panes}"
```

Display windows with pane counts.

If only one window, use it automatically.
Otherwise, use AskUserQuestion to let user choose.

### Step 4: List Panes in Window

```bash
tmux list-panes -t "{session_name}:{window_index}" -F "#{pane_index}|#{pane_current_command}|#{pane_current_path}|#{pane_width}x#{pane_height}"
```

Display panes with current command and path info.
Use AskUserQuestion to let user choose a pane.

### Step 5: Capture Pane Content

Capture the pane's scrollback buffer:
```bash
# Capture last 100 lines (or full history)
tmux capture-pane -t "{session_name}:{window_index}.{pane_index}" -p -S -100
```

Options for capture depth:
- `-S -100` - Last 100 lines
- `-S -` - Entire scrollback history
- `-S -50` - Last 50 lines (for quick preview)

### Step 6: Display Output

Present the captured output in a readable format:

```
Pane Output: myproject-dev:servers.0
══════════════════════════════════════
Command: npm
Path: ~/projects/myproject
Captured: Last 100 lines
──────────────────────────────────────

> myproject@1.0.0 dev
> vite

  VITE v5.0.0  ready in 324 ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: http://192.168.1.100:5173/
  ➜  press h to show help

[15:23:45] Compiled successfully in 1.2s
[15:24:01] File changed: src/App.tsx
[15:24:02] Compiled successfully in 0.3s

──────────────────────────────────────
End of captured output
```

### Step 7: Offer Follow-up Actions

Use AskUserQuestion with options:

1. **Refresh** - Capture again to see new output
2. **Capture more** - Get full scrollback history
3. **Save to file** - Write output to a file
4. **Run command** - Send a command to this pane
5. **Read different pane** - Select another pane
6. **Done** - Exit

### Handle "Save to file"

If user chooses to save:
- Ask for filename (suggest: `pane-output-{timestamp}.txt`)
- Default location: current directory
- Write the captured content to the file
- Confirm: "✓ Output saved to {filename}"

### Handle "Refresh"

Re-run the capture command and display new output.
Highlight any differences if possible (optional enhancement).

### Handle "Capture more"

```bash
tmux capture-pane -t "{session_name}:{window_index}.{pane_index}" -p -S -
```

This captures the entire scrollback buffer.
Warn if output is very large (>1000 lines).

## Error Handling

### Session/Window/Pane not found
- Show error with specific location that failed
- List available options

### Empty pane
If capture returns empty:
```
Pane is empty or has no scrollback.

The pane at myproject-dev:servers.0 has no captured output.
This could mean:
  - The pane just started
  - The command cleared the screen
  - No output has been generated yet

Would you like to:
  - Wait and try again
  - Run a command in this pane
  - Select a different pane
```

### Capture fails
If `capture-pane` returns error:
- Show the tmux error
- Suggest checking if pane still exists

## Output Formatting

When displaying output:
1. Preserve whitespace and formatting
2. Use code block for the actual output
3. Truncate very long outputs (>500 lines) with option to see more
4. Handle ANSI escape codes gracefully (strip or convert)

To strip ANSI codes:
```bash
tmux capture-pane -t "..." -p -S -100 | sed 's/\x1b\[[0-9;]*m//g'
```

## MCP Alternative

If tmux MCP tools are available, use:
- `capture_pane` tool for reading output
- May provide better formatted output
