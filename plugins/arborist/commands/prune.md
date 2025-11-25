---
description: Audit worktrees and recommend cleanup (trim dead branches)
argument-hint: [--merged] [--stale] [--all]
allowed-tools: Bash, Read, AskUserQuestion
---

# Prune Command

Audit all worktrees in the project space and recommend which ones can be safely removed.

## Parameters

**Arguments**: `$ARGUMENTS`

Parse the following from arguments:
- `--merged`: Focus on worktrees with merged branches
- `--stale`: Focus on stale/orphaned worktrees
- `--all`: Check all repos in parent directory (multi-repo mode)
- `--auto`: Automatically remove recommended worktrees (with confirmation)

## Your Task

### 1. Discover Worktrees

#### Single Repo Mode (default)
```bash
git worktree list --porcelain
```

#### Multi-Repo Mode (`--all`)
Scan parent directory for all git repos and their worktrees:

```bash
# From parent directory
for dir in */; do
  if [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; then
    echo "=== $dir ==="
    (cd "$dir" && git worktree list)
  fi
done
```

### 2. Analyze Each Worktree

For each worktree, gather:

#### Branch Status
```bash
# Is branch merged into main?
git branch --merged main | grep <branch>

# Is branch merged into develop?
git branch --merged develop | grep <branch>
```

#### Activity
```bash
# Last commit date
git -C <worktree-path> log -1 --format="%cr" 2>/dev/null

# Days since last commit
git -C <worktree-path> log -1 --format="%ct" 2>/dev/null
```

#### Stale Status
```bash
# Check if worktree is locked or prunable
git worktree list --porcelain | grep -A5 <path>
```

#### Uncommitted Changes
```bash
git -C <worktree-path> status --porcelain 2>/dev/null | wc -l
```

### 3. Categorize Worktrees

**Safe to Remove (Green):**
- Branch is merged into main/master/develop
- No uncommitted changes
- Worktree is clean

**Probably Safe (Yellow):**
- Branch merged but has uncommitted changes
- No commits in >30 days
- Stale worktree reference

**Keep (Protected):**
- Main/master/develop branches
- Has uncommitted changes on unmerged branch
- Recent activity (<7 days)

**Requires Attention (Red):**
- Orphaned worktree (branch deleted)
- Locked worktree
- Corrupted state

### 4. Display Audit Report

```
✂️  Worktree Pruning Audit

📁 Repository: /Users/you/project

SAFE TO REMOVE (merged & clean):
  🟢 feature/auth (/Users/you/project-auth)
     Branch merged to main • No uncommitted changes
     Last commit: 2 weeks ago

  🟢 fix/login-bug (/Users/you/project-login)
     Branch merged to main • No uncommitted changes
     Last commit: 1 month ago

PROBABLY SAFE (review recommended):
  🟡 experiment/new-api (/Users/you/project-api)
     Branch NOT merged • No commits in 45 days
     ⚠️  May contain abandoned work

KEEP (active or uncommitted):
  🔵 feature/dashboard (/Users/you/project-dash)
     Branch NOT merged • 3 uncommitted changes
     Last commit: 2 days ago

  ⚪ main (/Users/you/project)
     Main worktree • Protected

REQUIRES ATTENTION:
  🔴 orphaned-tree (/Users/you/project-orphan)
     ⚠️  Branch no longer exists
     Run: git worktree prune

────────────────────────────────────────
Summary: 2 safe to remove, 1 to review, 2 to keep, 1 needs attention
```

### 5. Multi-Repo Report

If `--all` specified, group by repository:

```
✂️  Multi-Repository Worktree Audit

📁 backend/
  🟢 feature/auth - merged, safe to remove
  🔵 main - protected

📁 frontend/
  🟢 feature/auth - merged, safe to remove
  🟡 experiment/ui - 60 days inactive
  🔵 main - protected

────────────────────────────────────────
Total: 2 safe to remove across 2 repos
```

### 6. Offer Actions

Based on analysis, offer options:

```
What would you like to do?

1. Remove all safe worktrees (2 worktrees)
2. Remove safe + probably safe (3 worktrees)
3. Select specific worktrees to remove
4. Just clean up stale references (git worktree prune)
5. Do nothing (just viewing)
```

Use AskUserQuestion for selection.

### 7. Execute Cleanup

If user chooses to remove:

1. Show final confirmation with list
2. Remove worktrees one by one
3. Offer to delete merged branches
4. Run `git worktree prune` to clean references

```bash
# Remove worktree
git worktree remove <path>

# Delete merged branch
git branch -d <branch>

# Clean stale references
git worktree prune
```

### 8. Final Report

```
✂️  Pruning Complete!

Removed worktrees:
  ✓ /Users/you/project-auth (feature/auth)
  ✓ /Users/you/project-login (fix/login-bug)

Deleted branches:
  ✓ feature/auth
  ✓ fix/login-bug

Cleaned stale references: 1

Remaining worktrees: 3
  • /Users/you/project (main)
  • /Users/you/project-dash (feature/dashboard)
  • /Users/you/project-api (experiment/new-api)
```

## Error Handling

- **No worktrees to prune**: Inform user, all clean
- **Permission denied**: Check ownership
- **Locked worktree**: Explain how to unlock
- **Not in git repo**: Guide to correct directory

## Example Usage

```
/arborist:prune                    # Audit current repo
/arborist:prune --merged           # Focus on merged branches
/arborist:prune --stale            # Focus on stale worktrees
/arborist:prune --all              # Audit all repos in parent dir
/arborist:prune --auto             # Auto-remove with confirmation
```
