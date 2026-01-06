---
name: Tmux Session Management
description: This skill should be used when the user asks to "read pane output", "check what's in a pane", "run command in pane", "execute in window", "see terminal output", "check the server pane", "restart process in pane", "what's happening in tmux", "manage tmux sessions", "work with multiple terminals", or when starting development environments that benefit from tmux multiplexing.
version: 2.0.0
---

# Tmux Session Management with Muxy

Expert guidance for managing tmux sessions, windows, and panes using the tmux-mcp server tools.

## Core Concepts

### Tmux Hierarchy

```
Session (named container)
├── Window 1 (like a tab)
│   ├── Pane 1 (terminal split)
│   └── Pane 2
├── Window 2
│   └── Pane 1
└── Window 3
    ├── Pane 1
    ├── Pane 2
    └── Pane 3
```

- **Session**: Top-level container, persists across disconnects
- **Window**: Like browser tabs within a session
- **Pane**: Split sections within a window

### Muxy Session Naming Convention

Sessions created from templates use the format: `SessionName (TemplateName)`

Example: `MyFeature (dev-fullstack)` indicates a session named "MyFeature" created from the "dev-fullstack" template.

## Available MCP Tools

The tmux-mcp server provides these tools:

### Session Operations
- `list-sessions` - List all active tmux sessions
- `find-session` - Find a session by name
- `create-session` - Create a new session
- `kill-session` - Terminate a session by ID

### Window Operations
- `list-windows` - List windows in a session
- `create-window` - Add a new window to a session
- `kill-window` - Terminate a window by ID

### Pane Operations
- `list-panes` - List panes in a window
- `split-pane` - Split a pane horizontally or vertically
- `kill-pane` - Terminate a pane by ID
- `capture-pane` - Read content from a pane
- `execute-command` - Run a command in a pane
- `get-command-result` - Get result of executed command

## Reading Pane Output

To read what's displayed in a pane:

1. **Identify the pane**: Use `list-sessions` → `list-windows` → `list-panes` to find the pane ID
2. **Capture content**: Use `capture-pane` with the pane ID

```
# Example workflow
1. list-sessions → find session ID
2. list-windows with session ID → find window ID
3. list-panes with window ID → find pane ID
4. capture-pane with pane ID → get output
```

When the user says "check pane 2" or "read the server pane", navigate the hierarchy to find the correct pane, then capture its content.

## Running Commands in Panes

To execute a command in a specific pane:

1. **Locate the target pane** using the hierarchy navigation above
2. **Execute command**: Use `execute-command` with pane ID and command string
3. **Check result**: Use `get-command-result` to verify execution

Common scenarios:
- "Restart the server" → Find server pane, execute restart command
- "Run tests" → Find test pane or create one, execute test command
- "Clear the logs pane" → Find logs pane, execute `clear`

## Template System

Templates are stored in `~/.config/muxy/templates/` as YAML files.

### Template Structure

```yaml
name: template-name
description: Brief description of the template purpose
windows:
  - name: window-name
    layout: even-horizontal  # optional: even-vertical, main-horizontal, tiled
    panes:
      - path: /starting/directory
        command: optional startup command
      - path: /another/directory
        command: another command
```

### Layout Options

- `even-horizontal` - Panes side by side, equal width
- `even-vertical` - Panes stacked, equal height
- `main-horizontal` - One large pane on top, others below
- `main-vertical` - One large pane on left, others on right
- `tiled` - Grid arrangement

### Creating Sessions from Templates

When creating a session from a template:

1. Parse the template YAML
2. Create the session with `create-session`
3. For each window after the first, use `create-window`
4. For each additional pane in a window, use `split-pane`
5. For each pane with a command, use `execute-command`

Name the session as `UserSessionName (TemplateName)`.

## Common Workflows

### Development Environment

```yaml
name: dev
description: Standard development setup
windows:
  - name: code
    panes:
      - path: ~/project
        command: $EDITOR .
  - name: server
    panes:
      - path: ~/project
        command: npm run dev
  - name: shell
    panes:
      - path: ~/project
```

### Monitoring Setup

```yaml
name: monitor
description: System monitoring layout
windows:
  - name: main
    layout: tiled
    panes:
      - command: htop
      - command: watch -n1 'df -h'
      - command: tail -f /var/log/syslog
      - command: nethogs
```

## Troubleshooting

### "Session not found"

- Verify session name with `list-sessions`
- Check if session was created (tmux may not be running)

### "Pane not responding"

- The process in the pane may be blocking
- Use `capture-pane` to see current state
- Consider sending interrupt signals

### "Command didn't execute"

- Verify pane ID is correct
- Check if pane is ready (not running an interactive program)
- Use `get-command-result` to check status

## Configuration

### Shell Configuration

Set the shell for tmux-mcp via environment variable:

```bash
export MUXY_SHELL=fish
```

Default: `fish`. The shell setting ensures proper command exit status handling in tmux-mcp.

### Template Directory

Templates are stored in `~/.config/muxy/templates/` by default. Each template is a `.yaml` file.
