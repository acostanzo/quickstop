# Quickstop Plugin Marketplace

A Claude Code plugin marketplace.

## Repository Structure

```
quickstop/
├── .claude-plugin/
│   └── marketplace.json    # Plugin registry
├── plugins/
│   └── claudit/            # Configuration audit & optimization
├── scripts/
│   ├── check-plugin-versions.sh  # Version validation script
│   ├── install-hooks.sh          # Git hooks installer
│   └── git-hooks/
│       └── pre-push              # Runs version check before push
├── CLAUDE.md
└── README.md
```

## Plugin Structure

Plugins live in `plugins/[plugin-name]/`:

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

Plugin cache is keyed by version number. If you modify plugin files without bumping the version, users won't get the changes until they reinstall.

**Before pushing changes to any plugin, update all three files:**
1. `plugins/[name]/.claude-plugin/plugin.json` — bump the version
2. `.claude-plugin/marketplace.json` — match the version (`source` field is required)
3. `README.md` — update the displayed version

**Run the version check script before pushing:**
```bash
./scripts/check-plugin-versions.sh
```

**Install git hooks for automatic enforcement:**
```bash
./scripts/install-hooks.sh
```

## Commit Conventions

```
PluginName vX.Y.Z: Brief description

- Change 1
- Change 2

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Testing

```bash
claude --plugin-dir /path/to/quickstop/plugins/plugin-name
```

Refer to the [Claude Code plugin documentation](https://docs.anthropic.com/en/docs/claude-code/plugins) for authoring details.
