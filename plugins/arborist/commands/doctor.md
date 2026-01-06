---
description: Diagnose and sync gitignored files from main worktree
allowed-tools: Read, Bash, Write
---

Diagnose the current git worktree's gitignored file synchronization status.

## Step 1: Detect Worktree Context

Detect worktree status: !`bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-worktree.sh`

If not in a git repository or in the main worktree, explain that the doctor command is for linked worktrees only and exit.

## Step 2: Identify Main Worktree and Current Worktree

Get the main worktree path:
```bash
git worktree list | head -1 | awk '{print $1}'
```

Get current worktree path:
```bash
git rev-parse --show-toplevel
```

## Step 3: Find Gitignored Files in Main Worktree

In the main worktree, find all gitignored files:
```bash
cd MAIN_WORKTREE && git ls-files --others --ignored --exclude-standard
```

## Step 4: Load Skip Patterns

Check for `.worktreeignore` in:
1. Main worktree root: `MAIN_WORKTREE/.worktreeignore`
2. Git info: `MAIN_WORKTREE/.git/info/worktreeignore`

Default skip patterns (files that should NOT be synced):
- `.git/`
- `node_modules/`, `.pnpm-store/`, `vendor/`, `.bundle/`
- `.venv/`, `venv/`, `__pycache__/`, `*.pyc`, `.eggs/`, `*.egg-info/`
- `build/`, `dist/`, `target/`, `out/`, `.gradle/`, `.next/`, `.nuxt/`
- `.cache/`, `.parcel-cache/`, `.turbo/`

## Step 5: Compare and Report

For each gitignored file in the main worktree that doesn't match skip patterns:
1. Check if it exists in the current worktree
2. If missing, add to the "missing files" list with size info

Display a diagnostic report:

```
╭─ Worktree Doctor ──────────────────────────────╮
│  Current: /path/to/linked-worktree             │
│  Main: /path/to/main-worktree                  │
│  Branch: feature/xyz                           │
╰────────────────────────────────────────────────╯

Skip patterns from: .worktreeignore (or <defaults>)

✓ Synced files: X files present
✗ Missing files: Y files

Missing files:
  .env (245 bytes)
  .env.local (128 bytes)
  config/local.json (1.2 KB)

Total missing: Z KB
```

## Step 6: Offer to Sync

If there are missing files, ask the user whether to copy them:

Use AskUserQuestion with options:
- "Copy all missing files" - Sync everything
- "Review individually" - Go through each file
- "Skip for now" - Exit without syncing

If the user chooses to sync, run the sync script:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/sync-gitignored.sh "MAIN_WORKTREE" "CURRENT_WORKTREE"
```

Report completion status with count of files synced.

## Step 7: Handle Edge Cases

- If already fully synced: Report "All gitignored files are in sync!"
- If main worktree is current: Explain doctor is for linked worktrees
- If no gitignored files: Report "No gitignored files found in main worktree"
- If all gitignored match skip patterns: Report "All gitignored files are in skip patterns (regeneratable)"
