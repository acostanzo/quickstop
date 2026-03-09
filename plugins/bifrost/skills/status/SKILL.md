---
name: status
description: Bifrost memory system health dashboard
disable-model-invocation: true
---

# Bifrost Status

Full system health dashboard.

## `/status`

### Steps

1. **Read config** from `~/.config/bifrost/config`. If missing, tell the user to run `/bifrost:setup`.
2. Expand `~` in `BIFROST_REPO` and validate the repo directory exists.
3. **Report all of the following:**

   - **Config:** exists, repo path, machine name
   - **Repo:** accessible, git remote URL, last fetch time
   - **MEMORY.md:** line count / 200 cap
   - **Inbox:** unprocessed file count (files in `inbox/` excluding `processed/` subdirectory)
   - **Journal:** today's journal exists? entry count? stale journals older than 7 days?
   - **Procedures:** file count in `procedures/`
   - **Rules file:** check both `~/.claude/rules/bifrost.md` and `.claude/rules/bifrost.md` — report which exists
   - **Bootstrap:** check if `${CLAUDE_SKILL_DIR}/../../scripts/bootstrap.sh` exists and is executable
   - **Last commit:** date on current branch

Format as a clean status panel:
```
Bifrost System Status
══════════════════════════════
Config:     ~/.config/bifrost/config
Repo:       ~/projects/my-memory
Machine:    personal-laptop
Remote:     git@github.com:user/memory.git
Last fetch: 2 minutes ago

Memory:     45/200 lines (23%)
Inbox:      3 unprocessed
Journal:    today exists (12 entries)
Procedures: 5 files
Stale:      0 journals older than 7 days
Rules:      ~/.claude/rules/bifrost.md
Bootstrap:  healthy
Last commit: 2026-03-06 14:30
```
