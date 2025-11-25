---
description: Create a new git worktree (plant a new tree)
argument-hint: <branch-name> [--base <branch>] [--path <dir>]
allowed-tools: Bash, Read, AskUserQuestion
---

# Plant Command

Create a new git worktree for parallel branch development.

## Parameters

**Arguments**: `$ARGUMENTS`

Parse the following from arguments:
- `<branch-name>` (required): The branch name for the worktree
- `--base <branch>`: Base branch to create from (default: current branch)
- `--path <dir>`: Custom path for worktree (default: `../<repo-name>-<branch-slug>`)

## Your Task

### 1. Validate Environment

First, verify we're in a git repository:

```bash
git rev-parse --git-dir 2>/dev/null
```

If not in a repo, inform the user and exit.

### 2. Parse Arguments

Extract branch name and options from `$ARGUMENTS`.

If no branch name provided, ask the user:
- What branch name would you like for this worktree?

### 3. Determine Worktree Path

Default path convention: `../<repo-name>-<branch-slug>`

For example:
- Repo: `myproject`, Branch: `feature/auth` → Path: `../myproject-feature-auth`

If `--path` provided, use that instead.

### 4. Check if Branch Exists

```bash
git show-ref --verify --quiet refs/heads/<branch-name>
```

- If branch exists: Will check it out in new worktree
- If branch doesn't exist: Will create it from base branch

### 5. Create the Worktree

If branch exists:
```bash
git worktree add <path> <branch-name>
```

If branch doesn't exist:
```bash
git worktree add -b <branch-name> <path> <base-branch>
```

### 6. Report Success

Show the user:
```
🌱 Planted worktree successfully!

Branch: <branch-name>
Path: <absolute-path>
Based on: <base-branch>

Next steps:
• cd <path>
• /arborist:fertilize to copy .env and config files
```

### 7. Offer Follow-up

Ask if the user would like to:
1. Fertilize the new worktree (copy gitignored files)
2. Switch to the new worktree

## Error Handling

- **Branch already has worktree**: Inform user and show existing worktree location
- **Path already exists**: Ask to use different path or remove existing
- **Invalid branch name**: Guide user on valid git branch naming
- **Not a git repo**: Clearly state requirement

## Example Usage

```
/arborist:plant feature/user-auth
/arborist:plant hotfix/login-bug --base main
/arborist:plant experiment/new-api --path ~/worktrees/new-api
```
