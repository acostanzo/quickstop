---
description: Switch to a different git worktree (graft onto another branch)
argument-hint: [worktree-name]
allowed-tools: Bash, Read, AskUserQuestion
---

# Graft Command

Switch your working context to a different worktree.

## Parameters

**Arguments**: `$ARGUMENTS`

Parse the following from arguments:
- `<worktree>` (optional): Worktree name, branch name, or path to switch to

## Your Task

### 1. List All Worktrees

Get worktree information:

```bash
git worktree list --porcelain
```

Parse to extract for each worktree:
- Path
- Branch name
- HEAD commit (abbreviated)

Also get current working directory:
```bash
pwd
```

### 2. Display Worktree Status

Show a formatted list with status indicators:

```
🌳 Available Worktrees:

   PATH                          BRANCH              STATUS
   ─────────────────────────────────────────────────────────
 → /Users/you/project            main                current
   /Users/you/project-feature    feature/auth        clean
   /Users/you/project-hotfix     hotfix/urgent       2 uncommitted

Which worktree would you like to graft to?
```

For each worktree, check status:
```bash
cd <path> && git status --porcelain | wc -l
```

### 3. Handle Selection

If worktree specified in `$ARGUMENTS`:
- Find matching worktree
- Proceed to step 4

If no worktree specified:
- Use AskUserQuestion with available worktrees as options
- Include branch names and paths

### 4. Safety Check Current Worktree

Before switching, check current worktree for uncommitted changes:

```bash
git status --porcelain
```

If uncommitted changes exist:
- List the changes
- Ask if user wants to:
  1. Stash changes before switching
  2. Continue anyway (changes stay in current worktree)
  3. Cancel

### 5. Provide Switch Instructions

Since Claude cannot change the terminal's working directory, provide clear instructions:

```
🌿 Ready to graft to: feature/auth

Run this command to switch:

    cd /Users/you/project-feature-auth

Or if using a shell with directory switching:

    pushd /Users/you/project-feature-auth

Worktree details:
• Branch: feature/auth
• Last commit: abc1234 - "Add auth middleware"
• Status: Clean working directory
```

### 6. Multi-Repo Awareness

If working from a parent directory with multiple repos, show worktrees grouped by repo:

```
🌳 Worktrees by Repository:

backend/
   → /path/backend              main           current
     /path/backend-feature      feature/auth   clean

frontend/
     /path/frontend             main           clean
     /path/frontend-feature     feature/auth   1 uncommitted
```

Detect multi-repo setup:
```bash
# Check if current dir contains multiple git repos
for dir in */; do
  if [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; then
    echo "$dir"
  fi
done
```

## Error Handling

- **No worktrees found**: Only main worktree exists - suggest `/arborist:plant`
- **Worktree not found**: Show available options and ask for selection
- **Invalid path**: Verify path exists and is a worktree

## Example Usage

```
/arborist:graft                    # List and select interactively
/arborist:graft feature/auth       # Switch by branch name
/arborist:graft project-feature    # Switch by directory name
```

## Notes

- Grafting doesn't lose any work - each worktree maintains its own state
- Uncommitted changes stay in their respective worktrees
- This is much faster than stash/checkout/pop workflows
