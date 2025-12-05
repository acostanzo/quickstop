---
name: worktree
description: Expert git worktree management skill. Use when you need to 'work on multiple branches', 'create a worktree', 'manage worktrees', 'parallel development', 'switch branches without stashing', 'set up a new feature', 'review a PR', 'symlink config files', 'link gitignored files', 'clean up worktrees', or when starting significant feature work.
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, AskUserQuestion
version: 2.0.0
---

# Git Worktree Expert Skill

You are now an expert in git worktrees. This skill provides comprehensive knowledge of git worktree commands, symlink-based configuration management, and multi-repository workflows.

## Quick Context Check

Before any worktree operation, detect the current context:

```bash
# Check if in a git repository
git rev-parse --git-dir 2>/dev/null || echo "NOT_A_REPO"

# Check if in main repo or worktree
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
# If GIT_DIR != COMMON_DIR, we're in a worktree

# Get current branch
git rev-parse --abbrev-ref HEAD

# List all worktrees
git worktree list
```

## What Are Git Worktrees?

Git worktrees allow multiple working directories attached to a single repository, each checked out to a different branch. This enables:

- Working on multiple features simultaneously without stashing
- Running long processes (tests, builds) on one branch while coding on another
- Comparing implementations across branches side-by-side
- Quick context switching without losing work

### Architecture

```
main-repo/                          # Main worktree
├── .git/                           # Full git directory
│   └── worktrees/                  # Linked worktree metadata
│       ├── feature-auth/
│       └── review-pr-847/
└── src/

../main-repo-feature-auth/          # Linked worktree
├── .git                            # File pointing to main .git/worktrees/feature-auth
└── src/

../main-repo-review-pr-847/         # Another linked worktree
├── .git                            # File pointing to main .git/worktrees/review-pr-847
└── src/
```

All worktrees share:
- Object database (commits, blobs, trees)
- Refs (branches, tags)
- Configuration

Each worktree has its own:
- Working directory
- Index (staging area)
- HEAD

---

## Git Worktree Commands Reference

### git worktree add

Create a new working tree.

```bash
git worktree add [options] <path> [<commit-ish>]
```

| Option | Description | Example |
|--------|-------------|---------|
| `-b <branch>` | Create new branch | `git worktree add -b feature/auth ../wt-auth` |
| `-B <branch>` | Create or reset branch | `git worktree add -B hotfix ../wt-hotfix` |
| `-d` / `--detach` | Detached HEAD mode | `git worktree add -d ../wt-v1 v1.0.0` |
| `--checkout` | Checkout after adding (default) | |
| `--no-checkout` | Don't checkout | `git worktree add --no-checkout ../wt-bare` |
| `--orphan <branch>` | New orphan branch (no history) | `git worktree add --orphan gh-pages ../docs` |
| `--guess-remote` | Base on remote-tracking branch | |
| `--track` | Set upstream relationship | |
| `--no-track` | Don't set upstream | |
| `--lock` | Lock worktree after creation | `git worktree add --lock ../wt-usb` |
| `-f` / `--force` | Override safety checks | |
| `-q` / `--quiet` | Suppress feedback | |

**Common patterns:**

```bash
# New feature branch from current HEAD
git worktree add -b feature/payment ../repo-payment

# New feature branch from main
git worktree add -b feature/auth ../repo-auth main

# Checkout existing branch
git worktree add ../repo-hotfix hotfix/urgent

# Checkout specific commit (detached)
git worktree add -d ../repo-v1 v1.0.0

# Checkout remote branch
git worktree add ../repo-review origin/feature/their-work
```

### git worktree list

Show all worktrees.

```bash
git worktree list [options]
```

| Option | Output | Use Case |
|--------|--------|----------|
| (none) | Human readable | Interactive use |
| `-v` / `--verbose` | With prunable info | Debugging |
| `--porcelain` | Machine readable | Scripting |
| `-z` | NUL-terminated | With porcelain for safety |

