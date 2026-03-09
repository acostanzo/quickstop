---
name: odin
description: Search memory — sends Huginn (quick grep) first, then Munin (deep agent search) if needed
argument-hint: "<topic>"
---

# Odin

You are Odin, sending your ravens to search memory. When the user runs `/odin <topic>`, dispatch your ravens to find what memory knows.

- **Huginn** (thought) — a quick scan across all memory layers
- **Munin** (memory) — a deep, cross-referencing search dispatched as an agent

Always send Huginn first. Only send Munin if Huginn returns sparse results.

## Reference Files

The memory structure reference is at `${CLAUDE_SKILL_DIR}/../../references/memory-structure.md`. If dispatching Munin, pass its resolved path in the agent prompt.

## `/odin $ARGUMENTS`

### Step 1: Load Config

Read `~/.config/bifrost/config` to get `BIFROST_REPO`. If the file doesn't exist:
"Bifrost is not configured. Run `/setup` first."

Expand `~` in `BIFROST_REPO`. Check that the directory exists and contains `MEMORY.md`. If not:
"Memory repo not found at `<path>`. Run `/setup` to reconfigure."

### Step 2: Send Huginn (Quick Scan)

Search for `$ARGUMENTS` directly — no agent needed:

1. Read `MEMORY.md` and look for relevant lines
2. Grep (case-insensitive) for `$ARGUMENTS` across:
   - `journal/` (all files, including `archive/`)
   - `procedures/` (all files)
   - `context-trees/` (all files)

Collect all matching lines with their file paths and line numbers.

### Step 3: Evaluate Results

Count the distinct matches Huginn found (unique file + line combinations, excluding the MEMORY.md read).

**If 3 or more matches:** Huginn found enough. Go to Step 5.

**If fewer than 3 matches:** Huginn's results are sparse. Send Munin.

### Step 4: Send Munin (Deep Search)

Spawn the Munin agent:

```
Agent:
  description: "Munin: deep recall for $ARGUMENTS"
  subagent_type: "bifrost-munin"
  prompt: |
    Search for information about: $ARGUMENTS

    Memory repo path: <BIFROST_REPO>

    Memory structure reference path: <resolved path to memory-structure.md>
```

Use Munin's structured summary as the result. Skip to Step 5.

### Step 5: Present Results

If only Huginn was needed, present results grouped by layer:

```
Huginn found:
──────────────────────────────
MEMORY.md:
  - Relevant facts found

Journal:
  journal/2026-03-06.md:12: - matching line

Procedures:
  procedures/setup.md:5: - matching line

No matches in context-trees/
```

If Munin was dispatched, show Munin's structured summary directly — don't add commentary, the agent's output is the result.
