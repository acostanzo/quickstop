# Quickstop

> *"I'm not even supposed to be here today!"* - Dante Hicks

A collection of Claude Code plugins for workflow enhancement and productivity. Like the convenience store from Clerks, Quickstop is your one-stop shop for useful Claude Code extensions.

## Available Plugins

### 🌳 Arborist
**Git worktree management with gardening-themed commands**

Work efficiently with git worktrees for parallel development across multiple branches. Plant, graft, fertilize, prune, and uproot worktrees with intuitive commands and Claude's expert guidance.

**Features:**
- Worktree skill for intelligent recommendations
- Session awareness of your current worktree
- Five gardening-themed slash commands: plant, graft, fertilize, prune, uproot
- Multi-repository support for consistent worktree management
- Smart gitignored file copying between worktrees

[📖 Read Arborist Documentation](./plugins/arborist/README.md)

### 🖥️ Muxy
**Orchestrate complex tmux sessions with templates**

Define reusable session configurations with windows, panes, and commands. Integrates with Arborist for worktree-aware development environments.

**Features:**
- Session templates with windows, panes, and startup commands
- Template variables: `{{worktree:branch}}`, `{{project_name}}`, `{{date}}`
- Git worktree integration via Arborist plugin
- Pane operations: run commands and read output
- Interactive session/window/pane selection

[📖 Read Muxy Documentation](./plugins/muxy/README.md)

## Installation

### Quick Start

```bash
# Add the Quickstop marketplace
/plugin marketplace add acostanzo/quickstop

# Install a plugin
/plugin install arborist@quickstop
```

Restart Claude Code to activate the plugin.

### From Local Clone

```bash
# Clone the repository
git clone https://github.com/acostanzo/quickstop.git

# Add as a local marketplace
/plugin marketplace add ./quickstop

# Install a plugin
/plugin install arborist@quickstop
```

## Plugin Management

### List Available Plugins
```bash
/plugin
```
Select "Browse Plugins" to see what's available in Quickstop.

### Disable/Enable
```bash
/plugin disable arborist@quickstop
/plugin enable arborist@quickstop
```

### Uninstall
```bash
/plugin uninstall arborist@quickstop
```

## Repository Structure

```
quickstop/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace definition
├── plugins/
│   ├── arborist/                 # Git worktree management
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── commands/
│   │   ├── hooks/
│   │   ├── skills/
│   │   ├── README.md
│   │   └── CHANGELOG.md
│   └── muxy/                     # Tmux session orchestration
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── commands/
│       ├── README.md
│       └── CHANGELOG.md
├── README.md                     # This file
└── CONTRIBUTING.md              # How to contribute
```

## Contributing

Want to add a new plugin to Quickstop? See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on:
- Plugin structure requirements
- Code standards
- Testing expectations
- Documentation format

## Philosophy

Quickstop plugins follow these principles:

1. **Focused Purpose** - Each plugin does one thing well
2. **Non-Intrusive** - Plugins enhance without getting in the way
3. **Well-Documented** - Clear docs and examples
4. **Production Ready** - Tested and reliable
5. **Community Friendly** - Easy to understand and contribute to

## About the Name

Quickstop is named after the convenience store in Kevin Smith's film "Clerks" (1994), where Dante and Randal work. Like the store, this marketplace aims to provide convenient tools that make your day-to-day work with Claude Code easier—even if you're not supposed to be here today.

## License

MIT

## Author

**Anthony Costanzo**
- Email: mail@acostanzo.com
- GitHub: [@acostanzo](https://github.com/acostanzo)
