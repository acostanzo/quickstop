# Muxy Plugin

> Component: Natural language tmux session management

## Purpose

Muxy enables natural language creation of tmux sessions. Users describe their desired terminal layout in plain English, and the skill translates that into tmux commands via an MCP server.

## Version

Current: **3.0.0**

## Architecture

```
muxy/
├── .claude-plugin/
│   └── plugin.json               # Plugin metadata
├── commands/
│   ├── doctor.md                 # Diagnostic command
│   └── templates.md              # List templates command
├── skills/
│   └── muxy/
│       ├── SKILL.md              # Natural language skill definition
│       └── references/
│           └── template-format.md  # Template YAML specification
├── scripts/
│   └── launch-tmux-mcp.sh        # MCP server launcher with shell detection
├── .mcp.json                     # MCP server configuration
└── README.md
```

## Components

### Muxy Skill

**Purpose:** Natural language interface for tmux session creation.

**File:** `/Users/acostanzo/Code/quickstop/plugins/muxy/skills/muxy/SKILL.md`

**Trigger Patterns:**
- "create a tmux session"
- "new tmux"
- "tmux for my project"
- "make a tmux layout"
- "set up tmux windows"
- "save as template"
- "load template"
- "tmux template"

**Workflow:**
1. Parse user description - Extract windows, panes, paths, commands
2. Infer project directories - From prompt, project names, or cwd
3. Present preview table - Markdown table showing planned structure
4. Execute on approval - Create session via MCP tools
5. Offer to save - Optionally save as template

**Preview Table Format:**
```markdown
**Session: [Session Name]**

| Window | Name | Layout | Panes |
|--------|------|--------|-------|
| 1 | Servers | single | `/path/to/project` -> `yarn start` |
| 2 | IDE | vertical | `/path/to/project`, `~/notes` |
```

### MCP Server Configuration

**File:** `/Users/acostanzo/Code/quickstop/plugins/muxy/.mcp.json`

```json
{
  "mcpServers": {
    "tmux": {
      "command": "bash",
      "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/launch-tmux-mcp.sh"]
    }
  }
}
```

### MCP Launcher Script

**File:** `/Users/acostanzo/Code/quickstop/plugins/muxy/scripts/launch-tmux-mcp.sh`

**Functionality:**
1. Detects user's shell by walking process tree
2. Supports: bash, zsh, fish, sh, dash, ksh, tcsh, csh
3. Honors `MUXY_SHELL` environment override
4. Validates prerequisites (npx, tmux)
5. Launches `tmux-mcp` with detected shell type

**Shell Detection Algorithm:**
```bash
# Walk up process tree looking for known shell
ppid=$PPID
for _ in {1..5}; do
    comm=$(ps -o comm= -p "$ppid")
    comm="${comm##*/}"  # Strip path
    comm="${comm#-}"    # Strip login shell dash
    if validate_shell "$comm"; then
        echo "$comm"
        return 0
    fi
    ppid=$(ps -o ppid= -p "$ppid")
done
echo "bash"  # Fallback
```

### MCP Tools Available

| Tool | Purpose |
|------|---------|
| `list-sessions` | List active tmux sessions |
| `create-session` | Create new session (includes first window) |
| `create-window` | Add window to existing session |
| `split-pane` | Split pane vertically or horizontally |
| `execute-command` | Run command in a pane |
| `kill-session` | Terminate a session |
| `capture-pane` | Read content from a pane |
| `send-keys` | Send keystrokes to a pane |

### Template System

**Storage:** `~/.config/muxy/templates/*.yaml`

**Template Format:**
```yaml
name: template-name
description: Brief description
variables:
  project_dir: "Project root directory"
windows:
  - name: Window Name
    layout: horizontal | vertical
    panes:
      - path: ${project_dir}
        command: optional startup command
```

**Variable Inference:**
| Variable | Inference Logic |
|----------|-----------------|
| `${project_dir}` | Project name in prompt or current working directory |
| `${notes_dir}` | `~/notes` if exists, else `~/Documents/notes`, else prompt |

### Commands

**Doctor Command** (`/muxy:doctor`):
- Checks tmux installation
- Verifies npx availability
- Tests MCP server connection
- Reports shell detection
- Validates templates directory

**Templates Command** (`/muxy:templates`):
- Lists available templates
- Shows name, description, window count
- Provides usage instructions

## Data Flow

```
User: "Create a tmux session for my rails project with servers and console"
                    │
                    ▼
            SKILL.md triggers
                    │
                    ▼
            Parse description:
            - Session: rails project
            - Windows: servers, console
                    │
                    ▼
            Infer project_dir from cwd
                    │
                    ▼
            Present preview table
                    │
                    ▼
            User: "looks good"
                    │
                    ▼
            MCP: create-session
            MCP: create-window (for each additional window)
            MCP: split-pane (for multi-pane layouts)
            MCP: execute-command (for startup commands)
                    │
                    ▼
            "Session created. Would you like to save as a template?"
```

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Preview before execute | Never create sessions without user confirmation |
| MCP for tmux operations | Structured tool access is more reliable than raw bash |
| Shell auto-detection | Eliminates configuration; works across environments |
| Skill (not command) | Natural language enables flexible session descriptions |
| YAML templates | Human-readable, easy to edit manually |
| Variable inference | Reduces prompting; smart defaults with transparency |
| Simplified commands (v3) | Reduced from 9 to 2 commands; skill handles most use cases |

## Dependencies

- **tmux** - Terminal multiplexer (required)
- **Node.js/npx** - For running tmux-mcp (required)
- **tmux-mcp** - MCP server for tmux (installed via npx)

---

**Last Updated:** 2025-01-25
