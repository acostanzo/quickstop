# Arborist Plugin

> Version: 3.1.0 | Git worktree configuration syncing

## Overview

Arborist automatically syncs gitignored configuration files (like `.env`, `.npmrc`, local configs) from the main worktree to linked worktrees. This eliminates the manual process of copying configuration files when working with git worktrees.

## Problem Solved

When working with git worktrees, gitignored files (environment configs, local settings) don't transfer between worktrees. Developers must manually copy these files, which is error-prone and tedious. Arborist automates this.

## Architecture

```
plugins/arborist/
├── .claude-plugin/
│   └── plugin.json           # Plugin metadata (v3.1.0)
├── commands/
│   └── tend.md               # Interactive sync command
└── hooks/
    ├── hooks.json            # SessionStart hook config
    └── session-start.sh      # Auto-sync script
```

## Key Components

| Component | File | Purpose |
|-----------|------|---------|
| Auto-Sync Hook | `hooks/session-start.sh` | Silently syncs missing configs on session start |
| Tend Command | `commands/tend.md` | Interactive sync with source worktree selection |

## How It Works

### Automatic Sync (SessionStart Hook)

When Claude starts in a **linked worktree** (not main), the hook:

1. **Detects worktree context** (`session-start.sh:14-16`)
   - Checks if `.git` path contains `/worktrees/`
   - Exits silently if in main worktree (nothing to sync from)

2. **Finds main worktree** (`session-start.sh:22-24`)
   - Strips `/worktrees/*` from git directory path
   - Derives main worktree location

3. **Discovers gitignored files** (`session-start.sh:34`)
   - Runs `git ls-files --others --ignored --exclude-standard` in main
   - Filters out regeneratable directories (see exclusions below)

4. **Syncs missing files** (`session-start.sh:44-62`)
   - Only copies files that exist in main but NOT in current worktree
   - Preserves permissions with `cp -a`
   - Creates parent directories as needed

5. **Reports results** (`session-start.sh:65-70`)
   - Shows count and names of synced files
   - Silent if nothing to sync

### Interactive Sync (`/arborist:tend`)

For manual control, the `/arborist:tend` command provides:

1. **Source selection** - Choose which worktree to sync from (not just main)
2. **File preview** - See what files will be synced with sizes
3. **Selective sync** - Choose to sync all or pick specific files

## Auto-Excluded Patterns

The following directories are automatically skipped (regeneratable via package managers/build tools):

| Category | Patterns |
|----------|----------|
| Node.js | `node_modules`, `.pnpm-store` |
| Ruby | `vendor`, `.bundle` |
| Python | `.venv`, `venv`, `__pycache__`, `.pyc`, `.eggs`, `.egg-info` |
| Build | `build`, `dist`, `target`, `out`, `.gradle` |
| Cache | `.next`, `.nuxt`, `.cache`, `.parcel-cache`, `.turbo` |
| Infrastructure | `.terraform`, `.serverless` |

## Usage Examples

### Automatic (Default Behavior)

Simply start Claude in a linked worktree:

```
$ claude
🌳 Synced 2 config files from main: .env .npmrc
```

### Interactive Sync

```
/arborist:tend
```

This prompts for:
1. Source worktree selection
2. Sync mode (all or customize)
3. File selection (if customizing)

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| One-way sync (main → linked) | Main worktree is source of truth; prevents accidental overwrites |
| Copy only if missing | Preserves local customizations; doesn't overwrite existing files |
| Silent by default | Non-intrusive; only outputs when files are actually synced |
| Auto-exclude patterns | Avoids syncing large regeneratable directories |

## Code References

- Worktree detection: `plugins/arborist/hooks/session-start.sh:14-16`
- Main worktree discovery: `plugins/arborist/hooks/session-start.sh:22-24`
- Skip patterns: `plugins/arborist/hooks/session-start.sh:31`
- File discovery: `plugins/arborist/hooks/session-start.sh:34`
- Sync logic: `plugins/arborist/hooks/session-start.sh:44-62`
