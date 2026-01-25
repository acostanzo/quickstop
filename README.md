# Quickstop

A collection of Claude Code plugins for workflow enhancement and productivity.

## Plugins

| Plugin | Version | Description |
|--------|---------|-------------|
| [Arborist](plugins/arborist/) | 3.1.0 | Sync gitignored config files across git worktrees |
| [Guilty Spark](plugins/guilty-spark/) | 1.0.3 | Autonomous documentation management for Claude Code projects |
| [Miser](plugins/miser/) | 1.0.2 | Mise polyglot version manager integration for Claude Code |
| [Muxy](plugins/muxy/) | 3.0.0 | Natural language tmux session management with templates |

## Installation

### Install from Marketplace

First, add quickstop as a plugin marketplace in Claude Code:

```bash
/plugin marketplace add acostanzo/quickstop
```

Then install individual plugins:

```bash
/plugin install arborist@quickstop
/plugin install guilty-spark@quickstop
/plugin install miser@quickstop
/plugin install muxy@quickstop
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

### Guilty Spark

Autonomous documentation management for Claude Code projects. Named after 343 Guilty Spark from Halo.

**Features:**
- Automatic documentation capture at session end and before /clear
- The Monitor skill for documentation management
- Sentinel agents for autonomous documentation updates
- Deep codebase research via Sentinel-Research
- Atomic commits (docs always separate from code)

**Commands:**
- `/guilty-spark:doctor` - Verify plugin setup and documentation health

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