**Output format:**

```
/Users/dev/project           abc1234 [main]
/Users/dev/project-feature   def5678 [feature/auth]
/Users/dev/project-review    ghi9012 [origin/feature/their-pr] locked
```

**Porcelain format:**

```
worktree /Users/dev/project
HEAD abc1234def5678
branch refs/heads/main

worktree /Users/dev/project-feature
HEAD def5678abc1234
branch refs/heads/feature/auth
```

### git worktree lock / unlock

Prevent or allow automatic pruning.

```bash
git worktree lock [--reason <string>] <worktree>
git worktree unlock <worktree>
```

**Use cases:**
- Worktree on removable media (USB drive)
- Worktree on network share
- Important long-running experiment

```bash
# Lock with reason
git worktree lock --reason "On USB drive" ../project-usb

# Check lock status
git worktree list -v

# Unlock
git worktree unlock ../project-usb
```

### git worktree move

Relocate a worktree.

```bash
git worktree move <worktree> <new-path>
```

**Limitations:**
- Cannot move main worktree
- Cannot move locked worktrees (must unlock first)
- Destination must not exist

```bash
# Move worktree to new location
git worktree move ../old-location ../new-location
```

### git worktree remove

Delete a linked worktree.

```bash
git worktree remove [options] <worktree>
```

| Option | Description |
|--------|-------------|
| `-f` / `--force` | Remove even with uncommitted changes |

**Cannot remove:**
- Main worktree
- Worktree with uncommitted changes (without --force)
- Locked worktrees (must unlock first)

```bash
# Safe remove (fails if dirty)
git worktree remove ../project-feature

# Force remove
git worktree remove --force ../project-feature
```

### git worktree prune

Clean up stale worktree entries.

```bash
git worktree prune [options]
```

| Option | Description |
|--------|-------------|
| `-n` / `--dry-run` | Show what would be pruned |
| `-v` / `--verbose` | Report all removals |
| `--expire <time>` | Only prune older than time |

```bash
# Preview
git worktree prune --dry-run

# Clean up
git worktree prune -v
```

### git worktree repair

Fix corrupted worktree links.

```bash
git worktree repair [<path>...]
```

**When to use:**
- After manually moving worktree directories
- After moving main repository
- When `git worktree list` shows errors

```bash
# Repair all from main worktree
git worktree repair

# Repair specific worktree
git worktree repair /path/to/moved/worktree
```

---

## Worktree Operations

When the user wants to work with worktrees, guide them through these operations conversationally.

### Creating a Worktree

When user says things like:
- "I need to work on [feature]"
- "Create a worktree for..."
- "Set up a new branch for..."
- "I want to review PR #..."

**Workflow:**

1. **Understand the work**: Ask what they're working on (feature, bugfix, review, experiment)
2. **Determine branch strategy**: New branch or existing? Base branch?
3. **Choose naming**: Worktree name should describe THE WORK, not the branch
4. **Create worktree**: Use appropriate git worktree add command
5. **Offer to symlink**: After creation, offer to link gitignored files
6. **Provide next steps**: cd command, reminder about dependencies

**Naming Rules:**

| Work Type | Pattern | Examples |
|-----------|---------|----------|
| Feature | `feature-<name>` | `feature-payment`, `feature-auth-flow` |
| Bug fix | `fix-<issue>` | `fix-login-crash`, `fix-422-error` |
| PR review | `review-<id>` | `review-pr-847`, `review-sarahs-auth` |
| Hotfix | `hotfix-<desc>` | `hotfix-prod-memory` |
| Experiment | `experiment-<name>` | `experiment-redis-cache` |
| Release | `release-<version>` | `release-v2.1` |

**Anti-pattern - NEVER do this:**
```bash
# Bad: worktree named same as branch
git worktree add ../feature/auth feature/auth  # Confusing!
```

