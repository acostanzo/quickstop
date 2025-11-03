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

### Distribution

Courtney is distributed as a **Claude Code plugin** for easy installation and management.

### Project Structure
```
quickstop/                          # Marketplace root
├── .claude-plugin/
│   └── marketplace.json           # Quickstop marketplace definition
├── plugins/
│   └── courtney/                  # Courtney plugin
│       ├── .claude-plugin/
│       │   └── plugin.json       # Plugin manifest
│       ├── courtney/             # Python package
│       │   ├── adapters/         # Database adapters
│       │   ├── config.py         # Configuration
│       │   └── recorder.py       # Core recording logic
│       ├── hooks/                # Plugin hooks
│       │   ├── hooks.json        # Hook configuration
│       │   └── courtney_hook.py  # Main hook entry point
│       ├── commands/             # Slash commands
│       │   └── readback.md       # Readback command
│       ├── install.py            # Legacy installation script
│       ├── test_courtney.py      # Test suite
│       ├── README.md             # Plugin documentation
│       └── CLAUDE.md             # This file
├── README.md                      # Marketplace overview
└── CONTRIBUTING.md               # Plugin authoring guide
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

### Hook Data Structure

#### SessionStart
```json
{
  "hook_event_name": "SessionStart",
  "session_id": "uuid-string",
  "transcript_path": "/path/to/session.jsonl",
  "cwd": "/working/directory",
  "source": "startup" | "cli" | "api"
}
```

#### SessionEnd
```json
{
  "hook_event_name": "SessionEnd",
  "session_id": "uuid-string",
  "transcript_path": "/path/to/session.jsonl",
  "cwd": "/working/directory",
  "reason": "prompt_input_exit" | "error" | "timeout"
}
```

#### UserPromptSubmit
```json
{
  "hook_event_name": "UserPromptSubmit",
  "session_id": "uuid-string",
  "transcript_path": "/path/to/session.jsonl",
  "cwd": "/working/directory",
  "permission_mode": "default" | "restrictive",
  "prompt": "full user prompt text"
}
```

#### Stop
```json
{
  "hook_event_name": "Stop",
  "session_id": "uuid-string",
  "transcript_path": "/path/to/session.jsonl",
  "cwd": "/working/directory",
  "permission_mode": "default" | "restrictive",
  "stop_hook_active": false
}
```

#### SubagentStop
```json
{
  "hook_event_name": "SubagentStop",
  "session_id": "uuid-string",
  "transcript_path": "/path/to/session.jsonl",
  "cwd": "/working/directory",
  "permission_mode": "default" | "restrictive",
  "stop_hook_active": false
}
```

The transcript_path points to a JSONL file where each line is a JSON object. Assistant messages have this structure:
```json
{
  "type": "assistant",
  "message": {
    "role": "assistant",
    "content": [
      {
        "type": "text",
        "text": "The actual response text"
      }
    ]
  }
}
```

## Future Enhancements
(Not in current scope, but considerations for Phase 2+)
- PostgreSQL/MySQL adapters for remote database support
- Query/search interface for the recorded data
- Export functionality (JSON, CSV, Markdown)
- Analytics and reporting on conversation patterns
- Integration with other AI tools beyond Claude Code
