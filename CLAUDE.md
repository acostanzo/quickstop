# Quickstop Plugin Marketplace

A Claude Code plugin marketplace.

## Repository Structure

```
quickstop/
├── .claude/
│   ├── skills/
│   │   ├── smith/              # /smith — plugin scaffolder
│   │   └── hone/               # /hone — plugin auditor
│   └── agents/                 # Shared agents (research + audit)
├── .claude-plugin/
│   └── marketplace.json        # Plugin registry
├── plugins/
│   └── claudit/                # Configuration audit & optimization
├── scripts/
│   ├── check-plugin-versions.sh
│   ├── install-hooks.sh
│   └── git-hooks/
│       └── pre-push
├── CLAUDE.md
└── README.md
```

## Plugin Structure

Plugins live in `plugins/[plugin-name]/`:

```
plugins/plugin-name/
├── .claude-plugin/
│   └── plugin.json         # Required: name, version, description
├── skills/                 # Skills (subdirs with SKILL.md)
│   └── skill-name/
│       ├── SKILL.md
│       └── references/     # Optional reference files loaded on demand
├── agents/                 # Sub-agent definitions
│   └── agent-name.md
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

## Dev Tools

Repo-level skills in `.claude/` for plugin authors:

- **`/smith <plugin-name>`** — Scaffold a new plugin with correct structure, frontmatter, and marketplace registration
- **`/hone <plugin-name>`** — Audit an existing plugin's quality against the Claude Code plugin spec (8-category scoring)

Shared infrastructure:
- `.claude/agents/research-plugin-spec.md` — fetches plugin/skill/agent docs (haiku, cached)
- `.claude/agents/research-hooks-mcp.md` — fetches hooks/MCP docs (haiku, cached)
- `.claude/skills/smith/references/plugin-spec.md` — canonical plugin structure baseline
- `.claude/skills/hone/references/scoring-rubric.md` — 8-category scoring framework

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