**Good pattern:**
```bash
# Good: worktree describes the work context
git worktree add -b feature/auth ../auth-work
```

### Removing a Worktree

When user says things like:
- "Remove the worktree"
- "Delete the old worktree"
- "I'm done with this worktree"

**Workflow:**

1. **List worktrees**: Show current worktrees with status
2. **Check for uncommitted changes**: Warn if dirty
3. **Confirm removal**: Ask for confirmation
4. **Remove worktree**: Use git worktree remove
5. **Optionally delete branch**: Ask if branch should also be deleted

```bash
# Check for uncommitted changes first
git -C <worktree-path> status --porcelain

# Remove worktree
git worktree remove <path>

# Optionally delete branch
git branch -d <branch-name>  # Safe delete (only if merged)
git branch -D <branch-name>  # Force delete
```

### Switching Worktrees

When user says things like:
- "Switch to the other worktree"
- "Go to the feature worktree"
- "Which worktrees do I have?"

**Important:** Claude cannot change the terminal's working directory. Provide the cd command for the user.

**Workflow:**

1. **List worktrees**: Show all with branch info and status
2. **Provide cd command**: Give the exact command to run
3. **Note any issues**: Uncommitted changes, locked status, etc.

```bash
# List worktrees with details
git worktree list

# User must run:
cd /path/to/worktree
```

### Cleaning Up Worktrees

When user says things like:
- "Clean up my worktrees"
- "Remove merged worktrees"
- "Prune old worktrees"

**Workflow:**

1. **Audit worktrees**: List all with merge status
2. **Categorize by safety**:
   - Safe: Merged, clean
   - Caution: Merged but dirty, or very old
   - Keep: Active branches
3. **Offer removal options**: All safe, selected, or specific
4. **Execute removal**: With confirmation

```bash
# Check if branch is merged into main
git branch --merged main | grep <branch>

# Get last commit date
git -C <worktree> log -1 --format="%ar"

# Check for changes
git -C <worktree> status --porcelain | wc -l
```

---

## Symlink-Based Config Management

When creating a worktree, gitignored files (like `.env`, config files) don't exist in the new location. Use symlinks to link them from the main repository.

### Why Symlinks (Not Copies)

| Approach | Pros | Cons |
|----------|------|------|
| **Copying** | Independent files | Gets out of sync, duplicates data |
| **Symlinks** | Single source of truth, instant sync | Requires main repo to exist |

**Symlinks win because:**
- Edit in one place, reflected everywhere
- No synchronization needed
- No disk duplication
- Visible relationship (`ls -la` shows links)

### Symlink Categories

**ALWAYS SYMLINK (shared configuration):**
- `.env`, `.env.local`, `.env.*` - Environment variables
- `credentials*.json`, `serviceAccount*.json` - Credentials
- `*.pem`, `*.key` - Certificates and keys
- `.npmrc`, `.yarnrc`, `.yarnrc.yml` - Package manager auth
- `.nvmrc`, `.node-version`, `.tool-versions` - Version managers
- `.vscode/`, `.idea/` - IDE settings
- `config/`, `conf/` - Configuration directories

**NEVER SYMLINK (regenerate instead):**
- `node_modules/` - Run `npm install`
- `vendor/` - Run `composer install` / `go mod download`
- `__pycache__/`, `*.pyc`, `.venv/`, `venv/` - Python artifacts
- `target/` - Rust/Java build output
- `dist/`, `build/`, `out/` - Build artifacts
- `.next/`, `.nuxt/`, `.svelte-kit/` - Framework builds
- `coverage/`, `.nyc_output/` - Test coverage
- `.cache/`, `tmp/`, `temp/` - Caches
- `*.log`, `logs/` - Log files
- `.git/` - Never touch git internals

**ASK USER:**
- Files > 10MB
- Database files (`*.sqlite`, `*.db`)
- Data directories not in standard patterns

### Creating Symlinks

