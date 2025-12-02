---
description: Kill a tmux session
argument-hint: [session-name]
allowed-tools: Bash, Read, AskUserQuestion
---

# Muxy Kill Command

Terminate a tmux session.

## Parameters

**Arguments**: `$ARGUMENTS`

- Optional session name to kill
- If not provided, will list sessions and ask user to choose

## Your Task

### Step 1: List Available Sessions

Get all current tmux sessions:
```bash
tmux list-sessions -F "#{session_name}:#{session_windows} windows,#{session_attached} attached" 2>/dev/null
```

If no sessions exist (command fails or returns empty):
```
No tmux sessions found.

Start a session with:
  /muxy:session <template-name>
```
Exit early.

### Step 2: Select Session

If `$ARGUMENTS` contains a session name:
- Verify it exists in the session list
- If not found, show error and list available sessions

If no name provided:
- Display sessions with details:
```
Active tmux Sessions
════════════════════

  1. myproject-dev (4 windows, attached)
  2. quickstart (1 window)
  3. testing (2 windows)
```
- Use AskUserQuestion to let user select one

### Step 3: Show Session Details

Before killing, show what will be terminated:
```bash
# Get window and pane info
tmux list-windows -t "{session_name}" -F "#{window_name}: #{window_panes} panes"
```

Display:
```
Session to Kill: myproject-dev
═══════════════════════════════

Windows:
  - servers: 3 panes
  - backend: 1 pane
  - frontend: 1 pane
  - claude: 1 pane

Total: 4 windows, 6 panes

⚠️  Any unsaved work in these panes will be lost.
```

### Step 4: Check if Attached

```bash
tmux list-sessions -F "#{session_name}:#{session_attached}" | grep "^{session_name}:"
```

If session is attached (has clients):
```
⚠️  This session is currently attached!
   Killing it will disconnect all clients.
```

### Step 5: Confirm Kill

Use AskUserQuestion with explicit confirmation:
- "Are you sure you want to kill session '{name}'?"
- Options:
  - "Yes, kill it"
  - "No, cancel"

Do not proceed without explicit confirmation.

### Step 6: Kill Session

```bash
tmux kill-session -t "{session_name}"
```

### Step 7: Confirm Result

Verify session is gone:
```bash
tmux has-session -t "{session_name}" 2>/dev/null && echo "exists" || echo "killed"
```

If successful:
```
✓ Session 'myproject-dev' terminated.

Remaining sessions: 2
  - quickstart
  - testing

Start a new session with:
  /muxy:session <template-name>
```

If no sessions remain:
```
✓ Session 'myproject-dev' terminated.

No remaining tmux sessions.

Start a new session with:
  /muxy:session <template-name>
```

## Error Handling

### Session not found
```
Session '{name}' not found.

Available sessions:
  - quickstart
  - testing

Use one of the above, or check with:
  tmux list-sessions
```

### Kill fails
If `kill-session` returns error:
- Show the error message
- Suggest manual intervention: `tmux kill-session -t {name}`
- May need to check permissions or zombie processes

### No tmux server
If tmux server isn't running:
```
No tmux server running.

There are no sessions to kill.
```
