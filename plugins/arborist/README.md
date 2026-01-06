# Arborist

Expert git worktree management with automatic configuration syncing.

## Features

- **Worktree Status on Start** - Shows a status box when launching Claude inside a linked worktree
- **Worktree Skill** - Comprehensive git worktree guidance including creation, management, repair, and troubleshooting
- **Automatic Config Sync** - Copies gitignored files (like `.env`, IDE settings) to new worktrees
- **Smart Skip Patterns** - Excludes regeneratable files (`node_modules/`, `build/`, etc.) from sync
- **Doctor Command** - Diagnose and repair missing configurations in worktrees

## Installation

Add to your Claude Code plugins:

```bash
# Using plugin directory flag
claude --plugin-dir /path/to/arborist

# Or add to .claude/plugins in your project
```

## Usage

### Creating Worktrees

When you ask Claude to create a worktree, it will:
1. Create the worktree with `git worktree add`
2. Automatically sync gitignored configuration files
3. Display the worktree status

Example prompts:
- "Create a worktree for the feature/auth branch"
- "Set up a worktree to review PR #123"
- "I need to work on a hotfix while keeping my current work"

### Doctor Command

Run `/arborist:doctor` to:
- Check if all gitignored configs are synced from main worktree
- See what files are missing
- Optionally copy missing files

### Worktree Skill

The worktree skill activates when you ask about:
- Creating or managing worktrees
- Working on multiple branches
- Parallel development
- Syncing gitignored files

## Configuration

### .worktreeignore

Create a `.worktreeignore` file in your repository root to customize which gitignored files are **excluded** from syncing:

```
# These files won't be synced to worktrees (they're regeneratable)

# Large dependency directories (defaults)
node_modules/
.venv/

# Project-specific exclusions
.terraform/
*.tfstate*
```

Files NOT matching these patterns will be synced (like `.env`, `.env.local`, IDE configs).

**Location priority:**
1. `<repo>/.worktreeignore` - Can be committed and shared
2. `<repo>/.git/info/worktreeignore` - Local only

### Default Skip Patterns

These patterns are always excluded (regeneratable files):
- `.git/`
- `node_modules/`, `.pnpm-store/`, `vendor/`, `.bundle/`
- `.venv/`, `venv/`, `__pycache__/`
- `build/`, `dist/`, `target/`, `out/`
- `.cache/`, `.parcel-cache/`, `.turbo/`

## Components

| Component | Purpose |
|-----------|---------|
| `skills/worktree/` | Git worktree expertise and guidance |
| `commands/doctor.md` | Diagnose and sync configurations |
| `hooks/` | SessionStart hook for worktree status display |
| `scripts/sync-gitignored.sh` | Sync script for gitignored files |
| `scripts/detect-worktree.sh` | Worktree status detection |

## Requirements

- Git 2.5+ (worktree support)
- Bash 4+ (for scripts)

## Version

2.0.0 - Complete rewrite with skill-based architecture and `.worktreeignore` support