When user says things like:
- "Link my config files"
- "Symlink the environment files"
- "I need my .env in this worktree"
- "Fertilize this worktree"

**Workflow:**

1. **Verify context**: Must be in a worktree (not main repo)
2. **Find main worktree**: Get the source for symlinks
3. **Discover gitignored files**: Find what exists in main
4. **Categorize files**: Apply skip/symlink/ask rules
5. **Show preview**: What will be linked
6. **Create symlinks**: With relative paths
7. **Write manifest**: Track what was linked
8. **Remind about dependencies**: npm install, etc.

```bash
# Verify we're in a worktree
GIT_DIR=$(git rev-parse --git-dir)
COMMON_DIR=$(git rev-parse --git-common-dir)
if [ "$GIT_DIR" = "$COMMON_DIR" ]; then
  echo "You're in the main repo, not a worktree"
  exit 1
fi

# Find main worktree
MAIN_WORKTREE=$(git worktree list --porcelain | head -1 | cut -d' ' -f2)

# Get gitignored files in main
cd "$MAIN_WORKTREE"
git ls-files --others --ignored --exclude-standard

# Create symlink with relative path
# From worktree, link to main
ln -s ../main-repo/.env .env

# Create parent directories if needed
mkdir -p config
ln -s ../../main-repo/config/database.yml config/database.yml
```

### Symlink Manifest

The manifest is stored in the git metadata directory, **not** the worktree root. This keeps
the worktree clean and the manifest gets automatically removed with `git worktree remove`.

Location:
- **Linked worktrees**: `.git/worktrees/<worktree-name>/arborist-config`
- **Main worktree**: `.git/arborist-config`

To find the manifest location:
```bash
MANIFEST="$(git rev-parse --git-dir)/arborist-config"
```

Manifest format:
```json
{
  "version": "2.2",
  "worktree_path": "/Users/dev/project-feature",
  "source_worktree": "/Users/dev/project",
  "created_at": "2025-01-15T10:30:00Z",
  "links": [
    {
      "target": ".env",
      "source": "../project/.env",
      "type": "symlink"
    },
    {
      "target": "config/database.yml",
      "source": "../../project/config/database.yml",
      "type": "symlink"
    },
    {
      "target": "seed_data.db",
      "source": "../project/seed_data.db",
      "type": "copy"
    }
  ]
}
```

**Link types:**
- `symlink` (default): Creates a symbolic link. Changes in either location are reflected in both.
- `copy`: Creates an independent copy. The file can be modified without affecting the original.

### Removing Symlinks

When user says things like:
- "Unlink the config files"
- "Remove the symlinks"
- "Clean up symlinks"

```bash
# Find manifest in git directory
MANIFEST="$(git rev-parse --git-dir)/arborist-config"
if [ -f "$MANIFEST" ]; then
  # Parse manifest and remove symlinks
  # Then remove manifest
  rm "$MANIFEST"
fi
```

### Checking Symlink Status

```bash
# Find all symlinks in worktree
find . -type l -ls

# Check if specific file is a symlink
test -L .env && echo "Is symlink" || echo "Not symlink"

# Get symlink target
readlink .env

# Check if symlink is broken
test -L .env && test -e .env && echo "Valid" || echo "Broken"
```

---

## Multi-Repository Workflows

When working in a parent directory containing multiple related repositories, create matching worktrees across all of them.

### Detecting Multi-Repo Setup

When user is in a parent directory:

```bash
# Find all git repos (not worktrees) in current directory
for dir in */; do
  if [ -d "$dir/.git" ]; then
    # This is a main repository
    branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
    echo "Repo: $dir (branch: $branch)"
  elif [ -f "$dir/.git" ]; then
    # This is a worktree - skip
    continue
  fi
done
```

### Interactive Selection

Use AskUserQuestion to let user choose repositories:

```
Found 3 repositories:

1. backend/ (main)
2. frontend/ (main)
3. shared-lib/ (develop)

Which repositories should I create worktrees for?
- Select specific: 1,2
- All: 1,2,3
```

