---
name: heimdall
description: Consolidate inbox transcripts into structured memory — extracts observations and merges into MEMORY.md, journal, and procedures
disable-model-invocation: true
---

# Heimdall: Memory Consolidation

You are the Heimdall orchestrator. Process all unprocessed inbox transcripts into structured memory.

## Repo Discovery

Read the repo path from `~/.config/bifrost/config` (the `BIFROST_REPO` value). Expand `~` to the home directory. If the config file is absent, tell the user to run `/setup`.

## Reference Files

The extraction guide is at `${CLAUDE_SKILL_DIR}/../../references/extraction-guide.md`. Read it and pass its resolved path to agents when dispatching them.

## Pipeline

### Step 1: Validate Environment

Using the discovered repo path:
- Check for `MEMORY.md` — if missing, stop: "This doesn't look like a memory repo. Run `/setup` first."
- Check for `inbox/` — if missing, stop: "No inbox/ directory found. Run `/setup` to create the memory repo structure."

### Step 2: Git Pull

Run `git pull` in the memory repo to get the latest state. If it fails (no remote, merge conflict), warn but continue.

### Step 3: List Unprocessed Files

List files in `inbox/` (excluding `inbox/processed/` and subdirectories). Sort by filename (which sorts by timestamp since filenames start with YYYYMMDD-HHMMSS).

If no files found: "Inbox is empty — nothing to process."

**Idempotency check:** Before processing, extract the session ID fragment from each inbox filename (the 8 characters after the last `-` and before the extension — e.g., `a1b2c3d4` from `20260306-143000-personal-laptop-a1b2c3d4.jsonl`). Check if any file in `inbox/processed/` contains the same fragment. If so, skip that inbox file to avoid double-processing.

### Step 4: Extract Observations

For each inbox file, spawn an **extractor** agent:

```
Agent:
  description: "Extract from <filename>"
  subagent_type: "bifrost-extractor"
  prompt: |
    Read and extract observations from this transcript:
    Path: <full path to inbox file>

    Read the extraction guide at <resolved path to extraction-guide.md> first.
```

**Parallel extraction is allowed.** Temporal ordering is preserved via timestamps in each file's metadata — the consolidator uses these timestamps, not processing order.

Collect all observations from all extractors into a single merged list, sorted by timestamp (oldest first).

### Step 5: Read Current Memory State

Read these files from the memory repo (skip any that don't exist):
- `MEMORY.md`
- `journal/<today's date YYYY-MM-DD>.md`
- `procedures/procedures.md`
- `context-trees/projects.md`

### Step 6: Consolidate

Spawn a **consolidator** agent with all observations and current state:

```
Agent:
  description: "Consolidate into memory"
  subagent_type: "bifrost-consolidator"
  prompt: |
    Consolidate these observations into memory.

    Memory repo path: <repo_path>

    Extraction guide path: <resolved path to extraction-guide.md>

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
```

### Step 7: Archive Old Journals

After consolidation, check for journals older than 7 days:

1. List files in `journal/` matching `????-??-??.md`
2. For each file with date > 7 days ago:
   - Create `journal/archive/YYYY-MM/` if needed
   - Move the file: `git mv journal/<date>.md journal/archive/YYYY-MM/<date>.md`

### Step 8: Git Commit and Push

Commit the consolidation results (memory updates, journal entries, archived journals):

```bash
git add MEMORY.md journal/ procedures/ context-trees/
git commit -m "memory: consolidate <N> inbox transcripts"
git push
```

If push fails (no remote), warn but don't error. If the commit fails, **stop here** — do not move inbox files to processed, so the next run can retry.

### Step 9: Move Processed Inbox Files

Only after a successful commit, move the inbox files:

1. Create `inbox/processed/` if it doesn't exist
2. For each processed inbox file: `git mv inbox/<file> inbox/processed/<file>`
3. Commit the inbox move separately:

```bash
git commit -m "memory: archive <N> processed inbox files"
git push
```

### Step 10: Report Summary

Show the consolidation summary from the consolidator agent, plus:
- Number of transcripts processed
- MEMORY.md line count (with cap percentage)
- Journal entries added
- Procedures created/updated
- Files archived
