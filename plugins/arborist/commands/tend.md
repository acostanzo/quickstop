---
description: Sync gitignored config files from another worktree
argument-hint: ""
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# Sync gitignored configuration files to current worktree

This command syncs gitignored configuration files (like `.env`, `.npmrc`, local configs) from another worktree to the current one.

## Prerequisites

Before proceeding, verify:
1. Current directory is a git worktree
2. There are other worktrees available to sync from

Run these checks:
```bash
# Check if in a git repo
git rev-parse --git-dir

# List all worktrees
git worktree list
```

If not in a git repo, inform the user and exit.

## Step 1: Identify Available Worktrees

Get the list of all worktrees:
```bash
git worktree list
```

Parse the output to extract:
- Path to each worktree
- Branch name for each worktree
- Identify which is the main worktree (first one listed, or the one without "detached" status)

## Step 2: Ask User to Select Source Worktree

Use AskUserQuestion to present the worktree selection:
- List the **main worktree first** (mark as "Recommended")
- Include other worktrees as additional options
- Show the path for each option in the description

Example format:
```
question: "Which worktree do you want to sync config files from?"
header: "Source"
options:
  - label: "main (Recommended)"
    description: "/path/to/project/main"
  - label: "feature-auth"
    description: "/path/to/project/feature-auth"
```

## Step 3: Get Missing Config Files

After user selects a source, find gitignored files that exist in source but not in current worktree.

Run in the **source** worktree:
```bash
cd <source_path> && git ls-files --others --ignored --exclude-standard
```

Filter out regeneratable directories using these patterns (auto-exclude):
- node_modules, .pnpm-store, vendor, .bundle
- .venv, venv, __pycache__, .pyc, .eggs, .egg-info
- build, dist, target, out, .gradle
- .next, .nuxt, .cache, .parcel-cache, .turbo
- .terraform, .serverless

For each remaining file, check if it exists in the current worktree. Collect the missing ones.

If no missing files found, inform the user:
> ✓ All config files are already synced from <source>.

And exit successfully.

## Step 4: Ask User for Sync Mode

Use AskUserQuestion:
```
question: "Found N config files to sync. How would you like to proceed?"
header: "Sync mode"
options:
  - label: "Sync all (Recommended)"
    description: "Copy all N missing config files"
  - label: "Customize"
    description: "Select which files to sync"
```

## Step 5: If Customize, Show File Selection

Only if user chose "Customize":

Use AskUserQuestion with `multiSelect: true`:
- List each missing file with its size
- Pre-check all files by default (user deselects unwanted ones)

Get file sizes with:
```bash
stat -f%z <file>  # macOS
# or
wc -c < <file>    # portable
```

Example format:
```
question: "Select files to sync:"
header: "Files"
multiSelect: true
options:
  - label: ".env (245 B)"
    description: "Environment variables"
  - label: ".env.local (128 B)"
    description: "Local environment overrides"
  - label: "config/local.json (1.2 KB)"
    description: "Local configuration"
```

## Step 6: Execute Sync

For each selected file:
1. Create the target directory if needed: `mkdir -p <target_dir>`
2. Copy the file preserving permissions: `cp -a <source>/<file> <target>/<file>`

Report results:
```
✓ Synced N files from <source_name>:
  - .env
  - .env.local
  - config/local.json
```

If some files failed to copy, report them separately.

## Error Handling

- If not in a git repo: "This command must be run from within a git repository."
- If only one worktree exists: "No other worktrees found. Create a worktree first with: git worktree add <path> <branch>"
- If source worktree doesn't exist: Handle gracefully if user provides invalid selection

## Notes

- Always preserve file permissions and timestamps when copying
- The sync is one-directional: source → current worktree
- Files are not modified, only copied if missing
- Directories are created as needed