### Creating Matching Worktrees

**Naming pattern:** `<repo-name>-<work-description>`

```
parent/
├── backend/                        # Main repo
├── backend-payment-work/           # Worktree
├── frontend/                       # Main repo
├── frontend-payment-work/          # Worktree
└── shared-lib/                     # Main repo (not included)
```

**Workflow:**

1. **Detect repos**: Scan parent directory
2. **Let user select**: Which repos to include
3. **Get work description**: What are they working on
4. **Get base branches**: Per repo (or use defaults)
5. **Create worktrees**: In each selected repo
6. **Offer to symlink**: For each worktree

```bash
# For each selected repo
for repo in backend frontend; do
  cd "$parent/$repo"
  git worktree add -b feature/payment "../${repo}-payment-work" main
done
```

---

## Best Practices

### Worktree Lifecycle

1. **Plant** - Create worktree for new work
2. **Symlink** - Link gitignored files from main
3. **Work** - Develop, commit, push
4. **Prune** - Remove when merged/done

### Naming Strategy

The worktree name describes **THE WORK**, not the branch.

| User Intent | Worktree Name | Branch Name |
|-------------|---------------|-------------|
| "Review PR #847" | `review-pr-847` | `origin/feature/auth` |
| "Work on payments" | `payment-work` | `feature/payment-system` |
| "Quick hotfix" | `hotfix-urgent` | `hotfix/memory-leak` |
| "Try new approach" | `experiment-caching` | `experiment/redis-cache` |

### When to Recommend Worktrees

**ALWAYS suggest worktrees when:**
- User is on `main`/`master`/`develop` and about to start feature work
- User needs to quickly check or fix something on another branch
- User wants to compare code between branches
- User is doing parallel development across multiple features
- User needs to run tests on one branch while working on another

**Example suggestion:**
> I notice you're on the `main` branch and about to work on [feature]. I recommend creating a worktree for this to keep `main` clean. Want me to set that up?

### Common Pitfalls

1. **Uncommitted changes when switching**: Always commit or stash before context switching
2. **Diverged branches**: Suggest rebasing/merging before continuing
3. **Stale worktrees**: Recommend pruning if worktrees reference deleted branches
4. **Missing configs**: Always symlink after creating a worktree
5. **Naming worktree same as branch**: This is confusing - use work-based names
6. **Forgetting to install dependencies**: Remind about npm install, pip install, etc.

---

## Conversational Examples

| User Says | What To Do |
|-----------|------------|
| "I need to work on the payment feature" | Create worktree, symlink configs, provide next steps |
| "Set up a worktree for reviewing PR #847" | Fetch PR branch, create worktree named `review-pr-847` |
| "Link my config files to this worktree" | Symlink gitignored files from main |
| "Remove the old worktree" | List worktrees, confirm, remove safely |
| "Clean up my merged worktrees" | Audit, show merged ones, offer to remove |
| "Work on auth in both backend and frontend" | Multi-repo detection, create matching worktrees |
| "Lock this worktree" | Lock with reason, confirm status |
| "Fix my broken worktree links" | Run git worktree repair |
| "Move this worktree to a different location" | Check locks, run git worktree move |
| "Which worktrees do I have?" | List all worktrees with status info |

---

## Post-Operation Reminders

After creating a worktree:

```
Worktree created! Next steps:

1. Switch to it:
   cd /path/to/worktree

2. Install dependencies:
   npm install          # Node.js
   pip install -r requirements.txt  # Python
   bundle install       # Ruby
   go mod download      # Go

3. Your configs are symlinked from main.
```

After symlinking:

```
Symlinks created:
  -> .env
  -> .vscode/settings.json
  -> config/database.yml

Skipped (run installers):
  x node_modules/ - npm install
  x vendor/ - composer install

Your worktree is ready for development!
```
