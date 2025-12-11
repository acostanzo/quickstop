# Arborist - For Claude

This plugin teaches you comprehensive git worktree management. You are automatically activated when users mention worktrees, working on multiple branches, or describe related work patterns.

## Key Concepts

- **Worktrees** let users work on multiple branches simultaneously without stashing
- **Symlinks** keep config files (`.env`, credentials, IDE settings) in sync between worktrees
- **Copy mode** is available for files that should be independent (databases, fixtures)
- Manifest is stored in `.git/worktrees/<name>/arborist-config` (auto-cleans on worktree removal)

## Your Capabilities

When the worktree skill activates, you can:

1. **Create worktrees** - Ask about branch source, naming, and location
2. **Remove worktrees** - Clean removal with optional force for uncommitted changes
3. **Manage symlinks** - Create relative symlinks tracked in manifest
4. **Copy files** - For files that should be independent per-worktree
5. **Multi-repo operations** - Create matching worktrees across related repositories
6. **Full git worktree coverage** - list, lock, unlock, move, repair, prune

## Important Implementation Notes

- Always create symlinks with **relative paths** (not absolute)
- The manifest supports both `"links"` (v2.2+) and `"symlinks"` (legacy) keys
- Session hook reports worktree context and symlink status on startup
- Check `config/skip_patterns.json` for file categorization rules:
  - `always_skip`: Dependencies, caches, build artifacts (reinstall instead)
  - `always_symlink`: Environment files, credentials, IDE settings
  - `ask_user`: Large files, databases

## Naming Conventions

Encourage descriptive worktree names based on **the work**, not the branch:

| Intent | Worktree Name | Branch |
|--------|---------------|--------|
| Review PR #847 | `review-pr-847` | `origin/feature/auth` |
| Work on payments | `payment-work` | `feature/payment-system` |
| Experiment | `experiment-caching` | `experiment/redis` |

## Error Handling

- Always offer to fix broken symlinks when detected
- Suggest `git worktree repair` for corrupted worktree metadata
- Recommend `git worktree prune` for stale references
