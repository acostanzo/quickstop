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
- **Speaker** - either "user", "agent", or "subagent"

## Installation

### Prerequisites
- Python 3.7 or higher
- Claude Code installed and configured

### Plugin Installation (Recommended)

Courtney is distributed as a Claude Code plugin for easy installation and management.

#### Install from GitHub

```bash
# Add the Quickstop marketplace
/plugin marketplace add acostanzo/quickstop

# Install Courtney
/plugin install courtney@quickstop
```

Select "Install now" when prompted, then restart Claude Code to activate.

#### Install from Local Clone

If you want to develop or customize Courtney:

```bash
# Clone the repository
git clone https://github.com/acostanzo/quickstop.git

# Add as a local marketplace
/plugin marketplace add ./quickstop

# Install Courtney
/plugin install courtney@quickstop
```

The plugin will automatically:
- Register hooks for SessionStart, SessionEnd, UserPromptSubmit, Stop, and SubagentStop
- Create a default configuration file at `~/.claude/courtney.json`
- Initialize the SQLite database at `~/.claude/courtney.db`

### Legacy Installation (Python Script)

If you prefer not to use the plugin system, you can still use the legacy installation script:

```bash
git clone https://github.com/acostanzo/quickstop.git
cd quickstop/plugins/courtney
python3 install.py
```

Choose either:
- **Global**: Records all Claude Code sessions across all projects
- **Project**: Records only sessions in the current project

## Managing the Plugin

### Check Plugin Status

```bash
/plugin
```

Select "Manage Plugins" to see installed plugins and their status.

### Disable/Enable

```bash
# Temporarily disable without uninstalling
/plugin disable courtney@quickstop

# Re-enable
/plugin enable courtney@quickstop
```

### Uninstall

```bash
/plugin uninstall courtney@quickstop
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
- `sqlite.path`: Path to the SQLite database file (supports `~` for home directory)

### First Run

On first use, Courtney automatically creates:
- Configuration file at `~/.claude/courtney.json` (if it doesn't exist)
- SQLite database at the configured path (default: `~/.claude/courtney.db`)

## Using Courtney

### Readback Command

Courtney includes a `/readback` command to review recorded transcripts directly in Claude Code.

#### Basic Usage

```bash
# Readback last 30 minutes (default)
/readback

# Readback specific timeframes
/readback last 10 minutes
/readback last 2 hours
/readback last hour

# Readback all entries (limited to recent 100)
/readback all
```

#### Examples

**Review recent activity:**
```bash
/readback
```
Shows all conversation entries from the last 30 minutes (default timeframe).

**Check specific timeframe:**
```bash
/readback last 10 minutes
```
Shows all conversations from the last 10 minutes.

**Quick review:**
```bash
/readback last hour
```
Shows all conversations from the last hour across all sessions.

The readback is formatted chronologically with timestamps, showing the natural flow of conversation between you and the AI.

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
- `speaker`: Either "user", "agent", or "subagent"
- `transcript`: The actual content

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

-- Find all subagent reports
SELECT timestamp, transcript
FROM entries
WHERE speaker = 'subagent'
ORDER BY timestamp DESC;

-- View a conversation (user/agent/subagent)
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
