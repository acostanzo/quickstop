# Arborist

Git worktree management with gardening-themed commands. Plant, graft, fertilize, prune, and uproot worktrees with ease.

## Overview

Arborist helps you work efficiently with git worktrees - allowing parallel development across multiple branches without the hassle of stashing and switching. Think of your repository as a tree, with worktrees as branches you can tend to independently.

## Features

- **Worktree Skill**: Claude understands worktrees and recommends them for appropriate workflows
- **Session Awareness**: Know which worktree you're in when starting a session
- **Multi-Repo Support**: Manage worktrees across related repositories consistently
- **Gardening Commands**: Intuitive, themed commands for all worktree operations

## Requirements

- Git 2.15+ (for worktree support)
- Claude Code with plugin support
- Python 3.9+ (for session hooks)

## Installation

### From Quickstop Marketplace

```bash
# Add the Quickstop marketplace
/plugin marketplace add acostanzo/quickstop

# Install Arborist
/plugin install arborist@quickstop
```

Restart Claude Code to activate the plugin.

### From Local Clone

```bash
# Clone the repository
git clone https://github.com/acostanzo/quickstop.git

# Add as local marketplace
/plugin marketplace add ./quickstop

# Install Arborist
/plugin install arborist@quickstop
```

## Commands

### `/arborist:plant <branch-name>` - Create Worktree

Plant a new worktree for parallel development.

```bash
# Create worktree for a new feature
/arborist:plant feature/user-auth

# Base on a specific branch
/arborist:plant hotfix/urgent --base main

# Custom path
/arborist:plant feature/api --path ~/worktrees/api-work
```

### `/arborist:uproot [worktree]` - Remove Worktree

Remove a worktree when you're done with it. If no worktree is specified, provides an interactive selection menu.

```bash
# Interactive selection
/arborist:uproot

# Remove specific worktree
/arborist:uproot feature/auth

# Force remove with uncommitted changes
/arborist:uproot feature/auth --force

# Also delete the branch
/arborist:uproot feature/auth --delete-branch
```

### `/arborist:graft [worktree]` - Switch Worktrees

Switch your working context to a different worktree.

```bash
# List all worktrees and select
/arborist:graft

# Switch to specific worktree
/arborist:graft feature/dashboard
```

### `/arborist:fertilize` - Copy Gitignored Files

Copy configuration files (.env, configs) from main repo to your worktree.

```bash
# Copy from main worktree
/arborist:fertilize

# Preview what would be copied
/arborist:fertilize --dry-run

# Skip specific patterns
/arborist:fertilize --skip "*.db,data/"

# Copy from a different worktree
/arborist:fertilize --from ../other-worktree
```

### `/arborist:prune` - Audit & Cleanup

Audit worktrees and get cleanup recommendations.

```bash
# Audit current repo
/arborist:prune

# Focus on merged branches
/arborist:prune --merged

# Audit all repos in parent directory
/arborist:prune --all
```

## Skill Usage

The worktree skill activates automatically when you mention phrases like **"work on multiple branches"**, **"create a worktree"**, **"parallel development"**, or **"switch branches without stashing"**. Just describe what you need in natural language.

When activated, the skill will:

- Recommend worktrees when starting feature work on main/master
- Guide you through the plant → fertilize → work → prune lifecycle
- Help manage worktrees across multiple related repositories
- Advise on which gitignored files to copy or skip

## Session Notifications

When you start a Claude Code session, Arborist tells you where you are:

```
Arborist: Working in worktree 'myproject-feature' (branch: feature/auth)
   Main repo: /Users/you/myproject
   3 worktrees available
```

## Multi-Repository Workflows

When working from a parent directory containing multiple repos (e.g., `backend/` and `frontend/`), Arborist helps create matching worktrees:

```
parent/
├── backend/                 # main
├── backend-feature-auth/    # feature/auth worktree
├── frontend/                # main
└── frontend-feature-auth/   # feature/auth worktree
```

Use `/arborist:prune --all` to audit worktrees across all repos.

## Why Worktrees?

Git worktrees let you:

1. **Work on multiple features** without stashing uncommitted work
2. **Run tests/builds** on one branch while coding on another
3. **Compare implementations** side-by-side
4. **Context switch instantly** - just `cd` to another directory
5. **Keep main clean** - never accidentally commit to the wrong branch

## License

MIT
