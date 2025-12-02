---
description: Run a command in a specific tmux pane
argument-hint: [command]
allowed-tools: Bash, Read, AskUserQuestion
---

# Muxy Pane Run Command

Execute a command in a specific tmux pane using interactive selection.

## Parameters

**Arguments**: `$ARGUMENTS`

- Optional command to run
- If not provided, will ask for command after pane selection

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
- Display sessions:
```
Select Session
══════════════

  1. myproject-dev
  2. quickstart
  3. testing
```
- Use AskUserQuestion to let user choose

### Step 3: List Windows in Session

```bash
tmux list-windows -t "{session_name}" -F "#{window_index}:#{window_name}:#{window_panes}"
```

Display windows:
```
Session: myproject-dev
Windows:
══════════════════════

  0. servers (3 panes)
  1. backend (1 pane)
  2. frontend (1 pane)
  3. claude (1 pane)
```

If only one window, use it automatically.
Otherwise, use AskUserQuestion to let user choose.

### Step 4: List Panes in Window

```bash
tmux list-panes -t "{session_name}:{window_index}" -F "#{pane_index}|#{pane_current_command}|#{pane_current_path}|#{pane_width}x#{pane_height}"
```

For each pane, also capture a preview of recent output:
```bash
tmux capture-pane -t "{session_name}:{window_index}.{pane_index}" -p -S -5 | tail -3
```

Display panes with context:
```
Window: servers
Panes:
═══════════════

  0. [npm] ~/projects/myproject (80x20)
     > Server running on http://localhost:3000
     > Compiled successfully

  1. [npm] ~/projects/myproject/api (80x20)
     > API server started on port 4000
     > Connected to database

  2. [node] ~/projects/myproject (80x10)
     > Worker: Processing jobs...
```

Use AskUserQuestion to let user choose a pane.

### Step 5: Get Command

If `$ARGUMENTS` contains a command, use it.

Otherwise, ask:
- "What command would you like to run in this pane?"
- Let user type the command

### Step 6: Execute Command

Send keys to the pane:
```bash
tmux send-keys -t "{session_name}:{window_index}.{pane_index}" "{command}" Enter
```

### Step 7: Report and Follow-up

```
✓ Command sent to myproject-dev:servers.0

Command: npm run build
Target: servers pane 0 (npm)

The command is now running in the pane.

Would you like to:
  - Read the pane output: /muxy:pane-read
  - Run another command in the same pane
  - Run a command in a different pane
```

Use AskUserQuestion with these options.

## Error Handling

### Session doesn't exist
- Show error
- List available sessions

### Window doesn't exist
- Show error
- List windows in selected session

### Pane doesn't exist
- Show error
- List panes in selected window

### send-keys fails
- Show tmux error
- Suggest checking if the pane is still active

## Tips for Users

Include these tips when displaying pane selection:

```
Tip: Pane coordinates are {session}:{window}.{pane}
     e.g., myproject-dev:servers.0

The current command shows what's running in each pane.
The path shows the pane's working directory.
```

## MCP Alternative

If tmux MCP tools are available, use:
- `list_sessions` instead of `tmux list-sessions`
- `list_windows` instead of `tmux list-windows`
- `list_panes` instead of `tmux list-panes`
- `send_keys` instead of `tmux send-keys`
