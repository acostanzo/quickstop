# Quickstop Plugin Marketplace

This repository is a Claude Code plugin marketplace containing workflow enhancement plugins.

## Repository Structure

```
quickstop/
├── .claude-plugin/
│   └── marketplace.json    # Plugin registry - KEEP UPDATED
├── plugins/
│   ├── arborist/           # Git worktree management
│   ├── claudit/            # Configuration audit & optimization
│   ├── guilty-spark/       # Branch-aware documentation management
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

### When Modifying Plugins

**Plugin cache is keyed by version number.** If you modify plugin files without bumping the version, users won't get the changes until they manually clear their cache or reinstall.

**Before pushing changes to any plugin, update all three files:**
1. Bump the version in `plugins/[name]/.claude-plugin/plugin.json`
2. Update the version in `.claude-plugin/marketplace.json` (see the file for format; `source` field is required)
3. Update the version in `README.md` plugin table

**Run the version check script before pushing:**
```bash
./scripts/check-plugin-versions.sh
```

**Install git hooks for automatic enforcement:**
```bash
./scripts/install-hooks.sh
```

## Current Plugins

### Claudit (v1.0.0)
Configuration audit and optimization with dynamic best-practice research.

**Key features:**
- Research-first architecture (subagents fetch Anthropic docs before analysis)
- Over-engineering detection as highest-weighted scoring category
- 6-category health scoring with interactive fix selection
- Persistent memory on research agents for faster subsequent runs
- `/claudit` for comprehensive configuration audit

### Guilty Spark (v3.2.0)
Branch-aware documentation management for Claude Code projects.

**Key features:**
- Cross-referencing, link auditing, and README pattern generation
- Stale documentation cleanup with sentinel agents
- Branch-aware documentation with mermaid diagrams
- `/guilty-spark:checkpoint` for documentation capture, `/guilty-spark:monitor` for docs management

### Arborist (v3.1.0)
Git worktree management with automatic configuration syncing.

**Key features:**
- Auto-syncs gitignored config files from main on session start
- `.worktreeignore` config for controlling file sync
- `/arborist:tend` for interactive sync with source selection

### Muxy (v3.0.0)
Natural language tmux session management with templates.

**Key features:**
- Natural language session creation with preview workflow
- Template system with variable inference (`${project_dir}`)
- Auto-detected shell (no configuration needed)
- Only 2 commands: `/muxy:doctor`, `/muxy:templates`

### Miser (v1.0.2)
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

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Testing Plugins

Test plugins locally before committing:

```bash
claude --plugin-dir /path/to/quickstop/plugins/plugin-name
```
