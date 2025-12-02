# Changelog

All notable changes to the Muxy plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-02

### Added

#### Foundation
- Plugin manifest with MCP integration support
- `/muxy:doctor` command for environment verification
  - Checks tmux installation
  - Verifies MCP server availability
  - Validates template directory

#### Template Management
- `/muxy:template-list` - Display all available templates with details
- `/muxy:template-create` - Interactive template creation wizard
  - Supports window and pane configuration
  - Template variable placeholders
- `/muxy:template-edit` - Modify existing templates
  - Add/edit/delete windows and panes
  - Update metadata
- `/muxy:template-delete` - Remove templates with confirmation

#### Session Management
- `/muxy:session` - Start or attach to sessions from templates
  - Template variable resolution (`{{worktree:*}}`, `{{project_name}}`, etc.)
  - Handles existing session conflicts
  - Full window and pane creation workflow
- `/muxy:kill` - Terminate sessions safely
  - Shows session details before kill
  - Warns about attached clients

#### Pane Operations
- `/muxy:pane-run` - Execute commands in specific panes
  - Interactive session → window → pane selection
  - Shows pane context (command, path, preview)
- `/muxy:pane-read` - Capture and display pane output
  - Configurable capture depth
  - Save to file option
  - Refresh capability

#### Skill
- Muxy skill for tmux orchestration guidance
  - Complete tmux command reference
  - Template schema documentation
  - Best practices

### Template Features
- JSON-based template schema
- Template variables:
  - `{{worktree:branch}}` - Git worktree paths
  - `{{project_name}}` - Current project name
  - `{{date}}` - Current date
  - `{{timestamp}}` - Unix timestamp
- Support for tmux layouts (even-horizontal, main-vertical, tiled, etc.)
- Pane split configuration with size control

### Integration
- Arborist plugin integration for worktree resolution
- MCP server support (optional)
- Direct bash fallback for tmux operations
