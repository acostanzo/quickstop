# Architecture Overview

> Project: quickstop - Claude Code Plugin Marketplace

## System Design

Quickstop is a **plugin marketplace** for Claude Code, providing workflow enhancement plugins through a centralized registry system. The architecture follows a hierarchical model with a marketplace manifest at the root and self-contained plugins in subdirectories.

### Marketplace Model

```
quickstop/
├── .claude-plugin/
│   └── marketplace.json      # Central registry (source of truth for installation)
├── plugins/
│   ├── arborist/             # Self-contained plugin
│   ├── muxy/                 # Self-contained plugin
│   └── miser/                # Self-contained plugin
└── scripts/                  # Marketplace maintenance tooling
```

**Key architectural concept:** Each plugin is fully self-contained with its own `plugin.json`, but the marketplace's `marketplace.json` serves as the authoritative registry for discovery and installation. Users install plugins via:

```bash
/plugin marketplace add acostanzo/quickstop
/plugin install arborist@quickstop
```

### Plugin Architecture

Each plugin follows the Claude Code plugin structure:

```
plugins/[name]/
├── .claude-plugin/
│   └── plugin.json           # Plugin metadata (name, version, description)
├── commands/                 # Slash commands (Markdown with YAML frontmatter)
├── skills/                   # AI skills (SKILL.md with conversation triggers)
├── hooks/                    # Event hooks (hooks.json + scripts)
├── .mcp.json                 # MCP server configuration (optional)
└── README.md
```

### Data Flow

```
                    Installation
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    marketplace.json                              │
│  (Registry: name, version, source path, keywords)               │
└─────────────────────────────────────────────────────────────────┘
                         │
                         │ source: "./plugins/[name]"
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    plugins/[name]/                               │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │  plugin.json  │  │   commands/   │  │    hooks/     │       │
│  │  (metadata)   │  │ (slash cmds)  │  │(SessionStart) │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
│  ┌───────────────┐  ┌───────────────┐                          │
│  │   skills/     │  │   .mcp.json   │                          │
│  │ (AI triggers) │  │ (MCP servers) │                          │
│  └───────────────┘  └───────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
                 Claude Code Runtime
                 (loads plugins, executes hooks, provides commands)
```

## Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| Language | Bash, Markdown | Scripts, commands, skills |
| Plugin System | Claude Code Plugin SDK | Plugin loading, hooks, commands |
| MCP Integration | Model Context Protocol | External tool integration (tmux, mise) |
| Version Control | Git | Repository, pre-push hooks for version validation |
| Package Format | JSON, YAML | Manifests, templates |

## Key Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| Version-keyed plugin caching | Plugin cache uses version as key; changes without version bump are not picked up by users | 2025-01 |
| Dual-location versioning | Version in both `plugin.json` and `marketplace.json` enables independent verification | 2025-01 |
| Pre-push hook enforcement | Prevents publishing plugins without version bumps, avoiding cache staleness | 2025-01 |
| SessionStart hooks for activation | Enables plugins like miser/arborist to auto-configure environment on session start | 2025-01 |
| MCP for external tools | Muxy uses tmux-mcp, Miser uses mise mcp - provides structured tool access | 2025-01 |
| Skills for natural language | Muxy uses SKILL.md with trigger patterns for conversational session creation | 2025-01 |
| Commands for explicit actions | Doctor/diagnostic commands use explicit `/plugin:command` pattern | 2025-01 |
| Shims mode for mise | Non-interactive bash in Claude Code requires shims mode (not prompt hooks) | 2025-01 |
| Auto-sync from main worktree | Arborist silently syncs gitignored configs to reduce worktree setup friction | 2025-01 |

## Directory Structure

```
quickstop/
├── .claude-plugin/
│   └── marketplace.json          # Plugin registry for marketplace installation
├── plugins/
│   ├── arborist/                 # Git worktree config sync plugin
│   │   ├── .claude-plugin/plugin.json
│   │   ├── commands/tend.md      # Interactive sync command
│   │   └── hooks/                # SessionStart auto-sync
│   ├── muxy/                     # Tmux session management plugin
│   │   ├── .claude-plugin/plugin.json
│   │   ├── commands/             # doctor.md, templates.md
│   │   ├── skills/muxy/          # Natural language skill
│   │   ├── scripts/              # MCP launcher
│   │   └── .mcp.json             # tmux-mcp configuration
│   └── miser/                    # Mise version manager plugin
│       ├── .claude-plugin/plugin.json
│       ├── commands/doctor.md
│       ├── hooks/                # SessionStart mise activation
│       └── .mcp.json             # mise mcp configuration
├── scripts/
│   ├── check-plugin-versions.sh  # Version validation (compares against main)
│   ├── install-hooks.sh          # Git hooks installer
│   └── git-hooks/pre-push        # Pre-push version check
├── CLAUDE.md                     # Development guidelines
└── README.md                     # Public documentation
```

## Version Management System

### The Caching Problem

Claude Code caches plugins by version number. If plugin files change without a version bump, users will not receive updates until they manually clear their cache. This creates a critical requirement: **every plugin change must be accompanied by a version bump**.

### Version Locations (Must Stay Synchronized)

1. **`plugins/[name]/.claude-plugin/plugin.json`** - Authoritative plugin version
2. **`.claude-plugin/marketplace.json`** - Marketplace registry version
3. **`README.md`** - Plugin table for documentation

### Enforcement Mechanism

```
git push
    │
    ▼
pre-push hook
    │
    ▼
check-plugin-versions.sh
    │
    ├── Compares current branch to origin/main
    ├── Identifies plugins with code changes (excludes README-only changes)
    ├── Verifies version in plugin.json changed
    ├── Warns if marketplace.json not updated
    │
    ▼
Exit 0 (success) or Exit 1 (block push)
```

### Script Logic

The version check script (`scripts/check-plugin-versions.sh`):

1. Detects changed files in `plugins/` directory
2. Groups changes by plugin name
3. Excludes README.md changes (no version bump required)
4. For each plugin with changes:
   - Extracts old version from `origin/main`
   - Extracts new version from current branch
   - Fails if versions match (not bumped)
5. Warns if `marketplace.json` not updated
6. Warns if root `README.md` not updated

## Component Index

- [Marketplace Registry](components/marketplace-registry.md) - Central plugin registry
- [Arborist Plugin](components/arborist.md) - Git worktree config sync
- [Muxy Plugin](components/muxy.md) - Tmux session management
- [Miser Plugin](components/miser.md) - Mise version manager integration
- [Version Management](components/version-management.md) - Version validation system

---

**Last Updated:** 2025-01-25
