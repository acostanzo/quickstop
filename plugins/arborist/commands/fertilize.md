---
description: Copy gitignored files from main repo to worktree (feed the tree)
argument-hint: [--from <worktree>] [--dry-run] [--skip <patterns>]
allowed-tools: Bash, Read, Glob, AskUserQuestion
---

# Fertilize Command

Copy gitignored configuration files (like `.env`, configs) from the main repository to the current worktree.

## Parameters

**Arguments**: `$ARGUMENTS`

Parse the following from arguments:
- `--from <worktree>`: Source worktree to copy from (default: main worktree)
- `--dry-run`: Show what would be copied without copying
- `--skip <patterns>`: Comma-separated patterns to skip (e.g., `node_modules,*.log`)

## Your Task

### 1. Verify We're in a Worktree

Check if current directory is a worktree (not the main repo):

```bash
# Get git directory and common directory
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
```

If `$GIT_DIR` equals `$COMMON_DIR`, we're in the main repo - warn user:
```
⚠️  You're in the main repository, not a worktree.
Fertilize copies files INTO worktrees.

Use /arborist:plant to create a worktree first.
```

### 2. Find Main Worktree (Source)

If `--from` specified, use that path.

Otherwise, find the main worktree:
```bash
git worktree list --porcelain | grep -A2 "^worktree" | head -1 | cut -d' ' -f2
```

Or parse:
```bash
git worktree list | head -1 | awk '{print $1}'
```

### 3. Parse .gitignore

Read the `.gitignore` from the source worktree:

```bash
cat <source>/.gitignore
```

Also check for `.git/info/exclude` patterns.

Build list of gitignored patterns.

### 4. Find Existing Gitignored Files

For each pattern in `.gitignore`, find files that exist in the source:

```bash
# Find files matching gitignore patterns
cd <source>
git ls-files --others --ignored --exclude-standard
```

This gives us files that:
- Exist in the source worktree
- Are ignored by git
- Could be copied to the target

### 5. Smart Skip Recommendations

**ALWAYS skip these (don't even list):**
- `node_modules/` - Too large, reinstall instead
- `.git/` - Never copy git internals
- `__pycache__/` - Python will regenerate
- `*.pyc` - Compiled Python
- `vendor/` - Dependencies, reinstall
- `dist/`, `build/`, `out/` - Build artifacts, regenerate
- `.cache/` - Cache directories
- `*.log` - Log files

**RECOMMEND copying:**
- `.env*` - Environment variables (critical!)
- `config/` - Configuration files
- `.env.local`, `.env.development` - Environment files
- `credentials*.json` - Credentials (if not in vault)
- `.idea/`, `.vscode/` - IDE settings (user preference)
- `*.local` - Local overrides

**ASK about:**
- Large files (>10MB)
- Database files (`*.sqlite`, `*.db`)
- Data directories

### 6. Show Preview

Display what will be copied:

```
🧪 Fertilize Preview

Source: /Users/you/project (main)
Target: /Users/you/project-feature (current)

Will copy:
  ✓ .env (1.2 KB)
  ✓ .env.local (0.3 KB)
  ✓ config/database.yml (2.1 KB)
  ✓ .vscode/settings.json (0.8 KB)

Skipping (recommended):
  ✗ node_modules/ (too large - run npm install)
  ✗ .cache/ (will regenerate)
  ✗ *.log (not needed)

⚠️  Large files found:
  ? data/seed.sqlite (45 MB) - Copy this file?
```

If `--dry-run`, stop here.

### 7. Confirm and Copy

Unless `--dry-run`, ask for confirmation:
- Proceed with copy?
- Any additional files to skip?

Then copy files preserving directory structure:

```bash
# For each file to copy
mkdir -p <target>/$(dirname <file>)
cp <source>/<file> <target>/<file>
```

Or use rsync for efficiency:
```bash
rsync -av --files-from=<filelist> <source>/ <target>/
```

### 8. Report Results

```
🧪 Fertilized successfully!

Copied 4 files (4.4 KB total):
  ✓ .env
  ✓ .env.local
  ✓ config/database.yml
  ✓ .vscode/settings.json

Skipped:
  ✗ node_modules/ - Run: npm install
  ✗ __pycache__/ - Will regenerate

Your worktree is ready for development!
```

### 9. Post-Fertilize Recommendations

Remind user about dependency installation:

```
📦 Don't forget to install dependencies:

Node.js:    npm install
Python:     pip install -r requirements.txt
Ruby:       bundle install
Go:         go mod download
```

## Error Handling

- **Not in worktree**: Guide to create one first
- **Source not found**: Help locate main worktree
- **Permission denied**: Check file permissions
- **No gitignored files**: Inform user, nothing to copy

## Example Usage

```
/arborist:fertilize                        # Copy from main worktree
/arborist:fertilize --dry-run              # Preview only
/arborist:fertilize --from ../other-tree   # Copy from specific worktree
/arborist:fertilize --skip "*.db,data/"    # Skip specific patterns
```
