# Extraction Guide

Reference for both the extractor and consolidator agents. Defines what to extract from transcripts and how to organize it in memory.

## Transcript Format

Inbox files are JSONL. Line 1 is Bifrost metadata (`_type: "bifrost_meta"`). Remaining lines are Claude Code session events.

### Navigating the JSONL

Each line has a `type` field. Focus on these:

- **`type: "user"`** — Human messages. The `message.content` field is a string containing what the user said.
- **`type: "assistant"`** — Agent responses. The `message.content` field is an **array** of content blocks:
  - `{"type": "text", "text": "..."}` — Agent's written response. **Read these.**
  - `{"type": "tool_use", ...}` — Tool calls (Read, Bash, Edit, etc.). **Skip these.**
  - `{"type": "thinking", ...}` — Internal reasoning. **Skip these.**

Skip these line types entirely:
- `type: "progress"` — Tool execution output (~70% of lines). Contains file reads, grep results, git logs.
- `type: "file-history-snapshot"` — Internal file state tracking.
- `type: "system"` — System events.

**In a typical 800-line transcript, ~95 lines are user messages, ~130 are assistant messages, and ~580 are progress events.** The extractable dialogue is <25% of the file.

## Parallel Extraction

Extractors may run in parallel across multiple inbox files. Temporal ordering of observations is determined by the `timestamp` field in each transcript's metadata line, not by processing order. The consolidator sorts all observations by timestamp before processing.

## Observation Categories

| Category | Description | Priority |
|----------|-------------|----------|
| `correction` | User corrected the agent — the agent was wrong about something | Highest |
| `preference` | User stated or demonstrated a preference (tool choice, style, workflow) | High |
| `fact` | Durable fact about the user, their environment, or their work | High |
| `procedure` | Workflow pattern — steps the user follows to accomplish something | Medium |
| `project_update` | Project status change, new project, completed milestone | Medium |
| `event` | Something that happened — a decision, a deployment, a meeting outcome | Low |

## What to Extract

Focus on **human-agent dialogue** — the parts where the user and agent are communicating, deciding, and reasoning.

### High-Value Signals
- User corrections ("no, I meant...", "that's wrong", "actually...")
- Explicit preferences ("I prefer...", "always use...", "never do...")
- Demonstrated preferences (user consistently chooses X over Y)
- Decisions with rationale ("let's go with X because...")
- New project context (team members, architecture choices, deadlines)
- Environment details (OS, tools, paths, services)
- Repeated patterns (user does the same workflow across sessions)

### What to Skip
- Tool output (file reads, grep results, git log output)
- Compile/lint/test output
- File contents that were read or written
- Mechanical actions (git add, git commit, file edits)
- Boilerplate conversation (greetings, confirmations, "sounds good")
- Intermediate reasoning that led to a final decision (capture the decision, not the journey)

## Compression Targets

**Target: 3-6x compression of the full transcript.** A 500-line transcript should yield 10-30 observations. Since ~75% of lines are tool execution noise (`progress`, `file-history-snapshot`, `system`), this is roughly 10-25x compression of the actual extractable dialogue.

### Good Observation (Concise)
```
- type: preference
  content: Prefers bun over npm for all JavaScript projects
  confidence: high
  source_context: "always use bun, never npm"
```

### Bad Observation (Too Verbose)
```
- type: preference
  content: During a discussion about package managers, the user mentioned that they have been using bun for a while and find it faster than npm. They asked the agent to switch from npm to bun when running install commands. The agent confirmed and updated the package.json scripts accordingly.
  confidence: high
```

### Bad Observation (Too Granular)
```
- type: event
  content: User ran git status
  confidence: high
```

## MEMORY.md Conventions

### Section Structure
```markdown
# Memory

## Identity
- Name, role, key identifiers

## Preferences
- Tool preferences, workflow preferences, communication style

## Active Projects
- Current projects with brief status

## Technical Environment
- OS, shell, editor, languages, key tools

## People
- Key collaborators and their roles
```

### Line Cap
MEMORY.md has a **200-line hard cap**. When approaching the cap:
1. Compress verbose entries into shorter statements
2. Move detailed workflows to `procedures/`
3. Archive completed project entries
4. Merge related facts into single lines

### Priority for Cap Enforcement
When space is tight, keep (in order):
1. Corrections (most recent understanding)
2. Active project context
3. Preferences
4. Identity and environment
5. Historical events (lowest priority — move to journal)

## Journal Conventions

### Format
```markdown
# YYYY-MM-DD

## HH:MM — <machine> — <project context>
- Event or decision bullet
- Another event
- Memory change: added "prefers bun" to Preferences
```

### What Goes in Journal vs MEMORY.md
- **MEMORY.md**: Durable facts that are true going forward
- **Journal**: Events, decisions, memory changes — things that happened at a point in time

## Procedure Conventions

### When to Create a Procedure
A procedure file is warranted when a workflow pattern appears for the **2nd+ time** across sessions. Don't create procedures for one-off workflows.

### Format
```markdown
# Procedure Name

Brief description of when to use this.

## Steps
1. Step one
2. Step two
3. Step three

## Notes
- Gotchas or variations

Last verified: YYYY-MM-DD
```

### Index
`procedures/procedures.md` is the index. Every procedure file gets a link there.

## Contradiction Resolution

**Newer observations always win.** When a new transcript contradicts an existing MEMORY.md fact:
1. Update the fact in MEMORY.md
2. Log the change in journal: "Updated: <old fact> -> <new fact> (source: <transcript>)"
3. Never silently overwrite — the journal is the audit trail

## Confidence Levels

| Level | Meaning |
|-------|---------|
| `high` | User explicitly stated it, or demonstrated it multiple times |
| `medium` | Inferred from behavior or context, reasonable confidence |
| `low` | Weak signal — mentioned in passing, might be situational |

Only `high` and `medium` confidence observations should update MEMORY.md. `low` confidence observations go in the journal only.
