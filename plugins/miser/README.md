# Miser

Mise polyglot version manager integration for Claude Code.

## Problem

Claude Code runs bash commands in non-interactive mode, which doesn't source shell configuration files (`.bashrc`, `.zshrc`, etc.). This means mise's normal activation (`mise activate bash`) doesn't work because it relies on a prompt hook (`PROMPT_COMMAND`) that never fires in non-interactive shells.

## Solution

Miser activates mise in **shims mode** at session start. Shims mode simply prepends `~/.local/share/mise/shims` to PATH, where wrapper scripts delegate to the correct tool versions. This works perfectly in any bash context.

## Features

- **Automatic Activation**: SessionStart hook activates mise for all Claude Code bash commands
- **Shims Mode**: Works correctly in non-interactive bash (no prompt hooks needed)
- **MCP Integration**: Exposes mise's built-in MCP server for querying tools, env, tasks, and config
- **Diagnostics**: `/miser:doctor` command to verify integration

## Prerequisites

- [mise](https://mise.jdx.dev/) installed and configured
- Tools installed via mise (e.g., `mise install node@20`)

## How It Works

### SessionStart Hook

When Claude Code starts, the hook:

1. Locates the mise binary
2. Runs `mise activate bash --shims`
3. Captures environment changes
4. Writes them to `$CLAUDE_ENV_FILE` for session persistence

### MCP Server

The plugin configures mise's built-in MCP server (`mise mcp`), which exposes:

| Resource | Description |
|----------|-------------|
| `mise://tools` | Active and installed tool versions |
| `mise://env` | Environment variables mise would set |
| `mise://tasks` | Available mise tasks |
| `mise://config` | Configuration information |

## Commands

### `/miser:doctor`

Diagnose mise integration:

- Verify mise installation and version
- Check shims directory and PATH
- List active tool versions
- Verify tool accessibility
- Check MCP server connection

## Installation

### From Marketplace

```bash
claude /install-plugin quickstop/miser
```

### Manual

Clone and add to your Claude Code plugins:

```bash
git clone https://github.com/quickstop/quickstop.git
claude --plugin-dir /path/to/quickstop/plugins/miser
```

## Troubleshooting

### Tools not available in Claude Code

1. Run `/miser:doctor` to diagnose
2. Verify mise is installed: `which mise`
3. Check tools are installed: `mise list`
4. Restart Claude Code to re-run SessionStart hook

### Shims not in PATH

The shims directory should be at `~/.local/share/mise/shims`. If missing, run:

```bash
mise reshim
```

### MCP server not connecting

Verify mise version supports MCP (v2024.5.0+):

```bash
mise --version
mise mcp --help
```

## Technical Notes

### Why shims mode?

Normal `mise activate bash` sets up:

```bash
PROMPT_COMMAND="_mise_hook;$PROMPT_COMMAND"
```

The `_mise_hook` function runs on each prompt display to update PATH based on the current directory. In non-interactive bash, prompts are never displayed, so the hook never runs.

Shims mode instead adds `~/.local/share/mise/shims` to PATH. Each shim is a wrapper script that:

1. Determines the correct tool version (from `.mise.toml`, `.tool-versions`, etc.)
2. Delegates to that version's actual binary

This works identically in interactive and non-interactive contexts.

### Environment persistence

The `$CLAUDE_ENV_FILE` mechanism allows SessionStart hooks to persist environment variables for the entire Claude Code session. The hook:

1. Captures `export -p` before mise activation
2. Activates mise
3. Captures `export -p` after
4. Writes only the *new* exports to `$CLAUDE_ENV_FILE`

Claude Code sources this file before each bash command.
