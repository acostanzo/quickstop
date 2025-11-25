# Quickstop

> *"I'm not even supposed to be here today!"* - Dante Hicks

A collection of Claude Code plugins for workflow enhancement and productivity. Like the convenience store from Clerks, Quickstop is your one-stop shop for useful Claude Code extensions.

## Available Plugins

### 🎙️ Courtney
**Your agentic workflow stenographer**

Records Claude Code conversations to a searchable SQLite database. Like a stenographer, Courtney captures only what was said—user prompts, AI responses, and subagent reports—without the noise of tool calls and internal reasoning.

**Features:**
- Automatic conversation recording
- Searchable SQLite database
- `/readback` command for reviewing transcripts
- No truncation - full conversation history
- Simple schema: sessions and entries

[📖 Read Courtney Documentation](./plugins/courtney/README.md)

### 🔌 Pluggy
**Your plugin development consultant**

Expert audits and interactive planning with deep ecosystem knowledge. Pluggy provides specialized subagents that understand the entire Claude Code plugin system—commands, hooks, skills, subagents, and best practices.

**Features:**
- Comprehensive plugin audits via `/pluggy:audit`
- Interactive planning sessions via `/pluggy:plan`
- Deep plugin ecosystem knowledge
- Smart scaffolding based on your needs
- Security and performance guidance

[📖 Read Pluggy Documentation](./plugins/pluggy/README.md)

### 🌳 Arborist
**Git worktree management with gardening-themed commands**

Work efficiently with git worktrees for parallel development across multiple branches. Plant, graft, fertilize, prune, and uproot worktrees with intuitive commands and Claude's expert guidance.

**Features:**
- Worktree skill for intelligent recommendations
- Session awareness of your current worktree
- Gardening-themed commands (plant, graft, fertilize, prune, uproot)
- Multi-repository support
- Copy configuration files between worktrees

[📖 Read Arborist Documentation](./plugins/arborist/README.md)

## Installation

### Quick Start

```bash
# Add the Quickstop marketplace
/plugin marketplace add acostanzo/quickstop

# Install a plugin
/plugin install courtney@quickstop
```

Restart Claude Code to activate the plugin.

### From Local Clone

```bash
# Clone the repository
git clone https://github.com/acostanzo/quickstop.git

# Add as a local marketplace
/plugin marketplace add ./quickstop

# Install a plugin
/plugin install courtney@quickstop
```

## Plugin Management

### List Available Plugins
```bash
/plugin
```
Select "Browse Plugins" to see what's available in Quickstop.

### Disable/Enable
```bash
/plugin disable courtney@quickstop
/plugin enable courtney@quickstop
```

### Uninstall
```bash
/plugin uninstall courtney@quickstop
```

## Repository Structure

```
quickstop/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace definition
├── plugins/
│   ├── courtney/                 # Conversation recorder
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json      # Plugin manifest
│   │   ├── courtney/            # Python package
│   │   ├── hooks/               # Hook scripts
│   │   ├── commands/            # Slash commands
│   │   ├── README.md
│   │   └── CHANGELOG.md
│   ├── pluggy/                   # Plugin development assistant
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── pluggy/              # Python package
│   │   ├── commands/
│   │   ├── docs/                # Plugin knowledge base
│   │   ├── README.md
│   │   └── CHANGELOG.md
│   └── arborist/                 # Git worktree management
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── commands/
│       ├── hooks/
│       ├── skills/
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
