# Arborist

Sync gitignored config files across git worktrees.

## What It Does

When you create a git worktree, gitignored files like `.env`, `.npmrc`, and local configs don't come along. Arborist detects this and helps you sync them.

**Simple workflow:**
1. Create a worktree via CLI: `git worktree add ../feature-branch feature/branch`
2. Start Claude in the worktree
3. If configs are missing, you'll see a **macOS alert dialog** prompting you to sync
4. Run `/arborist:tend` to interactively sync what you need

## Installation

```bash
# From quickstop marketplace
/plugin install arborist@quickstop

# Or use directly
claude --plugin-dir /path/to/quickstop/plugins/arborist
```

## Usage

### Automatic Detection

When you start a Claude session in a linked worktree, arborist checks for missing config files. If any are found, a **macOS alert dialog** appears:

```
┌─────────────────────────────────────────┐
│  🌳 Worktree: feature/auth              │
│                                         │
│  Missing 3 config files from main.      │
│                                         │
│  Run /arborist:tend to sync.            │
│                                         │
│                              [ OK ]     │
└─────────────────────────────────────────┘
```

This alert only appears when:
- You're in a linked worktree (not the main repo)
- There are config files in main that don't exist in your worktree
- You're on macOS

### /arborist:tend Command

Interactive command to sync config files:

1. **Select source** - Choose which worktree to sync from (main is default)
2. **Choose mode** - Sync all files or customize selection
3. **Pick files** (if customize) - Toggle which files to copy

Example flow:
```
> /arborist:tend

Select worktree to sync from:
○ main (/Users/you/project/main) [Recommended]
○ feature-auth (/Users/you/project/feature-auth)

Found 3 config files to sync. How would you like to proceed?
○ Sync all (Recommended)
○ Customize

✓ Synced 3 files from main:
  - .env
  - .env.local
  - config/local.json
```

## Auto-Excluded Files

These regeneratable directories are automatically excluded from detection and sync:

- `node_modules/`, `.pnpm-store/`, `vendor/`, `.bundle/`
- `.venv/`, `venv/`, `__pycache__/`
- `build/`, `dist/`, `target/`, `out/`, `.gradle/`
- `.next/`, `.nuxt/`, `.cache/`, `.parcel-cache/`, `.turbo/`
- `.terraform/`, `.serverless/`

## Components

| Component | Purpose |
|-----------|---------|
| `hooks/hooks.json` | SessionStart hook configuration |
| `hooks/session-start.sh` | Detects missing configs, shows macOS alert |
| `commands/tend.md` | Interactive sync command |

## Requirements

- Git 2.5+ (worktree support)
- macOS (for alert notifications)

## Version History

- **3.0.0** - Complete rewrite. macOS alert for missing configs, interactive /tend command. Removed worktree skill, .worktreeignore, and doctor command.
- **2.0.x** - Expert worktree guidance with .worktreeignore support
