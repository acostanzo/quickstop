# Quickstop

A collection of Claude Code plugins for workflow enhancement and productivity.

## Plugins

| Plugin | Version | Description |
|--------|---------|-------------|
| [Arborist](plugins/arborist/) | 2.0.0 | Git worktree management with automatic configuration syncing |
| [Muxy](plugins/muxy/) | 2.0.0 | Tmux session management with templates and natural language pane interactions |

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
```

### Install from Source

Clone and use directly:

```bash
git clone https://github.com/acostanzo/quickstop.git
claude --plugin-dir /path/to/quickstop/plugins/arborist
```

## Plugin Overview

### Arborist

Expert git worktree management with automatic configuration syncing between worktrees.

**Features:**
- Comprehensive worktree skill (create, manage, repair, troubleshoot)
- Automatic syncing of gitignored files (`.env`, IDE settings) to new worktrees
- `.worktreeignore` config file for customizing skip patterns
- SessionStart hook displays worktree status when in a linked worktree
- `/arborist:doctor` command for diagnostics

**Commands:**
- `/arborist:doctor` - Diagnose and sync gitignored files

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

## Contributing

Plugins are developed using the `plugin-dev` plugin from [claude-plugins-official](https://github.com/anthropics/claude-plugins-official).

See [CLAUDE.md](CLAUDE.md) for development guidelines.

## License

MIT
