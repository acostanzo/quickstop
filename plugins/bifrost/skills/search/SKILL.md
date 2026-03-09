---
name: search
description: Quick grep across all memory layers
argument-hint: "<query>"
---

# Search

Cross-layer grep across all memory files. For deeper analysis, use `/recall` instead.

## `/search $ARGUMENTS`

### Step 1: Load Config

Read `~/.config/bifrost/config` to get `BIFROST_REPO`. If the file doesn't exist:
"Bifrost is not configured. Run `/setup` first."

### Step 2: Validate Repo

Expand `~` in `BIFROST_REPO`. Check that the directory exists and contains `MEMORY.md`. If not:
"Memory repo not found at `<path>`. Run `/setup` to reconfigure."

### Step 3: Search All Layers

Search these locations for `$ARGUMENTS` (case-insensitive) using Grep:
- `MEMORY.md`
- `journal/` (all files, including archive)
- `procedures/` (all files)
- `context-trees/` (all files)

### Step 4: Display Results

Group results by layer:

```
Search: "$ARGUMENTS"
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

If no results in any layer: "No matches found for '$ARGUMENTS'."
