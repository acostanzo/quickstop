# Quickstop

A collection of Claude Code plugins for workflow enhancement and productivity.

## Plugins

| Plugin | Version | Description |
|--------|---------|-------------|
| [Arborist](plugins/arborist/) | 3.1.0 | Sync gitignored config files across git worktrees |
| [Muxy](plugins/muxy/) | 3.0.0 | Natural language tmux session management with templates |
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

Automatic syncing of gitignored config files across git worktrees.

**Features:**
- Auto-syncs missing config files from main on session start
- Interactive `/arborist:tend` command for manual sync with source selection
- Auto-excludes regeneratable directories (node_modules, build, .venv, etc.)

**Commands:**
- `/arborist:tend` - Interactive sync of gitignored config files

### Muxy

Natural language tmux session management. Describe what you want, Claude builds it.

**Features:**
- Natural language session creation with visual previews
- Template system with smart variable inference
- Auto-detected shell (no configuration needed)
- Dramatically simplified from v2 (2 commands vs 9)

**Commands:**
- `/muxy:doctor` - Verify setup
- `/muxy:templates` - List available templates

**Requirements:**
- tmux installed
- Node.js (for tmux-mcp)

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
