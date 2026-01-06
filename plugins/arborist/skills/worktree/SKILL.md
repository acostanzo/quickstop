---
name: Git Worktree Expert
description: This skill should be used when the user asks to "create a worktree", "work on multiple branches", "set up parallel development", "manage worktrees", "git worktree", "switch branches without stashing", "set up a new feature branch", "review a PR in a separate directory", "sync gitignored files", "copy local configs to worktree", or when starting any significant feature work that would benefit from isolated development.
version: 2.0.0
---

# Git Worktree Management

Expert guidance for git worktree operations with automatic synchronization of local configurations between worktrees.

## Worktree Status Detection

Before any worktree operation, detect and display current worktree context:

```bash
# Check if in a git worktree and get details
WORKTREE_INFO=$(git worktree list --porcelain 2>/dev/null | head -20)
CURRENT_DIR=$(pwd)
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")

# Determine if main or linked worktree
if [[ "$GIT_DIR" == *"/.git/worktrees/"* ]]; then
  WORKTREE_TYPE="linked"
  MAIN_WORKTREE=$(git worktree list | head -1 | awk '{print $1}')
else
  WORKTREE_TYPE="main"
  MAIN_WORKTREE="$CURRENT_DIR"
fi
```

Display worktree context in a formatted box when relevant:

```
╭─ Worktree Status ──────────────────────────────╮
│  Type: linked worktree                         │
│  Branch: feature/new-auth                      │
│  Path: /projects/myapp-auth                    │
│  Main: /projects/myapp                         │
╰────────────────────────────────────────────────╯
```

## Creating Worktrees

### Standard Workflow

To create a new worktree with automatic config syncing:

1. **Create the worktree**:
```bash
# For new branch
git worktree add -b feature/name ../project-feature

# For existing branch
git worktree add ../project-hotfix hotfix-branch

# Detached HEAD for exploration
git worktree add --detach ../project-explore HEAD~5
```

2. **Sync gitignored files automatically** using the sync script:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/sync-gitignored.sh "$MAIN_WORKTREE" "../project-feature"
```

This copies all gitignored files from the main worktree to the new one, respecting `.worktreeignore` patterns.

### Best Practices for Worktree Naming

- Use descriptive paths: `../project-feature-auth` not `../wt1`
- Mirror branch structure: branch `feature/login` → path `../project-login`
- Include ticket numbers when relevant: `../project-JIRA-123`

## Syncing Gitignored Files

### The .worktreeignore File

The `.worktreeignore` file controls which gitignored files are **excluded** from syncing between worktrees. Location priority:

1. Repository root: `.worktreeignore` (can be committed/shared)
2. Git directory: `.git/info/worktreeignore` (local only)

### Default Skip Patterns

Files matching these patterns are NOT synced (they're regeneratable):

```
# Version control
.git/

# Package managers & dependencies
node_modules/
.pnpm-store/
vendor/
.bundle/

# Python
.venv/
venv/
__pycache__/
*.pyc
.eggs/
*.egg-info/

# Build outputs
build/
dist/
target/
out/
.gradle/
.next/
.nuxt/

# Caches
.cache/
.parcel-cache/
.turbo/
```

### What Gets Synced

Files that ARE synced (local configs needed for development):
- `.env`, `.env.local`, `.env.development.local`
- IDE settings not in skip patterns
- Local database files
- Custom scripts
- Any gitignored file NOT matching `.worktreeignore` patterns

### Manual Sync

To sync files at any time, use the `/doctor` command or run directly:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/sync-gitignored.sh /path/to/main /path/to/worktree
```

## Listing and Managing Worktrees

### List All Worktrees

```bash
git worktree list
# Output:
# /projects/myapp        abc1234 [main]
# /projects/myapp-auth   def5678 [feature/auth]
# /projects/myapp-fix    789abcd (detached HEAD)

# Verbose output shows lock reasons
git worktree list -v
```

### Remove a Worktree

```bash
# Clean removal
git worktree remove ../project-feature

# Force remove if uncommitted changes exist
git worktree remove -f ../project-feature

# Force remove if locked (use -f twice)
git worktree remove -f -f ../project-locked
```

### Move a Worktree

```bash
git worktree move ../old-path ../new-path
```

**Note**: Cannot move the main worktree or worktrees with submodules.

## Advanced Operations

### Locking Worktrees

Lock to prevent accidental pruning (useful for portable drives):

```bash
git worktree lock --reason "On USB drive" ../portable-work
git worktree unlock ../portable-work
```

### Pruning Stale Entries

Clean up worktree metadata for deleted directories:

```bash
# Preview what would be removed
git worktree prune --dry-run -v

# Actually prune
git worktree prune
```

### Repairing Worktrees

Fix broken connections after manual moves:

```bash
# From main worktree after it was moved
git worktree repair

# Repair specific linked worktrees
git worktree repair /new/path/to/worktree1 /new/path/to/worktree2
```

## Common Patterns

### Emergency Hotfix While Developing

```bash
# Mid-feature and need to fix production? Create a hotfix worktree:
git worktree add -b hotfix/urgent ../project-hotfix main
cd ../project-hotfix
# Make fix, commit, push, create PR
cd -
git worktree remove ../project-hotfix
# Resume feature work without losing any state
```

### PR Review Workflow

```bash
# Review PR without disturbing your work
git fetch origin pull/123/head:pr-123
git worktree add ../project-pr-123 pr-123
cd ../project-pr-123
# Review, test, comment
cd -
git worktree remove ../project-pr-123
```

### Parallel Feature Development

```bash
# Work on multiple features simultaneously
git worktree add -b feature/auth ../project-auth main
git worktree add -b feature/dashboard ../project-dashboard main
# Each worktree has its own working directory, index, and HEAD
```

## Troubleshooting

### "fatal: 'branch' is already checked out"

A branch can only be checked out in one worktree at a time:
```bash
# See where the branch is checked out
git worktree list | grep branch-name

# Either remove that worktree or checkout a different branch there
```

### Missing Gitignored Files in New Worktree

Run the doctor command to diagnose and fix:
```
/arborist:doctor
```

Or manually sync:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/sync-gitignored.sh /main/worktree /target/worktree
```

### Worktree Shows as Stale

The worktree directory was deleted without using `git worktree remove`:
```bash
git worktree prune
```

### Broken Worktree After Manual Move

```bash
# From the moved main worktree
git worktree repair

# Or specify the new paths explicitly
git worktree repair /new/path/to/linked
```

## Important Concepts

### Shared vs Per-Worktree

**Shared across all worktrees**:
- All branches and tags (`refs/`)
- Commit history and objects
- Repository configuration

**Per-worktree (separate)**:
- `HEAD` (current checkout)
- `index` (staging area)
- Working directory files

### Directory Structure

```
main-repo/
├── .git/                    # Full git directory
│   ├── worktrees/           # Linked worktree metadata
│   │   └── feature-auth/
│   │       ├── HEAD
│   │       ├── index
│   │       └── gitdir
│   └── ...

linked-worktree/
├── .git                     # File pointing to main .git/worktrees/name
├── src/
└── ...
```

## Plugin Scripts

Located at `${CLAUDE_PLUGIN_ROOT}/scripts/`:

- **`sync-gitignored.sh`** - Sync gitignored files between worktrees
- **`detect-worktree.sh`** - Get current worktree status as JSON or formatted box
