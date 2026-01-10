# Quickstop Plugin Marketplace

This repository is a Claude Code plugin marketplace containing workflow enhancement plugins.

## Repository Structure

```
quickstop/
├── .claude-plugin/
│   └── marketplace.json    # Plugin registry - KEEP UPDATED
├── plugins/
│   ├── arborist/           # Git worktree management
│   ├── miser/              # Mise version manager integration
│   └── muxy/               # Tmux session management
├── scripts/
│   ├── check-plugin-versions.sh  # Version validation script
│   ├── install-hooks.sh          # Git hooks installer
│   └── git-hooks/                # Hook templates
│       └── pre-push              # Runs version check before push
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

### IMPORTANT: Keep marketplace.json and README.md Updated

When adding, removing, or modifying plugins, update both:
1. `.claude-plugin/marketplace.json` - Plugin registry for marketplace installation
2. `README.md` - Public documentation with plugin table and features

**marketplace.json format:**

```json
{
  "plugins": [
    {
      "name": "plugin-name",
      "version": "X.Y.Z",
      "description": "Brief description",
      "source": "./plugins/plugin-name",
      "keywords": ["relevant", "keywords"]
    }
  ]
}
```

Note: The `source` field is required (use relative path like `./plugins/name`). The `features` field is NOT part of the marketplace schema - document features in the plugin's README instead.

**Update both files when:**
- Adding a new plugin (add to marketplace.json and README plugin table)
- Bumping a plugin version
- Changing a plugin's description
- Removing a plugin

### Version Conventions

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Bump MAJOR for breaking changes or complete rewrites
- Bump MINOR for new features
- Bump PATCH for bug fixes

### CRITICAL: Always Bump Versions on Plugin Changes

**Plugin cache is keyed by version number.** If you modify plugin files without bumping the version, users won't get the changes until they manually clear their cache or reinstall.

**Before pushing changes to any plugin:**
1. Bump the version in `plugins/[name]/.claude-plugin/plugin.json`
2. Update the version in `.claude-plugin/marketplace.json`
3. Update the version in `README.md` plugin table

**Run the version check script before pushing:**
```bash
./scripts/check-plugin-versions.sh
```

This script compares staged/committed changes against the main branch and warns if plugin files changed without a version bump.

**Install git hooks for automatic enforcement:**
```bash
./scripts/install-hooks.sh
```

This installs a pre-push hook that runs the version check automatically.

## Current Plugins

### Arborist (v2.0.1)
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

### Miser (v1.0.1)
Mise polyglot version manager integration for Claude Code.

**Key features:**
- SessionStart hook activates mise in shims mode (works in non-interactive bash)
- MCP integration exposing mise's built-in server (tools, env, tasks, config)
- `/miser:doctor` for diagnostics

**Note:** Requires mise with experimental features enabled (`MISE_EXPERIMENTAL=1`)

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
