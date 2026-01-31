# Miser Plugin

> Component: Mise polyglot version manager integration

## Purpose

Miser integrates the mise polyglot version manager with Claude Code's non-interactive bash environment. It solves the problem that mise's normal `activate bash` command uses prompt hooks (PROMPT_COMMAND) which never fire in non-interactive shells.

## Version

Current: **1.0.2**

## Architecture

```
miser/
├── .claude-plugin/
│   └── plugin.json           # Plugin metadata
├── commands/
│   └── doctor.md             # Diagnostic command
├── hooks/
│   ├── hooks.json            # SessionStart hook registration
│   └── session-start.sh      # Mise activation script
├── .mcp.json                 # Mise MCP server configuration
└── README.md
```

## Components

### SessionStart Hook

**Purpose:** Activate mise in shims mode when Claude Code session starts.

**File:** `/Users/acostanzo/Code/quickstop/plugins/miser/hooks/session-start.sh`

**The Problem:**
Claude Code runs non-interactive bash. Normal mise activation (`mise activate bash`) uses `PROMPT_COMMAND` which only executes when displaying the prompt. In non-interactive mode, the prompt never displays, so mise never activates.

**The Solution:**
Use mise's shims mode, which simply prepends `~/.local/share/mise/shims` to PATH. This works in any bash context.

**Implementation:**
```bash
# Activate mise in SHIMS mode (required for non-interactive bash)
eval "$("$MISE_BIN" activate bash --shims)"

# Capture environment changes
comm -13 <(echo "$ENV_BEFORE") <(echo "$ENV_AFTER") >> "$CLAUDE_ENV_FILE"
```

**Key Details:**
1. Finds mise binary (checks common locations)
2. Captures environment before activation
3. Activates mise with `--shims` flag
4. Captures environment after activation
5. Writes diff to `CLAUDE_ENV_FILE` for persistence
6. Environment persists across bash commands in session

### MCP Server Configuration

**File:** `/Users/acostanzo/Code/quickstop/plugins/miser/.mcp.json`

```json
{
  "mcpServers": {
    "mise": {
      "command": "bash",
      "args": [
        "-c",
        "for p in \"$HOME/.local/bin/mise\" /opt/homebrew/bin/mise /usr/local/bin/mise; do [ -x \"$p\" ] && exec \"$p\" mcp; done; echo 'mise not found' >&2; exit 1"
      ],
      "env": {
        "MISE_EXPERIMENTAL": "1"
      }
    }
  }
}
```

**Note:** Mise MCP requires experimental features flag (`MISE_EXPERIMENTAL=1`).

### Doctor Command

**Purpose:** Diagnose mise integration and verify tool availability.

**File:** `/Users/acostanzo/Code/quickstop/plugins/miser/commands/doctor.md`

**Checks:**
1. mise installation (`which mise`, `mise --version`)
2. Shims directory exists and is in PATH
3. Current tool versions (`mise current`)
4. Configuration files present (`.mise.toml`, `.tool-versions`)
5. Tool verification (run version commands for each active tool)
6. MCP server connection (check mise resources available)

**Allowed Tools:** Bash, Read, ListMcpResourcesTool, ReadMcpResourceTool

### Hook Registration

**File:** `/Users/acostanzo/Code/quickstop/plugins/miser/hooks/hooks.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

## Data Flow

```
Claude Code Session Start
         │
         ▼
    SessionStart hook
         │
         ▼
    session-start.sh
         │
         ├── CLAUDE_ENV_FILE not set? → Exit silently
         │
         ├── Find mise binary:
         │   - ~/.local/bin/mise
         │   - /usr/local/bin/mise
         │   - /opt/homebrew/bin/mise
         │
         ├── mise not found? → Exit silently
         │
         ├── Capture ENV_BEFORE
         │
         ├── eval "$(mise activate bash --shims)"
         │
         ├── Capture ENV_AFTER
         │
         ├── Write diff to CLAUDE_ENV_FILE
         │
         └── Output: "mise activated (shims mode)"

Subsequent Bash Commands
         │
         ├── CLAUDE_ENV_FILE sourced automatically
         │
         └── Tools available via shims PATH
```

## MCP Resources

When connected, mise MCP provides:

| Resource | Description |
|----------|-------------|
| `mise://tools` | List of installed tools |
| `mise://env` | Environment variables set by mise |
| `mise://tasks` | Available mise tasks |
| `mise://config` | Current mise configuration |

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Shims mode activation | Only reliable method for non-interactive bash |
| Silent failure | User may not have mise installed; don't interrupt |
| Environment file persistence | Ensures tools available across bash invocations |
| Multiple binary locations | Supports homebrew, manual install, and standard paths |
| Experimental flag for MCP | Required for mise's built-in MCP server |

## Requirements

- **mise** - Polyglot version manager ([mise.jdx.dev](https://mise.jdx.dev/))
- **MISE_EXPERIMENTAL=1** - For MCP server functionality
- **Tools installed via mise** - e.g., `mise install node@20`

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Tools not available | Shims not in PATH | Check `/miser:doctor` |
| MCP not connected | Missing MISE_EXPERIMENTAL | Set env var |
| Wrong tool version | No .mise.toml in directory | Create config file |
| mise not found | Not installed or unusual path | Install mise or set custom path |

---

**Last Updated:** 2025-01-25
