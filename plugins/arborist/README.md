# Arborist

Sync gitignored config files across git worktrees.

## What It Does

When you create a git worktree, gitignored files like `.env`, `.npmrc`, and local configs don't come along. Arborist automatically syncs them from main when you start a Claude session.

**Simple workflow:**
1. Create a worktree: `git worktree add ../feature-branch feature/branch`
2. Start Claude in the worktree
3. Missing configs are automatically synced from main - no action needed

## Installation

```bash
# From quickstop marketplace
/plugin install arborist@quickstop

# Or use directly
claude --plugin-dir /path/to/quickstop/plugins/arborist
```

## Usage

### Automatic Sync on Session Start

When you start Claude in a linked worktree, arborist automatically copies any missing gitignored config files from the main worktree. The sync happens silently - files just appear.

### /arborist:tend Command

For manual control, run `/arborist:tend` to interactively sync files:

1. **Select source** - Choose which worktree to sync from (main is default)
2. **Choose mode** - Sync all files or customize selection
3. **Pick files** (if customize) - Toggle which files to copy

Use this when:
- You want to sync from a different worktree (not main)
- You want to selectively sync specific files
- You need to re-sync after making changes in the source worktree

## Auto-Excluded Files

These regeneratable directories are automatically excluded:

- `node_modules/`, `.pnpm-store/`, `vendor/`, `.bundle/`
- `.venv/`, `venv/`, `__pycache__/`
- `build/`, `dist/`, `target/`, `out/`, `.gradle/`
- `.next/`, `.nuxt/`, `.cache/`, `.parcel-cache/`, `.turbo/`
- `.terraform/`, `.serverless/`

## Components

| Component | Purpose |
|-----------|---------|
| `hooks/hooks.json` | SessionStart hook configuration |
| `hooks/session-start.sh` | Auto-syncs missing configs from main |
| `commands/tend.md` | Interactive sync command |

## Requirements

- Git 2.5+ (worktree support)

## Version History

- **3.1.0** - Automatic sync on session start. No prompts, just syncs missing configs from main automatically.
- **3.0.0** - macOS alert for missing configs, interactive /tend command.
- **2.0.x** - Expert worktree guidance with .worktreeignore support
