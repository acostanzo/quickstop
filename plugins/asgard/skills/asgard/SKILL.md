---
name: asgard
description: Unified memory system — setup wizard and full system health status
---

# Asgard: Memory System

You manage the Asgard memory system. When the user runs `/asgard`, determine what they need from the subcommand.

## Subcommands

### `/asgard setup`

Full guided setup — from zero to working memory system. Walk the user through each step, adapting based on what they already have.

#### Step 1: Check Dependencies

Run these checks via Bash:

- `git --version` — required. If missing, stop and tell the user to install Git.
- `python3 --version` — required for hooks. If missing, warn and link to python.org.

#### Step 2: Check for Existing Config

Look for `~/.config/asgard/config`. If it exists, show current values and ask if they want to reconfigure or start fresh.

Also check for legacy configs (`~/.config/bifrost/config`, `~/.config/munin/config`). If found, offer to migrate values.

#### Step 3: Memory Repo

Ask: "Do you have an existing memory repo, or should we create one?"

**If they have one:**
- Ask for the path. Validate it exists and is a git repo.
- Check for expected structure: `MEMORY.md`, `inbox/`, `journal/`, `procedures/`. If any are missing, offer to create them.

**If they need a new one:**
- Ask where to create it (e.g., `~/projects/my-memory`).
- Create the directory and initialize git: `git init`
- Scaffold the full directory structure:
  ```
  MEMORY.md
  procedures/procedures.md
  journal/
  inbox/
  context-trees/
  .gitignore
  ```
- Seed `MEMORY.md` with a starter template:
  ```markdown
  # Memory

  ## Identity
  - Name:
  - Role:

  ## Preferences

  ## Active Projects

  ## Technical Environment
  ```
- Seed `procedures/procedures.md`:
  ```markdown
  # Procedures

  Index of learned workflows. Individual procedure files live in this directory.
  ```
- Seed `.gitignore`:
  ```
  .DS_Store
  ```
- Ask if they want to add a git remote (for syncing across machines). If yes, ask for the URL, run `git remote add origin <url>`.
- Make an initial commit: `git add -A && git commit -m "Initial memory repo"`
- If remote was added, push: `git push -u origin main`
- Tell the user: "Your memory repo is ready. Seed `MEMORY.md` with what your agents should know about you — identity, preferences, projects, technical environment."

#### Step 4: Machine Name

Ask for a machine name. This identifies the machine in inbox filenames. Suggest the hostname as default: run `hostname` via Bash. The name should be short, lowercase, hyphenated (e.g., `personal-laptop`, `home-desktop`). **Validate:** only allow `[a-z0-9-]` — reject names with spaces, slashes, or special characters.

#### Step 5: Rules Scope

Ask where to plant the rules file (AskUserQuestion, single-select):
- **Global (recommended)** — `~/.claude/rules/asgard.md` — active in all projects
- **Project only** — `.claude/rules/asgard.md` — active only in current project

#### Step 6: Write Config File

```bash
mkdir -p ~/.config/asgard
cat > ~/.config/asgard/config << EOF
ASGARD_REPO=<path>
ASGARD_MACHINE=<name>
ASGARD_JOURNAL_DAYS=2
EOF
```

#### Step 7: Write Rules File

Write the rules file to the chosen location. **Critical: Do NOT hardcode the repo path.** Instead, instruct Claude to read the config file at runtime:

```markdown
# Asgard: Memory Awareness

You have persistent memory. To find its location, read `~/.config/asgard/config`
and use the `ASGARD_REPO` value.

## Session Context

Your core memory (MEMORY.md) and recent journal entries have been loaded as
session context automatically by the Asgard bootstrap hook. You don't need to
re-read MEMORY.md unless you need to verify a specific fact.

The layers below require explicit Read/Grep when relevant:

| Layer | Path (relative to ASGARD_REPO) | Use |
|-------|------|-----|
| Core memory | `MEMORY.md` | Stable facts — already loaded as context |
| Procedures | `procedures/` | Learned workflows — Read when doing multi-step tasks |
| Journal | `journal/` | Recent events and decisions — Grep for temporal context |
| Context trees | `context-trees/` | Project status and relationships |

## When to Recall

Before planning or making decisions that could benefit from historical context:
- Use Grep on `journal/` and `procedures/` for specific topics
- For deep searches across all layers, use `/munin recall <topic>`

## Corrections

When the user corrects you about something memory should know, note the
correction explicitly: "Noted correction: <what changed>." This flags it
for future consolidation.

## Constraints

- Memory files are **read-only during sessions** — never edit them directly
- Don't recite memory to the user — use it silently to inform your behavior
```

#### Step 8: Verification

Confirm everything is wired up:
- Config file exists and has correct values
- Rules file exists at chosen path
- Memory repo is accessible and has `MEMORY.md`
- Git remote is configured (warn if not — syncing won't work without one)
- Report: "Asgard is configured. Memory will load at session start and transcripts will be captured at session end."

---

### `/asgard status`

Full system health dashboard — combines and extends the individual layer status commands.

#### Steps

1. **Read config** from `~/.config/asgard/config`. If missing, tell the user to run `/asgard setup`.
2. Expand `~` in `ASGARD_REPO` and validate the repo directory exists.
3. **Report all of the following:**

   - **Config:** exists, repo path, machine name
   - **Repo:** accessible, git remote URL, last fetch time
   - **MEMORY.md:** line count / 200 cap
   - **Inbox:** unprocessed file count (files in `inbox/` excluding `processed/` subdirectory)
   - **Journal:** today's journal exists? entry count? stale journals older than 7 days?
   - **Procedures:** file count in `procedures/`
   - **Rules file:** check both `~/.claude/rules/asgard.md` and `.claude/rules/asgard.md` — report which exists
   - **Bootstrap:** check if `${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap.sh` exists and is executable
   - **Last commit:** date on current branch

Format as a clean status panel:
```
Asgard System Status
══════════════════════════════
Config:     ~/.config/asgard/config
Repo:       ~/projects/my-memory
Machine:    personal-laptop
Remote:     git@github.com:user/memory.git
Last fetch: 2 minutes ago

Memory:     45/200 lines (23%)
Inbox:      3 unprocessed
Journal:    today exists (12 entries)
Procedures: 5 files
Stale:      0 journals older than 7 days
Rules:      ~/.claude/rules/asgard.md
Bootstrap:  healthy
Last commit: 2026-03-06 14:30
```

---

### `/asgard` (no subcommand)

Show all available commands across the entire Asgard system:

```
Asgard — Memory System
══════════════════════════════
/asgard setup       Full setup wizard — config, repo, rules
/asgard status      System health dashboard

/heimdall process   Process inbox transcripts into memory
/heimdall status    Memory health dashboard
/heimdall search Q  Cross-layer search
/heimdall archive   Archive old journals

/munin recall Q     Deep search across all memory layers
```
