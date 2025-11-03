---
description: Read back the conversation transcript from the Courtney database
argument-hint: [timeframe like "last 10 minutes" or "current session"]
allowed-tools: Bash(sqlite3:*)
---

# Readback Command

Read back the conversation transcript that Courtney has recorded.

## Parameters

**Timeframe**: `$ARGUMENTS` (optional)
- Default: Last 30 minutes
- Accepts: "last N minutes", "last N hours", "last hour", "all"

## Database Location

The Courtney database is located at `~/.claude/courtney.db` (or custom location from `~/.claude/courtney.json`).

## Your Task

1. **Parse the timeframe argument** (if provided in `$ARGUMENTS`)
   - If empty → Query last 30 minutes (default)
   - If "last N minutes" → Query entries from last N minutes
   - If "last N hours" → Query entries from last N hours
   - If "last hour" → Query entries from last hour
   - If "all" → Query all entries (limited to most recent 100)

2. **Build the appropriate SQL query**:
   - For time-based queries: `SELECT timestamp, speaker, transcript FROM entries WHERE timestamp >= datetime('now', '-N minutes') ORDER BY timestamp`
   - For "all": `SELECT timestamp, speaker, transcript FROM entries ORDER BY timestamp DESC LIMIT 100`

3. **Execute the query** using sqlite3:
   ```bash
   sqlite3 ~/.claude/courtney.db "SELECT timestamp, speaker, transcript FROM entries WHERE timestamp >= datetime('now', '-30 minutes') ORDER BY timestamp"
   ```

4. **Format and present the results** in a readable way:
   - Show timestamp, speaker, and transcript for each entry
   - Format as a chronological conversation
   - If no results found, explain that nothing was recorded for that timeframe
   - Use clear visual separators between entries

5. **Handle errors gracefully**:
   - If database doesn't exist, explain that Courtney hasn't recorded anything yet
   - If no configuration found, use default database path

## Example Output Format

```
📋 Transcript Readback (Last 30 minutes)
═══════════════════════════════════════════════

[2025-11-03 10:15:23] User:
Can you help me implement a new feature?

[2025-11-03 10:15:45] Agent:
Of course! I'd be happy to help you implement a new feature...

[2025-11-03 10:16:12] User:
Great, let's start with...
```

Make the output clear, well-formatted, and easy to read. Keep it simple and focused on showing the conversation flow.
