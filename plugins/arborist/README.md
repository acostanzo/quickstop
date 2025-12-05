# Arborist

Expert git worktree management through natural conversation. Create worktrees, symlink configs, and work across multiple repositories effortlessly.

## Overview

Arborist is a **skill-based plugin** that teaches Claude everything about git worktrees. Instead of memorizing commands, just describe what you want in natural language:

- "I need to work on the payment feature"
- "Set up a worktree for reviewing PR #847"
- "Link my config files to this worktree"
- "Clean up my old worktrees"

## v2.0 Highlights

- **Pure conversational interface** - No slash commands needed
- **Symlink-based configs** - Links gitignored files instead of copying
- **Multi-repo support** - Create matching worktrees across related repositories
- **Full git worktree coverage** - All subcommands and options

## Requirements

- Git 2.15+ (for worktree support)
- Claude Code with plugin support
- Python 3.9+ (for hooks)

## Installation

### From Quickstop Marketplace

```bash
# Add the Quickstop marketplace
/plugin marketplace add acostanzo/quickstop

# Install Arborist
/plugin install arborist@quickstop
```

Restart Claude Code to activate.

## How It Works

Arborist activates automatically when you mention worktrees or describe related work. The skill understands:

### Creating Worktrees

Just say what you want to work on:

```
You: "I need to work on the auth feature"

Claude: I'll create a worktree for that. Let me set up `auth-work` based on main...
        [Creates worktree, offers to symlink configs]
```

### Symlinking Config Files

Instead of copying `.env` and config files (which get out of sync), Arborist creates symlinks:

```
main-repo/.env           # Original file (source of truth)
worktree/.env -> ../main-repo/.env  # Symlink - always in sync
```

Say things like:
- "Link my config files"
- "Symlink the environment files"
- "I need my .env in this worktree"

For files that should be independent (like database seeds), request a copy instead:
- "Copy the seed database to the worktree"
- "I need a copy of data.db, not a symlink"

### Multi-Repo Projects

When working in a parent directory with multiple repos:

```
You: "Create worktrees for the payment feature in both backend and frontend"

Claude: Found 2 repositories. Creating matching worktrees...
        - backend-payment-work/
        - frontend-payment-work/
```

### Cleanup

```
You: "Clean up my old worktrees"

Claude: Let me audit your worktrees...
        [Shows merged/stale worktrees, offers to remove]
```

## What Gets Linked

**Always symlinked (shared, stays in sync):**
- `.env`, `.env.local`, `.env.*` - Environment variables
- `credentials*.json` - Credentials
- `.npmrc`, `.yarnrc` - Package manager configs
- `.vscode/`, `.idea/` - IDE settings
- `config/` - Configuration directories

**Copy on request (independent files):**
- Database seeds, test fixtures
- Large binary files you might modify per-worktree
- Any file where you explicitly ask for "copy" instead of "symlink"

**Never linked (reinstall instead):**
- `node_modules/` - Run `npm install`
- `vendor/` - Run `composer install`
- `dist/`, `build/` - Build output
- `.cache/` - Caches

## Session Notifications

When you start a session, Arborist shows your context:

```
Arborist: In worktree 'myproject-auth' (feature/auth)
   Main: /Users/you/myproject
   Symlinks: 5 files linked
   3 worktrees available
```

## Git Worktree Commands

The skill knows all git worktree operations:

| Operation | Example Request |
|-----------|-----------------|
| Create | "Create a worktree for feature X" |
| Remove | "Remove the old worktree" |
| List | "Which worktrees do I have?" |
| Lock | "Lock this worktree" |
| Unlock | "Unlock the worktree" |
| Move | "Move this worktree to a different location" |
| Repair | "Fix my broken worktree links" |
| Prune | "Clean up stale worktree references" |

## Why Worktrees?

Git worktrees let you:

1. **Work on multiple features** without stashing
2. **Run tests/builds** on one branch while coding on another
3. **Compare implementations** side-by-side
4. **Context switch instantly** - just `cd` to another directory
5. **Keep main clean** - never accidentally commit to the wrong branch

## Worktree Naming

Arborist encourages descriptive names based on **the work**, not the branch:

| Intent | Worktree Name | Branch Name |
|--------|---------------|-------------|
| "Review PR #847" | `review-pr-847` | `origin/feature/auth` |
| "Work on payments" | `payment-work` | `feature/payment-system` |
| "Try caching approach" | `experiment-caching` | `experiment/redis` |

## Commands

| Command | Description |
|---------|-------------|
| `/arborist:config` | Show current worktree's linked config files |

## File Structure

```
arborist/
├── .claude-plugin/plugin.json    # Plugin manifest
├── commands/config.md            # Config display command
├── skills/worktree/SKILL.md      # Comprehensive skill
├── hooks/session_start.py        # Session context detection
├── src/config_manager.py         # Config file operations
├── config/skip_patterns.json     # Symlink categorization
└── test_arborist.py              # Tests
```

## License

MIT
