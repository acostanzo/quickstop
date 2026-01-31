# Muxy Plugin

> Version: 3.0.0 | Natural language tmux session management

## Overview

Muxy enables natural language creation of tmux sessions. Instead of memorizing tmux commands and syntax, users describe their desired layout in plain English and Muxy translates it into tmux operations via an MCP server.

## Problem Solved

Creating multi-window tmux sessions requires remembering arcane syntax and executing many commands. Muxy lets you say "create a tmux session with servers, console, and IDE windows" and handles the rest, with a preview step for confirmation.

## Architecture

```
plugins/muxy/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata (v3.0.0)
├── .mcp.json                    # MCP server configuration
├── commands/
│   ├── doctor.md                # Diagnostic command
│   └── templates.md             # Template listing command
├── scripts/
│   └── launch-tmux-mcp.sh       # Shell auto-detection script
└── skills/
    └── muxy/
        ├── SKILL.md             # Core skill definition
        └── references/
            └── template-format.md  # YAML template specification
```

## Key Components

| Component | File | Purpose |
|-----------|------|---------|
| Muxy Skill | `skills/muxy/SKILL.md` | Session creation workflow |
| MCP Launcher | `scripts/launch-tmux-mcp.sh` | Shell detection and MCP startup |
| Doctor Command | `commands/doctor.md` | Diagnostics |
| Templates Command | `commands/templates.md` | List saved templates |

## How It Works

### Core Workflow

1. **Parse user description** - Extract windows, panes, paths, and commands
2. **Infer project directories** - Detect paths from prompt, project names, or cwd
3. **Present preview table** - Show structured plan for confirmation
4. **Execute on approval** - Create session via MCP tools
5. **Offer to save** - Optionally save as template for reuse

### Preview Table Format

Sessions are always previewed before creation:

```markdown
**Session: my-project**

| Window | Name | Layout | Panes |
|--------|------|--------|-------|
| 1 | Servers | single | `/path/to/project` → `yarn start` |
| 2 | IDE | vertical | `/path/to/project`, `~/notes` |
| 3 | Console | horizontal | `/path` → `rails c`, `/path` → `claude` |
```

### Shell Auto-Detection

The launch script (`scripts/launch-tmux-mcp.sh:16-64`) automatically detects the user's shell:

1. Check `MUXY_SHELL` environment variable (explicit override)
2. Walk process tree (up to 5 levels) looking for shell processes
3. Strip path and login shell indicator (`-zsh` → `zsh`)
4. Validate against supported shells: `bash`, `zsh`, `fish`, `sh`, `dash`, `ksh`, `tcsh`, `csh`
5. Fall back to `bash` if detection fails

### MCP Integration

Muxy uses the `tmux-mcp` server via npx. Available tools:

| Tool | Purpose |
|------|---------|
| `list-sessions` | List active tmux sessions |
| `create-session` | Create new session (first window included) |
| `create-window` | Add window to existing session |
| `split-pane` | Split existing pane vertically/horizontally |
| `execute-command` | Run command in a pane |
| `kill-session` | Terminate a session |
| `capture-pane` | Read content from a pane |
| `send-keys` | Send keystrokes to a pane |

### Template System

Templates are YAML files stored in `~/.config/muxy/templates/`:

**Variable support:**
| Variable | Inference Logic |
|----------|-----------------|
| `${project_dir}` | Project name from prompt → search directories, or use cwd |
| `${notes_dir}` | `~/notes` if exists, else `~/Documents/notes`, else ask |

**Operations:**
- **Save**: After confirming a session, save as `~/.config/muxy/templates/{name}.yaml`
- **Load**: Parse YAML, infer variables, show preview with resolved values
- **List**: `/muxy:templates` shows available templates

## Usage Examples

### Natural Language Creation

```
User: Create a tmux session for my rails project with servers, console, and IDE windows

Muxy: Shows preview table → User confirms → Session created
```

### Using Templates

```
User: New tmux for rails

Muxy: Loads rails.yaml template → Infers project_dir → Shows preview → Creates
```

### Basic Operations

```
User: List my sessions
User: Kill the dev session
User: What's running in tmux?
```

## Commands

| Command | Purpose |
|---------|---------|
| `/muxy:doctor` | Verify tmux and npx installation, MCP connectivity |
| `/muxy:templates` | List saved templates from `~/.config/muxy/templates/` |

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Preview before create | Prevents mistakes; users confirm the interpreted layout |
| Shell auto-detection | No configuration needed; works with any shell |
| npx for MCP server | No global installation; always gets latest tmux-mcp |
| YAML templates | Human-readable; easy to edit manually |
| Variable inference | Reduces repetition; templates adapt to context |

## Prerequisites

1. **Node.js** - For npx (tmux-mcp installation)
2. **tmux** - The terminal multiplexer itself

## Code References

- Shell detection: `plugins/muxy/scripts/launch-tmux-mcp.sh:16-64`
- Supported shells: `plugins/muxy/scripts/launch-tmux-mcp.sh:9`
- Core workflow: `plugins/muxy/skills/muxy/SKILL.md:12-18`
- Preview format: `plugins/muxy/skills/muxy/SKILL.md:22-32`
- MCP tools: `plugins/muxy/skills/muxy/SKILL.md:54-68`
