# Changelog

All notable changes to Arborist will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-12-05

Complete rewrite as a pure skill-based plugin. Arborist is now fully conversational—just describe what you want to do with worktrees and Claude handles the rest.

### Changed

- **BREAKING**: Removed all slash commands in favor of pure conversational interface
- **BREAKING**: Fertilize now uses symlinks instead of copying files (with optional copy mode)
- **BREAKING**: Manifest location moved from worktree root to git metadata directory
  - Linked worktrees: `.git/worktrees/<name>/arborist-config`
  - Main worktree: `.git/arborist-config`
  - This keeps the worktree clean and auto-cleans on `git worktree remove`
- **BREAKING**: Manifest structure changed from `"symlinks"` to `"links"` array with `type` field
- Plugin is now purely skill-based—no commands needed
- Session hook now reports symlink status
- Manifest version bumped to 2.2

### Added

- Full git worktree command coverage (all subcommands and options)
- Symlink-based config management with manifest tracking
- **Copy mode**: Individual files can be copied instead of symlinked
  - Use `"type": "copy"` in manifest or when user requests
  - Useful for database seeds, large binaries that shouldn't sync
- `/arborist:config` command to display current linked config files
- Multi-repo interactive selection for batch operations
- `src/config_manager.py` module for config file operations (symlinks/copies)
- `config/skip_patterns.json` for symlink categorization rules
- Comprehensive test suite (44 tests)
- Smart pattern matching for file categorization
- New functions: `copy_file()`, `create_links()`, `remove_links()`, `get_link_status()`
- Backward-compatible wrappers: `create_symlinks()`, `remove_symlinks()`, `get_symlink_status()`

### Removed

- `/arborist:plant` command (use skill conversationally)
- `/arborist:uproot` command (use skill conversationally)
- `/arborist:graft` command (use skill conversationally)
- `/arborist:fertilize` command (use skill conversationally)
- `/arborist:prune` command (use skill conversationally)
- `commands/` directory

## [1.0.0] - 2025-11-25

Parallel development without the pain. Arborist brings git worktree management to Claude Code, eliminating the constant stash-switch-unstash cycle when working across multiple branches.

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
- Python 3.9+ compatibility
- Comprehensive documentation with usage examples

[2.0.0]: https://github.com/acostanzo/quickstop/releases/tag/arborist-v2.0.0
[1.0.0]: https://github.com/acostanzo/quickstop/releases/tag/arborist-v1.0.0
