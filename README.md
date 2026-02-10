# Quickstop

A collection of Claude Code plugins for workflow enhancement and productivity.

## Plugins

| Plugin | Version | Description |
|--------|---------|-------------|
| [Arborist](plugins/arborist/) | 3.1.0 | Sync gitignored config files across git worktrees |
| [Claudit](plugins/claudit/) | 1.0.0 | Audit and optimize Claude Code configurations with dynamic best-practice research |
| [Guilty Spark](plugins/guilty-spark/) | 3.2.0 | Branch-aware documentation management for Claude Code projects |
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
/plugin install claudit@quickstop
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

### Claudit

Audit and optimize your Claude Code configuration with dynamic best-practice research.

**Features:**
- Research-first architecture: fetches official Anthropic docs before analysis
- Over-engineering detection (highest-weighted scoring category)
- 6-category health scoring with visual report
- Interactive fix selection with before/after score delta
- Persistent memory: research agents get faster across runs

**Commands:**
- `/claudit` - Run comprehensive configuration audit

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

Branch-aware documentation management for Claude Code projects. Named after 343 Guilty Spark from Halo.

**Features:**
- Branch-aware checkpoint (diff mode on feature branches, deep review on main)
- Mermaid diagram generation for architecture and data flows
- Monitor skill for on-demand documentation
- Sentinel agents for autonomous documentation updates
- Deep codebase research via Sentinel-Research
- Atomic commits (docs always separate from code)

**Commands:**
- `/guilty-spark:checkpoint` - Branch-aware documentation capture

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
