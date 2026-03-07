# Memory Repo Structure

Single source of truth for the memory repo layout. Referenced by all Asgard agents and skills.

## Directory Layout

```
memory-repo/
  MEMORY.md              # Core memory — stable facts, preferences, identity (200-line cap)
  procedures/
    procedures.md        # Index of learned workflows
    *.md                 # Individual procedure files
  journal/
    YYYY-MM-DD.md        # Daily logs — events, decisions, memory changes
    archive/             # Journals older than 7 days
      YYYY-MM/
        YYYY-MM-DD.md
  context-trees/
    projects.md          # Project status tracker
  inbox/                 # Raw session transcripts (captured by Asgard hooks)
    processed/           # Transcripts after consolidation
  .gitignore
```

## Layer Details

### MEMORY.md (Core Memory)

Stable facts organized in sections:
- **Identity** — name, role, key identifiers
- **Preferences** — tool choices, workflow preferences, communication style
- **Active Projects** — current projects with brief status
- **Technical Environment** — OS, shell, editor, languages, key tools
- **People** — key collaborators and their roles

200-line hard cap. Updated by Heimdall consolidation, never during sessions.

### Procedures

Learned workflows that have appeared in 2+ sessions. Each file documents:
- When to use the procedure
- Step-by-step instructions
- Gotchas or variations
- Last verified date

The index (`procedures/procedures.md`) links to all procedure files.

### Journal

Chronological log of events, decisions, and memory changes. Format:

```markdown
# YYYY-MM-DD

## HH:MM — <machine> — <project>
- Event or decision
- Memory change: added/updated/removed "<fact>"
```

Journals older than 7 days are archived to `journal/archive/YYYY-MM/`.

### Context Trees

Project status tracking. `projects.md` contains high-level status for active projects.

### Inbox

Raw session transcripts land here via Asgard's SessionEnd hook. Each file has YAML frontmatter with machine, session_id, cwd, and timestamp. After processing by `/heimdall process`, files move to `inbox/processed/`.

## Search Strategies by Question Type

### Broad Topic ("Tell me about X")
1. Read MEMORY.md — look for any mention
2. Grep all layers for the topic
3. Read matching files for full context

### "How do I..." (Procedure Lookup)
1. Check `procedures/` first — glob for related filenames
2. Grep `procedures/` for keywords
3. Fall back to journal for historical examples

### "What happened with..." (Temporal Query)
1. Grep `journal/` chronologically (filenames sort by date)
2. Include `journal/archive/` for older history
3. Check MEMORY.md for the current state

### "What's the status of..." (Project Status)
1. Check `context-trees/projects.md` first
2. Cross-reference with MEMORY.md Active Projects section
3. Grep recent journals for latest activity

### "What does the user prefer..." (Preference Lookup)
1. Read MEMORY.md Preferences section
2. Grep journal for corrections and preference changes
3. Check procedures for preference-driven workflows
