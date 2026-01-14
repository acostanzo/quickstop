# Muxy v3

Natural language tmux session management for Claude Code.

## Overview

Muxy lets you describe tmux sessions in plain English. Just tell Claude what you want:

> "Create a tmux session for my rails project with three windows: one for the server, one split horizontally for console and shell, and one for my editor"

Claude shows you a preview, you confirm, and it's created.

## Features

- **Natural language session creation** - Describe layouts in your own words
- **Visual preview before creation** - See exactly what will be built
- **Template system** - Save and reuse session layouts
- **Smart variable inference** - Automatically detects project directories
- **Auto-detected shell** - Works with fish, zsh, bash, etc.

## Quick Start

### Create a Session

Just describe what you want:

```
New tmux session named "My Project"
- Window 1: Server, run `npm start`
- Window 2: Two vertical panes for coding
- Window 3: Horizontal split with claude and shell
```

Claude presents a preview table, you say "looks good", and it's created.

### Use a Template

```
New tmux for rails
```

Claude loads the template, infers your project directory, shows the preview, and creates on confirmation.

### Save as Template

After confirming a session:

```
Save this as a template called "fullstack"
```

### Basic Operations

These work naturally without previews:

- "List my tmux sessions"
- "Kill the dev session"
- "What's running in the server pane?"

## Commands

| Command | Description |
|---------|-------------|
| `/muxy:doctor` | Verify setup and dependencies |
| `/muxy:templates` | List available templates |

## Templates

Templates are YAML files stored in `~/.config/muxy/templates/`.

### Format

```yaml
name: rails
description: Standard Rails development
variables:
  project_dir: "Rails project root"
windows:
  - name: Server
    panes:
      - path: ${project_dir}
        command: bin/rails server
  - name: Console
    layout: horizontal
    panes:
      - path: ${project_dir}
        command: rails c
      - path: ${project_dir}
```

### Variables

Templates support variables that are inferred automatically:

| Variable | Inference |
|----------|-----------|
| `${project_dir}` | Current working directory or detected from prompt |
| `${notes_dir}` | `~/notes` if exists |

Unknown variables prompt for values.

## Requirements

- tmux installed
- Node.js/npx for tmux-mcp server
- Claude Code with MCP support

## Shell Detection

Muxy automatically detects the shell you launched Claude from (fish, zsh, bash, etc.) and configures tmux-mcp accordingly. No manual configuration needed.

If detection fails, it defaults to bash. You can override by setting `MUXY_SHELL` environment variable.

## Troubleshooting

Run `/muxy:doctor` to diagnose issues:

```
✓ tmux: v3.4
✓ npx: 10.2.0
✓ tmux-mcp: Connected
✓ Shell: fish
✓ Templates: ~/.config/muxy/templates/
```

### Common Issues

**MCP not connected:** Restart your Claude Code session.

**Shell not detected:** Set `MUXY_SHELL` environment variable to your shell (fish, zsh, bash).

**Templates directory missing:** Run `mkdir -p ~/.config/muxy/templates`

## Version History

### v3.0.0

Complete rewrite focused on simplicity:
- Natural language session creation with preview workflow
- Template system with variable inference
- Auto-detected shell (no more MUXY_SHELL configuration)
- Reduced from 9 commands to 2

### v2.0.0

- YAML-based templates
- Natural language pane interactions
- 9 specialized commands

### v1.0.0

- Initial release
