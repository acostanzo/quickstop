---
name: muxy
description: Tmux session orchestration skill. Use when you need to 'manage tmux sessions', 'create terminal layouts', 'run commands in panes', 'read pane output', 'work with multiple terminals', or when starting development environments.
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
version: 1.0.0
---

# Muxy - Tmux Session Orchestration

You are an expert at managing tmux sessions, windows, and panes. You can help users create, manage, and interact with complex terminal environments.

## Capabilities

### Session Management
- Create new tmux sessions from templates
- Attach to existing sessions
- Kill sessions safely
- List and navigate sessions

### Template System
- Create reusable session templates
- Templates support variables: `{{worktree:branch}}`, `{{project_name}}`, `{{date}}`
- Templates stored at `~/.config/claude-code/muxy/templates/`

### Pane Operations
- Run commands in specific panes
- Read and capture pane output
- Navigate session → window → pane hierarchy

### Worktree Integration
- Resolve `{{worktree:branch-name}}` to actual paths
- Integrates with Arborist plugin for worktree management

## Available Commands

- `/muxy:doctor` - Check tmux and environment setup
- `/muxy:template-list` - List available templates
- `/muxy:template-create [name]` - Create new template
- `/muxy:template-edit [name]` - Edit existing template
- `/muxy:template-delete [name]` - Delete template
- `/muxy:session [template]` - Start or attach to session
- `/muxy:kill [session]` - Kill a session
- `/muxy:pane-run [command]` - Run command in pane
- `/muxy:pane-read` - Read pane output

## Tmux Command Reference

### Sessions
```bash
# List sessions
tmux list-sessions -F "#{session_name}"

# Create session
tmux new-session -d -s "name" -n "window" -c "/path"

# Kill session
tmux kill-session -t "name"

# Check if session exists
tmux has-session -t "name" 2>/dev/null
```

### Windows
```bash
# List windows
tmux list-windows -t "session" -F "#{window_index}:#{window_name}"

# Create window
tmux new-window -t "session" -n "name" -c "/path"

# Select window
tmux select-window -t "session:index"
```

### Panes
```bash
# List panes
tmux list-panes -t "session:window" -F "#{pane_index}|#{pane_current_command}"

# Split pane
tmux split-window -t "session:window" -h  # horizontal
tmux split-window -t "session:window" -v  # vertical

# Send keys to pane
tmux send-keys -t "session:window.pane" "command" Enter

# Capture pane output
tmux capture-pane -t "session:window.pane" -p -S -100
```

### Layouts
```bash
# Apply layout
tmux select-layout -t "session:window" even-horizontal
```

Available layouts:
- `even-horizontal` - Panes side by side
- `even-vertical` - Panes stacked
- `main-horizontal` - One large pane on top
- `main-vertical` - One large pane on left
- `tiled` - Grid layout

## Template Schema

```json
{
  "name": "template-name",
  "description": "What this template does",
  "version": "1.0",
  "base_directory": "/project/path",
  "session_name": "session-name",
  "windows": [
    {
      "name": "window-name",
      "description": "Window purpose",
      "layout": "main-horizontal",
      "base_directory": "{{worktree:branch}}",
      "panes": [
        {
          "id": "pane-id",
          "command": "npm run dev",
          "split": "horizontal",
          "size": "50%",
          "description": "What this pane does"
        }
      ]
    }
  ]
}
```

## Best Practices

1. **Use descriptive names** - Session/window/pane names should indicate purpose
2. **Leverage templates** - Create templates for common workflows
3. **Use worktree variables** - `{{worktree:branch}}` for multi-branch development
4. **Check before creating** - Use `has-session` to avoid duplicates
5. **Confirm destructive actions** - Always confirm before killing sessions

## When to Suggest Muxy

Suggest using Muxy when users:
- Need to run multiple services simultaneously
- Want to set up development environments
- Work with git worktrees
- Need to monitor multiple processes
- Want reproducible terminal layouts
