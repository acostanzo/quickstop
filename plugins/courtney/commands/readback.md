---
description: Read back the conversation transcript from the Courtney database
argument-hint: [timeframe like "last 10 minutes" or "all"]
allowed-tools: Bash(sqlite3:*)
---

# Readback Command

Read back the conversation transcript that Courtney has recorded.

## Parameters

**Timeframe**: `$ARGUMENTS` (optional)
- Default: Current session only
- Accepts: "last N minutes", "last N hours", "last hour", "all"

## Database Location

The Courtney database is located at `~/.claude/courtney.db` (or custom location from `~/.claude/courtney.json`).

## Your Task

1. **Parse the timeframe argument** (if provided in `$ARGUMENTS`)
   - If empty/blank/undefined → Query **current session only** (default - see below for logic)
   - If "last N minutes" → Query entries from last N minutes (across all sessions)
   - If "last N hours" → Query entries from last N hours (across all sessions)
   - If "last hour" → Query entries from last hour (across all sessions)
   - If "all" → Query all entries (limited to most recent 100)

2. **For the default case (current session):**

   Since this command doesn't have direct access to the session_id, use this two-step approach:

   **Step 1:** Get the session_id from the most recent entry in the database:
   ```bash
   SESSION_ID=$(sqlite3 ~/.claude/courtney.db "SELECT session_id FROM entries ORDER BY timestamp DESC LIMIT 1")
   ```

   **Step 2:** If a session_id was found, query all entries from that session:
   ```bash
   sqlite3 ~/.claude/courtney.db "SELECT timestamp, speaker, transcript FROM entries WHERE session_id = '$SESSION_ID' ORDER BY timestamp"
   ```

   **Rationale:** Since the readback command itself is not recorded (meta-command filtering), the most recent entry in the database is guaranteed to be from the actual conversation before readback was invoked - i.e., the "current session".

3. **Build SQL queries for other cases**:
   - For time-based queries: `SELECT timestamp, speaker, transcript FROM entries WHERE timestamp >= datetime('now', '-N minutes') ORDER BY timestamp`
   - For "all": `SELECT timestamp, speaker, transcript FROM entries ORDER BY timestamp DESC LIMIT 100`

4. **Format and present the results** in a readable way:
   - Show timestamp, speaker, and transcript for each entry
   - Format as a chronological conversation
   - If no results found, explain that nothing was recorded for that timeframe
   - Use clear visual separators between entries

5. **Handle errors gracefully**:
   - If database doesn't exist, explain that Courtney hasn't recorded anything yet
   - If no configuration found, use default database path

## Example Output Format

### Default (Current Session)
```
📋 Transcript Readback (Current Session)
═══════════════════════════════════════════════

[2025-11-03 10:15:23] User:
Can you help me implement a new feature?

[2025-11-03 10:15:45] Agent:
Of course! I'd be happy to help you implement a new feature...

[2025-11-03 10:16:12] User:
Great, let's start with...
```

### Time-Based Query
```
📋 Transcript Readback (Last 30 minutes)
═══════════════════════════════════════════════

[Shows entries from all sessions in the last 30 minutes...]
```

Make the output clear, well-formatted, and easy to read. Keep it simple and focused on showing the conversation flow.
