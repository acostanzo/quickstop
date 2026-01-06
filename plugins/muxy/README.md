# Muxy

Tmux session management with templates and natural language pane interactions.

## Features

- **Template-based Sessions** - Create reusable session layouts with windows, panes, and startup commands
- **Natural Pane Interaction** - Read pane output and run commands using natural language
- **Session Management** - Create, list, inspect, and destroy tmux sessions
- **Doctor Command** - Verify tmux and MCP server setup

## Requirements

- **tmux** 2.1+ installed
- **Node.js** (for npx/tmux-mcp)
- **tmux-mcp** server (auto-installed via npx)

## Installation

Add to your Claude Code plugins:

```bash
claude --plugin-dir /path/to/muxy
```

## Configuration

### Shell Configuration

Muxy uses tmux-mcp which needs to know your shell for proper command exit status handling. Set it via environment variable:

```bash
export MUXY_SHELL=fish
```

Add this to your shell profile (`.bashrc`, `.zshrc`, `config.fish`, etc.) to persist it.

**Default**: `fish` (change by setting `MUXY_SHELL`)

### Verify Setup

Run `/muxy:doctor` to verify your setup is complete.

## Usage

### Session Commands

| Command | Description |
|---------|-------------|
| `/muxy:session [template]` | Create session from template or custom |
| `/muxy:list-sessions` | List all active sessions |
| `/muxy:read-session [name]` | Show session layout and processes |
| `/muxy:kill [name]` | Destroy session with confirmation |

### Template Commands

| Command | Description |
|---------|-------------|
| `/muxy:template-create` | Interactively create a new template |
| `/muxy:template-list` | List all available templates |
| `/muxy:template-edit [name]` | Modify an existing template |
| `/muxy:template-delete [name]` | Remove a template |

### Natural Language Pane Interaction

Through the muxy skill, you can interact with panes naturally:

- "What's happening in the server pane?"
- "Read the output from pane 2"
- "Run `npm test` in the test window"
- "Restart the server in the main pane"
- "Clear the logs pane"

## Templates

Templates are stored in `~/.config/muxy/templates/` as YAML files.

### Example Template

```yaml
name: dev
description: Standard development setup
windows:
  - name: editor
    panes:
      - path: ~/project
        command: $EDITOR .
  - name: server
    layout: even-horizontal
    panes:
      - path: ~/project
        command: npm run dev
      - path: ~/project
        command: tail -f logs/app.log
  - name: shell
    panes:
      - path: ~/project
```

### Layout Options

- `even-horizontal` - Panes side by side
- `even-vertical` - Panes stacked
- `main-horizontal` - Large pane on top
- `main-vertical` - Large pane on left
- `tiled` - Grid arrangement

## Session Naming

Sessions created from templates are named: `SessionName (TemplateName)`

Example: Creating a "Feature-X" session from the "dev" template creates `Feature-X (dev)`.

## Components

| Component | Purpose |
|-----------|---------|
| `skills/muxy/` | Tmux expertise and pane interactions |
| `commands/` | Session and template management (9 commands) |
| `.mcp.json` | tmux-mcp server configuration |

## Version

2.0.0 - Complete rewrite with template system, MCP integration, and natural pane interaction
