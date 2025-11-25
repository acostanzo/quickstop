# Changelog

All notable changes to Arborist will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-25

### Added

- Initial release of Arborist - git worktree management for Claude Code
- **Commands**:
  - `/arborist:plant` - Create new worktrees with optional branch creation
  - `/arborist:uproot` - Safely remove worktrees with uncommitted change detection
  - `/arborist:graft` - Switch between worktrees seamlessly
  - `/arborist:fertilize` - Copy gitignored files (node_modules, .env, etc.) between worktrees
  - `/arborist:prune` - Audit worktrees and clean up stale ones
- **Hooks**:
  - SessionStart hook for automatic worktree context detection
- **Skills**:
  - Worktree expert skill for guided worktree operations
- Multi-repository support for managing worktrees across projects
- Interactive command fallbacks when arguments not provided
