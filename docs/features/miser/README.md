# Miser Plugin

> Version: 1.0.2 | Mise polyglot version manager integration

## Overview

Miser integrates [mise](https://mise.jdx.dev/) (polyglot version manager) with Claude Code, enabling automatic tool version management. It activates mise in shims mode on session start and exposes mise's MCP server for tool/environment introspection.

## Problem Solved

Claude Code runs bash commands in non-interactive mode. The standard `mise activate bash` relies on `PROMPT_COMMAND` hooks that only fire when displaying a prompt—which never happens in non-interactive shells. Miser solves this by using **shims mode**, which prepends the shims directory to PATH.

## Architecture

```
plugins/miser/
├── .claude-plugin/
│   └── plugin.json           # Plugin metadata (v1.0.2)
├── .mcp.json                  # MCP server configuration
├── commands/
│   └── doctor.md             # Diagnostics command
└── hooks/
    ├── hooks.json            # SessionStart hook config
    └── session-start.sh      # Mise activation script
```

## Key Components

| Component | File | Purpose |
|-----------|------|---------|
| Activation Hook | `hooks/session-start.sh` | Activates mise in shims mode |
| MCP Server | `.mcp.json` | Exposes mise's built-in MCP server |
| Doctor Command | `commands/doctor.md` | Diagnostics for troubleshooting |

## How It Works

### SessionStart Hook

When Claude starts, the hook activates mise for the session:

1. **Find mise binary** (`session-start.sh:15-21`)
   - Searches: `~/.local/bin/mise`, `/usr/local/bin/mise`, `/opt/homebrew/bin/mise`
   - Falls back to `command -v mise`
   - Exits silently if mise not installed

2. **Activate in shims mode** (`session-start.sh:30`)
   ```bash
   eval "$("$MISE_BIN" activate bash --shims)"
   ```
   This prepends `~/.local/share/mise/shims` to PATH instead of using prompt hooks.

3. **Persist environment** (`session-start.sh:27-37`)
   - Captures environment before and after activation
   - Writes diff to `$CLAUDE_ENV_FILE`
   - This persists changes for all subsequent bash commands

### MCP Integration

The `.mcp.json` configures mise's built-in MCP server:

```json
{
  "mcpServers": {
    "mise": {
      "command": "bash",
      "args": ["-c", "...find mise and exec mise mcp..."],
      "env": { "MISE_EXPERIMENTAL": "1" }
    }
  }
}
```

**Available MCP Resources:**

| Resource | Description |
|----------|-------------|
| `mise://tools` | Installed tool versions |
| `mise://env` | Environment variables set by mise |
| `mise://tasks` | Available mise tasks |
| `mise://config` | Current mise configuration |

## Prerequisites

1. **mise installed** - Any standard installation method
2. **Experimental features enabled** - Required for MCP server
   ```bash
   export MISE_EXPERIMENTAL=1
   # or add to mise config
   ```

## Usage

### Automatic Activation

Mise activates automatically on session start:
```
$ claude
mise activated (shims mode)
```

### Check Status

```
/miser:doctor
```

This verifies:
- mise installation and version
- Shims mode activation
- MCP server connectivity
- Tool availability

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Shims mode over activate | Works in non-interactive bash; prompt hooks don't fire |
| Multi-path binary search | Supports various installation methods (brew, cargo, binary) |
| Environment diff capture | Persists mise changes to `$CLAUDE_ENV_FILE` for session |
| Silent failure | Exits cleanly if mise not installed; doesn't break other plugins |

## Troubleshooting

**Mise not activating:**
- Check if mise is installed: `which mise`
- Verify `MISE_EXPERIMENTAL=1` is set for MCP features

**MCP server not connecting:**
- Run `/miser:doctor` for diagnostics
- Check `/mcp` to see if mise server is listed

## Code References

- Binary discovery: `plugins/miser/hooks/session-start.sh:15-21`
- Shims activation: `plugins/miser/hooks/session-start.sh:30`
- Environment persistence: `plugins/miser/hooks/session-start.sh:35-37`
- MCP configuration: `plugins/miser/.mcp.json:1-14`
