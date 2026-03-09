---
name: archive
description: Archive old journals and report memory cap pressure
argument-hint: ""
---

# Archive

Standalone maintenance — archive old journals and report cap pressure.

## `/archive`

### Step 1: Load Config

Read `~/.config/bifrost/config` to get `BIFROST_REPO`. If the file doesn't exist:
"Bifrost is not configured. Run `/setup` first."

### Step 2: Validate Repo

Expand `~` in `BIFROST_REPO`. Check that the directory exists and contains `MEMORY.md`. If not:
"Memory repo not found at `<path>`. Run `/setup` to reconfigure."

### Step 3: Archive Old Journals

List journal files in `journal/` matching `????-??-??.md`. Identify those older than 7 days.

For each stale journal:
- Create `journal/archive/YYYY-MM/` if needed
- Move the file: `git mv journal/<date>.md journal/archive/YYYY-MM/<date>.md`

Report how many were archived.

### Step 4: Report Cap Pressure

Count lines in MEMORY.md:
- If > 180: warn about approaching cap, suggest running `/heimdall` to trigger compression
- If > 200: error — cap violated, needs immediate attention
- Otherwise: report current count

### Step 5: Git Commit and Push

```bash
git add journal/
git commit -m "memory: archive journals older than 7 days"
git push
```

If nothing to archive: "No journals older than 7 days. Nothing to archive."
