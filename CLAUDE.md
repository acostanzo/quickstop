# CLAUDE.md

This file contains instructions and guidelines for Claude (or any AI assistant) working on the Courtney project.

## Project Guidelines

### README Maintenance
- Update README.md whenever changes affect:
  - What the project is or does
  - Setup or installation instructions
  - Core functionality or features
  - Usage examples or API changes
- Keep descriptions focused on current functionality (Phase 1: recording only)
- Avoid mentioning future features that aren't implemented yet

### Project Scope
- **In Scope**: Recording Claude Code conversations to a normalized data store
- **Out of Scope** (for now): Reading/extracting/analyzing the recorded data

### Development Principles
- Think like a stenographer: record what was said/done, not what was thought
- Keep the data structure simple and normalized
- Ensure timestamps are accurate and consistent
- Make speaker identification clear and unambiguous
- Hooks should NEVER block Claude Code operations (always exit 0)
- Fail silently - log errors but don't interrupt the user's workflow

## Architecture

### Project Structure
```
courtney/
├── adapters/           # Database adapter implementations
│   ├── base.py        # Abstract base class
│   └── sqlite.py      # SQLite implementation
├── hooks/             # Claude Code hook scripts
│   └── courtney_hook.py  # Main hook entry point
├── config.py          # Configuration management
└── recorder.py        # Core recording logic

install.py             # Installation script
```

### Database Schema
- **sessions**: Tracks Claude Code sessions with start/end times
- **entries**: Individual transcript entries with speaker, timestamp, and content

### Hook Events
Courtney registers hooks for:
- SessionStart/SessionEnd: Session lifecycle
- UserPromptSubmit: User input (full text, no truncation)
- Stop: AI text responses (full text, no truncation)
- SubagentStop: Subagent final reports (full text, no truncation)

Note: PreToolUse/PostToolUse hooks are NOT used - tool calls are considered "working" not "speaking"

## Future Enhancements
(Not in current scope, but considerations for Phase 2+)
- PostgreSQL/MySQL adapters for remote database support
- Query/search interface for the recorded data
- Export functionality (JSON, CSV, Markdown)
- Analytics and reporting on conversation patterns
- Integration with other AI tools beyond Claude Code
