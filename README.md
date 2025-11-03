# Courtney

Your agentic workflow stenographer for Claude Code.

## What is Courtney?

Courtney is a Claude Code hook that records your AI conversations in a clean, normalized format. Like a stenographer in a courtroom, Courtney captures only what was explicitly said and done—not the internal reasoning or context building that happens behind the scenes.

## What Gets Recorded

Courtney logs only what was *said* in the conversation:
- **User prompts** - Full text of what you asked (no truncation)
- **AI responses** - Full text responses from the assistant (no truncation)
- **Subagent reports** - Final reports from subagent tasks (no truncation)

Courtney does NOT record:
- Tool calls and their results (the "thinking" and "working" behind the scenes)
- Internal reasoning or context building

Each entry includes:
- **Timestamp** - when it occurred
- **Transcript** - the actual content (full, never truncated)
- **Speaker** - either "user" or "agent"
- **Metadata** - JSON with additional context (e.g., response type)

## Installation

### Prerequisites
- Python 3.7 or higher
- Claude Code installed and configured

### Quick Install

1. Clone or download this repository:
```bash
git clone https://github.com/yourusername/Courtney.git
cd Courtney
```

2. Run the installation script:
```bash
python3 install.py
```

3. Choose your installation type:
   - **Global**: Records all Claude Code sessions across all projects
   - **Project**: Records only sessions in the current project

The installer will automatically:
- Set up the necessary Claude Code hooks
- Create a default configuration file at `~/.claude/courtney.json`
- Initialize the SQLite database at `~/.claude/courtney.db`

### Manual Installation

If you prefer to install manually, add the following to your Claude Code settings file:

**For global installation**, edit `~/.claude/settings.json`:
**For project installation**, edit `<project>/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{"matcher": "*", "hooks": [{"type": "command", "command": "/path/to/Courtney/courtney/hooks/courtney_hook.py"}]}],
    "SessionEnd": [{"matcher": "*", "hooks": [{"type": "command", "command": "/path/to/Courtney/courtney/hooks/courtney_hook.py"}]}],
    "UserPromptSubmit": [{"matcher": "*", "hooks": [{"type": "command", "command": "/path/to/Courtney/courtney/hooks/courtney_hook.py"}]}],
    "Stop": [{"matcher": "*", "hooks": [{"type": "command", "command": "/path/to/Courtney/courtney/hooks/courtney_hook.py"}]}],
    "SubagentStop": [{"matcher": "*", "hooks": [{"type": "command", "command": "/path/to/Courtney/courtney/hooks/courtney_hook.py"}]}]
  }
}
```

## Configuration

Courtney's configuration is stored in `~/.claude/courtney.json`:

```json
{
  "adapter": "sqlite",
  "sqlite": {
    "path": "~/.claude/courtney.db"
  }
}
```

### Configuration Options

- `adapter`: Database adapter type (currently only "sqlite" is supported)
- `sqlite.path`: Path to the SQLite database file

## Database Schema

Courtney uses a simple, normalized schema:

**sessions** table:
- `id`: Unique session identifier
- `started_at`: Session start timestamp
- `ended_at`: Session end timestamp
- `metadata`: JSON metadata about the session

**entries** table:
- `id`: Unique entry identifier
- `session_id`: Reference to the session
- `timestamp`: When the entry occurred
- `speaker`: Either "user" or "agent"
- `transcript`: The actual content
- `metadata`: JSON metadata (tool names, parameters, etc.)

## Querying Your Data

You can query the SQLite database directly:

```bash
sqlite3 ~/.claude/courtney.db
```

Example queries:

```sql
-- View all sessions
SELECT * FROM sessions ORDER BY started_at DESC;

-- View all entries for a session
SELECT timestamp, speaker, transcript
FROM entries
WHERE session_id = 'your-session-id'
ORDER BY timestamp;

-- Find all user prompts
SELECT timestamp, transcript
FROM entries
WHERE speaker = 'user'
ORDER BY timestamp DESC;

-- Find all AI responses
SELECT timestamp, transcript
FROM entries
WHERE speaker = 'agent'
ORDER BY timestamp DESC;

-- View a conversation (alternating user/agent)
SELECT timestamp, speaker,
       SUBSTR(transcript, 1, 100) || '...' as preview
FROM entries
WHERE session_id = 'your-session-id'
ORDER BY timestamp;
```

## Testing

To validate your Courtney installation, run the included test suite:

```bash
python3 test_courtney.py
```

This will test:
- Database initialization
- Session lifecycle tracking
- User prompt recording (full text, no truncation)
- AI response recording (full text, no truncation)
- Full conversation flow (user → agent)
- Stop hook transcript parsing
- Example SQL queries

All tests run against a temporary database and clean up after themselves.

## Use Cases

Courtney creates a searchable record of your AI-assisted development sessions, useful for:
- Reviewing what decisions were made and why
- Tracking the evolution of a solution
- Creating documentation from development sessions
- Auditing AI interactions in your workflow
- Training or fine-tuning models on your interaction patterns
