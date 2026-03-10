# Quickstop Plugin Marketplace

A Claude Code plugin marketplace.

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

## Dev Tools

Repo-level skills in `.claude/` for plugin authors:

- **`/smith <plugin-name>`** — Scaffold a new plugin with correct structure, frontmatter, and marketplace registration
- **`/hone <plugin-name>`** — Audit an existing plugin's quality against the Claude Code plugin spec (8-category scoring)

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
