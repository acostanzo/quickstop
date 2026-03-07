---
name: heimdall
description: Memory consolidation — process inbox transcripts into structured memory, check status, search, and archive
---

# Heimdall: Memory Consolidation

You are the Heimdall orchestrator. When the user runs `/heimdall`, determine what they need from the subcommand and execute the appropriate pipeline.

## Repo Discovery

**Read the repo path from `~/.config/asgard/config`** (the `ASGARD_REPO` value). Expand `~` to the home directory. If the config file is absent, fall back to the current working directory and check for `MEMORY.md` there.

## Subcommands

### `/heimdall process`

The core consolidation pipeline. Processes all unprocessed inbox transcripts into structured memory.

#### Step 1: Validate Environment

Using the discovered repo path:
- Check for `MEMORY.md` — if missing, stop: "This doesn't look like a memory repo. Run `/asgard setup` first."
- Check for `inbox/` — if missing, stop: "No inbox/ directory found. Run `/asgard setup` to create the memory repo structure."

#### Step 2: Git Pull

Run `git pull` in the memory repo to get the latest state. If it fails (no remote, merge conflict), warn but continue.

#### Step 3: List Unprocessed Files

List files in `inbox/` (excluding `inbox/processed/` and subdirectories). Sort by filename (which sorts by timestamp since filenames start with YYYYMMDD-HHMMSS).

If no files found: "Inbox is empty — nothing to process."

**Idempotency check:** Before processing, check `inbox/processed/` for files with matching session IDs. If a file was already processed (exists in `processed/` with the same session ID fragment), skip it to avoid double-processing.

#### Step 4: Extract Observations

For each inbox file, spawn an **extractor** agent:

```
Agent:
  description: "Extract from <filename>"
  subagent_type: "asgard:extractor"
  prompt: |
    Read and extract observations from this transcript:
    Path: <full path to inbox file>

    Read the extraction guide at ${CLAUDE_PLUGIN_ROOT}/references/extraction-guide.md first.
```

**Parallel extraction is allowed.** Temporal ordering is preserved via timestamps in each file's frontmatter — the consolidator uses these timestamps, not processing order.

Collect all observations from all extractors into a single merged list, sorted by timestamp (oldest first).

#### Step 5: Read Current Memory State

Read these files from the memory repo (skip any that don't exist):
- `MEMORY.md`
- `journal/<today's date YYYY-MM-DD>.md`
- `procedures/procedures.md`
- `context-trees/projects.md`

#### Step 6: Consolidate

Spawn a **consolidator** agent with all observations and current state:

```
Agent:
  description: "Consolidate into memory"
  subagent_type: "asgard:consolidator"
  prompt: |
    Consolidate these observations into memory.

    Memory repo path: <repo_path>

    ## Extracted Observations
    <all observations from Step 4, sorted by timestamp>

    ## Current MEMORY.md
    <content or "File not found — create from scratch">

    ## Today's Journal
    <content or "No entry yet — create new">

    ## Procedures Index
    <content or "File not found — create from scratch">

    ## Context Trees
    <content or "File not found — create if needed">

    Read the extraction guide at ${CLAUDE_PLUGIN_ROOT}/references/extraction-guide.md for formatting conventions.
```

#### Step 7: Archive Old Journals

After consolidation, check for journals older than 7 days:

1. List files in `journal/` matching `????-??-??.md`
2. For each file with date > 7 days ago:
   - Create `journal/archive/YYYY-MM/` if needed
   - Move the file: `git mv journal/<date>.md journal/archive/YYYY-MM/<date>.md`

#### Step 8: Move Processed Inbox Files

1. Create `inbox/processed/` if it doesn't exist
2. For each processed inbox file: `git mv inbox/<file> inbox/processed/<file>`

#### Step 9: Git Commit and Push

```bash
git add MEMORY.md journal/ procedures/ context-trees/ inbox/
git commit -m "memory: consolidate <N> inbox transcripts"
git push
```

If push fails (no remote), warn but don't error.

#### Step 10: Report Summary

Show the consolidation summary from the consolidator agent, plus:
- Number of transcripts processed
- MEMORY.md line count (with cap percentage)
- Journal entries added
- Procedures created/updated
- Files archived

---

### `/heimdall status`

Memory health dashboard. No agents needed — read files directly.

#### Steps

1. Discover repo path from config (as described in Repo Discovery above).
2. Check for `MEMORY.md` — if missing, stop: "Not a memory repo."
3. Read/compute:
   - MEMORY.md line count (out of 200 cap)
   - Unprocessed inbox file count
   - Today's journal: exists? Entry count?
   - Procedure file count in `procedures/`
   - Journals older than 7 days (candidates for archival)
   - Last git commit date on current branch
4. Display:

```
Heimdall Status
──────────────────────────────
MEMORY.md:  45/200 lines (23%)
Inbox:      3 unprocessed
Journal:    today exists (5 entries)
Procedures: 2 files
Stale:      0 journals older than 7 days
Last commit: 2026-03-06 14:30
```

---

### `/heimdall search <query>`

Cross-layer grep across all memory files.

#### Steps

1. Discover repo path from config.
2. Check for `MEMORY.md` — if missing, stop.
3. Search these locations for `<query>` (case-insensitive):
   - `MEMORY.md`
   - `journal/` (all files, including archive)
   - `procedures/` (all files)
   - `context-trees/` (all files)
4. Display results grouped by layer:

```
Search: "<query>"
──────────────────────────────
MEMORY.md:
  Line 15: - Prefers bun over npm for JavaScript projects

Journal:
  journal/2026-03-06.md:12: - Switched from npm to bun
  journal/archive/2026-02/2026-02-28.md:8: - First tried bun

Procedures:
  procedures/js-setup.md:5: 2. Run bun install

No matches in context-trees/
```

If no results in any layer: "No matches found for '<query>'."

---

### `/heimdall archive`

Standalone maintenance — archive old journals and report cap pressure.

#### Steps

1. Discover repo path from config.
2. Check for `MEMORY.md` — if missing, stop.
3. **Archive journals > 7 days old:**
   - List journal files, identify those older than 7 days
   - Move to `journal/archive/YYYY-MM/` via `git mv`
   - Report how many archived
4. **Report MEMORY.md cap pressure:**
   - Count lines
   - If > 180: warn about approaching cap, suggest running `/heimdall process` to trigger compression
   - If > 200: error — cap violated, needs immediate attention
5. **Git commit and push:**

```bash
git add journal/
git commit -m "memory: archive journals older than 7 days"
git push
```

If nothing to archive: "No journals older than 7 days. Nothing to archive."

---

### `/heimdall` (no subcommand)

Show available subcommands:

```
Heimdall — Memory Consolidation
──────────────────────────────
/heimdall process    Process inbox transcripts into structured memory
/heimdall status     Memory health dashboard
/heimdall search Q   Cross-layer search across all memory files
/heimdall archive    Archive old journals, report cap pressure
```
