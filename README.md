# Quickstop

A collection of Claude Code plugins for workflow enhancement and productivity.

## Plugins

| Plugin | Version | Description |
|--------|---------|-------------|
| [Arborist](plugins/arborist/) | 3.0.0 | Sync gitignored config files across git worktrees |
| [Muxy](plugins/muxy/) | 2.0.0 | Tmux session management with templates and natural language pane interactions |
| [Miser](plugins/miser/) | 1.0.2 | Mise polyglot version manager integration for Claude Code |

## Installation

### Install from Marketplace

First, add quickstop as a plugin marketplace in Claude Code:

```bash
/plugin marketplace add acostanzo/quickstop
```

Then install individual plugins:

```bash
/plugin install arborist@quickstop
/plugin install muxy@quickstop
/plugin install miser@quickstop
```

### Install from Source

Clone and use directly:

```bash
git clone https://github.com/acostanzo/quickstop.git
claude --plugin-dir /path/to/quickstop/plugins/arborist
```

## Plugin Overview

### Arborist

Lightweight detection and syncing of gitignored config files across git worktrees.

**Features:**
- SessionStart hook detects missing config files when in a linked worktree
- Interactive `/arborist:tend` command to sync files from any worktree
- Auto-excludes regeneratable directories (node_modules, build, .venv, etc.)

**Commands:**
- `/arborist:tend` - Interactive sync of gitignored config files

### Muxy

Tmux session management with YAML-based templates and natural language pane interactions.

**Features:**
- Template-based session creation
- Natural language pane interactions ("read the server pane", "run tests in pane 2")
- tmux-mcp server integration
- Session and template management

**Commands:**
- `/muxy:session [template]` - Create session from template
- `/muxy:list-sessions` - List active sessions
- `/muxy:read-session [name]` - Show session layout
- `/muxy:kill [name]` - Destroy session
- `/muxy:template-create` - Create new template
- `/muxy:template-list` - List templates
- `/muxy:template-edit [name]` - Modify template
- `/muxy:template-delete [name]` - Remove template
- `/muxy:doctor` - Verify setup

**Requirements:**
- tmux 2.1+
- Node.js (for tmux-mcp)
- Set `MUXY_SHELL` env var for your shell (default: fish)

### Miser

Mise polyglot version manager integration for Claude Code's non-interactive bash environment.

**Features:**
- Automatic mise activation in shims mode at session start
- Works with non-interactive bash (no prompt hooks needed)
- MCP integration exposing mise's built-in server (tools, env, tasks, config)
- Diagnostic command for troubleshooting

**Commands:**
- `/miser:doctor` - Diagnose mise integration and verify tool availability

**Requirements:**
- [mise](https://mise.jdx.dev/) installed
- Tools installed via mise (e.g., `mise install node@20`)

## Contributing

Plugins are developed using the `plugin-dev` plugin from [claude-plugins-official](https://github.com/anthropics/claude-plugins-official).

See [CLAUDE.md](CLAUDE.md) for development guidelines.

## License

MIT
