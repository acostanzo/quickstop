---
description: Start or attach to a tmux session from a template
argument-hint: [template-name]
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# Muxy Session Command

Start a new tmux session from a template, or attach to an existing session.

## Parameters

**Arguments**: `$ARGUMENTS`

- Optional template name
- If not provided, will list templates and ask user to choose

## Your Task

### Step 1: Select Template

If `$ARGUMENTS` contains a template name:
- Look for `~/.config/claude-code/muxy/templates/{name}.json`
- If not found, show error and list available templates

If no name provided:
- List all templates from `~/.config/claude-code/muxy/templates/*.json`
- Use AskUserQuestion to let user select one

### Step 2: Load and Parse Template

Read the template JSON file and validate structure:
- Must have `name`, `session_name`, `windows` array
- Each window must have `name` and `panes` array
- Each pane must have at least `id`

### Step 3: Resolve Template Variables

Replace variables in the template:

#### `{{worktree:branch-name}}`
Use the Arborist plugin or directly query git worktrees:
```bash
git worktree list --porcelain
```
Find the worktree matching the branch name and get its path.

If worktree not found:
- List available worktrees
- Use AskUserQuestion: "Worktree 'branch-name' not found. What would you like to do?"
  - Choose different worktree
  - Create worktree with `/arborist:plant`
  - Use current directory
  - Cancel

#### `{{project_name}}`
Extract from current directory: `basename $(pwd)`

#### `{{date}}`
Current date: `date +%Y-%m-%d`

#### `{{timestamp}}`
Unix timestamp: `date +%s`

### Step 4: Check for Existing Sessions

List current tmux sessions:
```bash
tmux list-sessions -F "#{session_name}" 2>/dev/null || echo ""
```

Check if session with the template's `session_name` already exists.

If session exists, use AskUserQuestion:
- "Session '{name}' already exists. What would you like to do?"
  - Attach to existing session
  - Create new session with suffix (e.g., myproject-2)
  - Kill existing and recreate
  - Cancel

### Step 5: Create Session

If creating new session:

#### 5a. Create the session with first window
```bash
tmux new-session -d -s "{session_name}" -n "{first_window_name}" -c "{base_directory}"
```

#### 5b. Create panes in first window
For each additional pane in first window:
```bash
# Split pane
tmux split-window -t "{session_name}:{window_name}" -{h|v} -p {size_percent} -c "{pane_directory}"

# Run command if specified
tmux send-keys -t "{session_name}:{window_name}.{pane_index}" "{command}" Enter
```

Split direction:
- `-h` for horizontal split (panes side by side)
- `-v` for vertical split (panes stacked)

#### 5c. Apply layout to first window
```bash
tmux select-layout -t "{session_name}:{window_name}" {layout}
```

#### 5d. Create additional windows
For each additional window:
```bash
# Create window
tmux new-window -t "{session_name}" -n "{window_name}" -c "{window_directory}"

# Create panes (same as 5b)
# Apply layout (same as 5c)
```

#### 5e. Run commands in panes
For each pane with a command:
```bash
tmux send-keys -t "{session_name}:{window_name}.{pane_index}" "{command}" Enter
```

#### 5f. Select first window
```bash
tmux select-window -t "{session_name}:0"
```

### Step 6: Report Results

Show what was created:

```
Session Created: myproject-dev
═══════════════════════════════

Windows:
  1. servers (3 panes)
     ├─ web: npm run dev
     ├─ api: npm run api
     └─ worker: npm run workers

  2. backend (1 pane)
     └─ Directory: /Users/dev/projects/myproject-backend

  3. frontend (1 pane)
     └─ Directory: /Users/dev/projects/myproject-frontend

  4. claude (1 pane)
     └─ claude (running)

Attach to this session with:
  tmux attach-session -t myproject-dev

Or from another tmux session:
  tmux switch-client -t myproject-dev
```

### Step 7: Offer to Attach

Ask: "Would you like me to provide the attach command?"

Note: Claude cannot directly attach to a tmux session (that requires terminal control).
Provide the command for the user to run in their terminal.

## Error Handling

### tmux not running
```bash
tmux list-sessions 2>&1
```
If error contains "no server running":
- Explain tmux server isn't running
- The `new-session` command will start it automatically

### Permission errors
- Show the specific error
- Suggest checking tmux socket permissions

### Invalid template
- Show validation errors
- Suggest using `/muxy:template-edit` to fix

### Worktree resolution failures
- List available worktrees
- Offer alternatives

## MCP Server Alternative

If tmux MCP tools are available (check for `mcp__tmux__*` or similar):
- Use MCP tools instead of direct bash commands
- MCP provides: list_sessions, create_session, create_window, split_pane, send_keys

Prefer MCP when available as it may provide better error handling and cross-platform support.
