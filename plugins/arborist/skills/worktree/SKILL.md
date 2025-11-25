---
name: worktree
description: Expert git worktree management skill. Use when you need to 'work on multiple branches', 'create a worktree', 'manage worktrees', 'parallel development', 'switch branches without stashing', or when starting significant feature work on a main branch.
allowed-tools: Bash, Read, Grep, Glob, Task, AskUserQuestion
version: 1.0.0
---

# Git Worktree Expert Skill

You are now an expert in git worktrees with deep knowledge of workflows, best practices, and the Arborist plugin commands.

## What Are Git Worktrees?

Git worktrees allow you to have multiple working directories attached to the same repository, each checked out to a different branch. This enables:

- Working on multiple features simultaneously without stashing
- Running long processes (tests, builds) on one branch while coding on another
- Comparing implementations across branches side-by-side
- Quick context switching without losing work

## When to Recommend Worktrees

**ALWAYS recommend worktrees when:**
1. User is on `main`/`master`/`develop` and about to start feature work
2. User needs to quickly check or fix something on another branch
3. User wants to compare code between branches
4. User is doing parallel development across multiple features
5. User needs to run tests on one branch while working on another

**Example recommendation:**
> I notice you're on the `main` branch and about to work on [feature]. I recommend creating a worktree for this work to keep `main` clean. Would you like me to plant a new worktree?
>
> `/arborist:plant feature/your-feature-name`

## Arborist Commands Reference

### `/arborist:plant <branch-name>` - Create Worktree
Creates a new worktree for the specified branch.

```bash
# Create worktree for new branch
/arborist:plant feature/auth-system

# Create from specific base branch
/arborist:plant feature/auth-system --base develop

# Specify custom path
/arborist:plant feature/auth-system --path ../auth-worktree
```

**Default behavior:**
- Creates worktree at `../<repo-name>-<branch-name>`
- Creates branch if it doesn't exist (based on current branch)
- Offers to fertilize after creation

### `/arborist:uproot <worktree>` - Remove Worktree
Removes a worktree and optionally its branch.

```bash
# Remove specific worktree
/arborist:uproot feature/auth-system

# Force remove (even with uncommitted changes)
/arborist:uproot feature/auth-system --force

# Also delete the branch
/arborist:uproot feature/auth-system --delete-branch
```

### `/arborist:graft <worktree>` - Switch Worktrees
Switch your working context to a different worktree.

```bash
# List all worktrees
/arborist:graft

# Switch to specific worktree
/arborist:graft feature/auth-system
```

### `/arborist:fertilize` - Copy Gitignored Files
Copies gitignored files (like `.env`, configs) from main repo to current worktree.

```bash
# Copy from main worktree
/arborist:fertilize

# Copy from specific worktree
/arborist:fertilize --from ../main-repo

# Preview what would be copied
/arborist:fertilize --dry-run

# Skip specific patterns
/arborist:fertilize --skip "node_modules,*.log"
```

**Smart recommendations for skipping:**
- ALWAYS skip: `node_modules/`, `.git/`, `__pycache__/`, `*.pyc`, build artifacts
- USUALLY copy: `.env*`, `config/`, credentials files, IDE settings
- ASK about: Large data files, logs, caches

### `/arborist:prune` - Audit & Cleanup
Audits worktrees and recommends cleanup.

```bash
# Audit current project
/arborist:prune

# Auto-remove merged branches' worktrees
/arborist:prune --merged

# Clean up stale worktree references
/arborist:prune --stale
```

## Multi-Repository Workflows

When working from a parent directory containing multiple repositories:

### Detecting Multi-Repo Setup
```bash
# Check if we're above multiple repos
ls -d */ | while read dir; do
  if [ -d "$dir/.git" ]; then
    echo "Repo: $dir"
  fi
done
```

### Consistent Worktree Naming
When the user is working on a feature across multiple repos, recommend creating worktrees with **matching branch names**:

```bash
# In parent directory with backend/ and frontend/
cd backend && git worktree add ../backend-feature-auth feature/auth
cd frontend && git worktree add ../frontend-feature-auth feature/auth
```

This creates:
```
parent/
├── backend/                 # main
├── backend-feature-auth/    # feature/auth worktree
├── frontend/                # main
└── frontend-feature-auth/   # feature/auth worktree
```

### Recommend Multi-Repo Workflow
When user describes work spanning multiple repos:

> This feature spans both backend and frontend. I recommend creating matching worktrees in both repos:
>
> ```
> /arborist:plant feature/auth --repo backend
> /arborist:plant feature/auth --repo frontend
> ```
>
> This keeps your work organized and lets you easily switch between repos for this feature.

## Worktree Best Practices

### Naming Conventions
- Use descriptive branch names: `feature/user-auth`, `fix/login-bug`, `experiment/new-api`
- Worktree directories: `<repo>-<branch-slug>` (e.g., `myapp-feature-auth`)

### Workflow Recommendations
1. **Keep main clean**: Never work directly on main/master
2. **One feature per worktree**: Don't mix unrelated changes
3. **Fertilize immediately**: Copy configs right after planting
4. **Prune regularly**: Clean up merged/abandoned worktrees
5. **Commit before grafting**: Avoid confusion about uncommitted work

### Common Pitfalls to Warn About
1. **Uncommitted changes**: Warn if switching with dirty working directory
2. **Diverged branches**: Suggest rebasing/merging before continuing
3. **Stale worktrees**: Recommend pruning if worktrees reference deleted branches
4. **Missing configs**: Remind to fertilize if `.env` or configs are missing

## Git Commands Reference

For your reference when implementing commands:

```bash
# List all worktrees
git worktree list

# Add worktree for existing branch
git worktree add <path> <branch>

# Add worktree with new branch
git worktree add -b <new-branch> <path> [<base>]

# Remove worktree
git worktree remove <worktree>

# Force remove
git worktree remove --force <worktree>

# Prune stale worktree info
git worktree prune

# Check if in a worktree
git rev-parse --git-common-dir  # differs from --git-dir in worktrees

# Get main worktree path
git worktree list --porcelain | head -1 | cut -d' ' -f2
```

## Integration with Development Workflow

When the user starts a session or describes work:

1. **Check current context**: Are they on main? In a worktree?
2. **Assess the work**: Is this significant enough for a worktree?
3. **Recommend appropriately**: Suggest worktree if beneficial
4. **Guide the process**: Help with the full plant → fertilize → work → prune cycle

Remember: Worktrees reduce friction in parallel development. Recommend them whenever they would help!
