# Marketplace Registry

> Component: Central plugin registry for quickstop marketplace

## Purpose

The marketplace registry (`/.claude-plugin/marketplace.json`) serves as the authoritative source for plugin discovery and installation. It enables Claude Code to find and install plugins from the quickstop marketplace.

## Schema

```json
{
  "name": "quickstop",
  "owner": {
    "name": "Author Name",
    "email": "email@example.com"
  },
  "description": "Marketplace description",
  "plugins": [
    {
      "name": "plugin-name",
      "version": "X.Y.Z",
      "description": "Brief description",
      "source": "./plugins/plugin-name",
      "keywords": ["keyword1", "keyword2"]
    }
  ]
}
```

## Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Marketplace identifier |
| `owner` | Yes | Marketplace owner information |
| `description` | Yes | Human-readable marketplace description |
| `plugins` | Yes | Array of plugin entries |

### Plugin Entry Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Plugin name (must match directory name in plugins/) |
| `version` | Yes | Semantic version (must match plugin.json) |
| `description` | Yes | Brief plugin description |
| `source` | Yes | Relative path to plugin directory |
| `keywords` | No | Search/discovery keywords |

## Source File

**Location:** `/Users/acostanzo/Code/quickstop/.claude-plugin/marketplace.json`

```json
{
  "name": "quickstop",
  "owner": {
    "name": "Anthony Costanzo",
    "email": "mail@acostanzo.com"
  },
  "description": "A collection of Claude Code plugins for workflow enhancement and productivity",
  "plugins": [
    {
      "name": "arborist",
      "version": "3.1.0",
      "description": "Sync gitignored config files across git worktrees",
      "source": "./plugins/arborist",
      "keywords": ["git", "worktree", "configuration", "sync", "env"]
    },
    {
      "name": "muxy",
      "version": "3.0.0",
      "description": "Natural language tmux session management with templates",
      "source": "./plugins/muxy",
      "keywords": ["tmux", "terminal", "multiplexer", "sessions", "templates"]
    },
    {
      "name": "miser",
      "version": "1.0.2",
      "description": "Mise polyglot version manager integration for Claude Code",
      "source": "./plugins/miser",
      "keywords": ["mise", "version-manager", "polyglot", "ruby", "node", "python", "tools"]
    }
  ]
}
```

## Relationship to Plugin Versions

The version in `marketplace.json` must match the version in each plugin's `plugin.json`. This dual-location versioning enables:

1. **Independent verification** - Claude Code can verify consistency
2. **Cache invalidation** - Version changes trigger cache refresh
3. **Changelog tracking** - Git history shows version changes

## Update Requirements

When modifying plugins, update:

1. `plugins/[name]/.claude-plugin/plugin.json` - Plugin version
2. `.claude-plugin/marketplace.json` - Registry version
3. `README.md` - Documentation table

The `scripts/check-plugin-versions.sh` script validates these are synchronized before push.

## Installation Flow

```
User: /plugin marketplace add acostanzo/quickstop
                    │
                    ▼
           Fetch marketplace.json
                    │
                    ▼
User: /plugin install arborist@quickstop
                    │
                    ▼
           Find entry where name == "arborist"
                    │
                    ▼
           Resolve source: "./plugins/arborist"
                    │
                    ▼
           Load plugins/arborist/.claude-plugin/plugin.json
                    │
                    ▼
           Install plugin files
```

---

**Last Updated:** 2025-01-25
