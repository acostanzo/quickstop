# Quickstop Plugin Marketplace

This repository is a Claude Code plugin marketplace containing workflow enhancement plugins.

## Repository Structure

```
quickstop/
├── .claude-plugin/
│   └── marketplace.json    # Plugin registry - KEEP UPDATED
├── plugins/
│   ├── arborist/           # Git worktree management
│   └── muxy/               # Tmux session management
└── CLAUDE.md
```

## Plugin Development

### Creating New Plugins

Use the `plugin-dev` plugin from `claude-plugins-official` for guided plugin creation:

```
/plugin-dev:create-plugin [description of what you want to build]
```

This provides a structured workflow through:
1. Discovery - Understanding requirements
2. Component Planning - Determining skills, commands, hooks, MCP needs
3. Detailed Design - Specifying each component
4. Implementation - Building with best practices
5. Validation - Quality checks
6. Testing - Verification

### Plugin Location

All plugins live in `plugins/[plugin-name]/` with this structure:

```
plugins/plugin-name/
├── .claude-plugin/
│   └── plugin.json         # Required: name, version, description
├── commands/               # Slash commands (.md files)
├── skills/                 # Skills (subdirs with SKILL.md)
│   └── skill-name/
│       └── SKILL.md
├── hooks/                  # Event hooks
│   └── hooks.json
├── .mcp.json              # MCP server config (if needed)
└── README.md
```

## Marketplace Management

### IMPORTANT: Keep marketplace.json Updated

When adding, removing, or modifying plugins, update `.claude-plugin/marketplace.json`:

```json
{
  "plugins": [
    {
      "name": "plugin-name",
      "version": "X.Y.Z",
      "description": "Brief description",
      "path": "plugins/plugin-name",
      "keywords": ["relevant", "keywords"],
      "features": ["Key feature 1", "Key feature 2"]
    }
  ]
}
```

**Update marketplace.json when:**
- Adding a new plugin
- Bumping a plugin version
- Changing a plugin's description or features
- Removing a plugin

### Version Conventions

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Bump MAJOR for breaking changes or complete rewrites
- Bump MINOR for new features
- Bump PATCH for bug fixes

## Current Plugins

### Arborist (v2.0.0)
Git worktree management with automatic configuration syncing.

**Key features:**
- Worktree skill for creation, management, repair
- `.worktreeignore` config for controlling file sync
- SessionStart hook displays worktree status
- `/arborist:doctor` for diagnostics

### Muxy (v2.0.0)
Tmux session management with templates and natural language pane interactions.

**Key features:**
- YAML-based session templates
- Natural language pane reading/command execution
- tmux-mcp server integration
- Session and template management commands

**Configuration:** Set `MUXY_SHELL` environment variable for your shell (default: fish)

## Commit Conventions

When committing plugin changes:

```
PluginName vX.Y.Z: Brief description

- Feature/change 1
- Feature/change 2

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

## Testing Plugins

Test plugins locally before committing:

```bash
claude --plugin-dir /path/to/quickstop/plugins/plugin-name
```

Verify:
- Skills trigger on expected phrases
- Commands appear in `/help`
- Hooks execute on events
- MCP servers connect (check with `/mcp`)
