---
description: Remove a git worktree (uproot a tree)
argument-hint: <worktree> [--force] [--delete-branch]
allowed-tools: Bash, Read, AskUserQuestion
---

# Uproot Command

Remove a git worktree and optionally delete its branch.

## Parameters

**Arguments**: `$ARGUMENTS`

Parse the following from arguments:
- `<worktree>` (optional): Worktree name, branch name, or path to remove
- `--force`: Remove even if there are uncommitted changes
- `--delete-branch`: Also delete the branch after removing worktree

## Your Task

### 1. List Available Worktrees

If no worktree specified in `$ARGUMENTS`, list all worktrees:

```bash
git worktree list
```

Show the user a formatted list:
```
Available worktrees:
1. /path/to/main [main] (bare/main)
2. /path/to/feature-auth [feature/auth]
3. /path/to/hotfix [hotfix/urgent]

Which worktree would you like to uproot?
```

Use AskUserQuestion to let them select.

### 2. Identify Target Worktree

Match the user's input against:
1. Full path
2. Directory name
3. Branch name

```bash
git worktree list --porcelain
```

Parse to find the matching worktree.

### 3. Safety Checks

#### Check for Uncommitted Changes
```bash
cd <worktree-path> && git status --porcelain
```

If there are uncommitted changes and `--force` not specified:
- List the uncommitted changes
- Ask if user wants to proceed anyway
- Remind them changes will be lost

#### Check if Currently in Worktree
```bash
pwd
```

If user is in the worktree they're trying to remove:
- Warn them they need to cd out first
- Suggest: `cd <main-worktree-path>`

### 4. Remove the Worktree

Without force:
```bash
git worktree remove <worktree-path>
```

With force:
```bash
git worktree remove --force <worktree-path>
```

### 5. Optionally Delete Branch

If `--delete-branch` specified:

Check if branch is merged:
```bash
git branch --merged main | grep <branch-name>
```

If merged:
```bash
git branch -d <branch-name>
```

If not merged, warn and ask for confirmation:
```bash
git branch -D <branch-name>
```

### 6. Report Success

```
🪓 Uprooted worktree successfully!

Removed: <worktree-path>
Branch: <branch-name> (kept|deleted)

Remaining worktrees:
<list remaining worktrees>
```

## Error Handling

- **Worktree not found**: List available worktrees and ask for selection
- **Main worktree**: Cannot remove the main worktree - inform user
- **Locked worktree**: Explain and offer `--force` if appropriate
- **In the worktree**: Guide user to cd out first

## Example Usage

```
/arborist:uproot                           # Interactive selection
/arborist:uproot feature/auth              # By branch name
/arborist:uproot ../myproject-feature-auth # By path
/arborist:uproot feature/auth --force      # Force remove
/arborist:uproot feature/auth --delete-branch  # Also delete branch
```
