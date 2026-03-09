---
name: setup
description: Bifrost memory system setup wizard
---

# Bifrost Setup

Full guided setup — from zero to working memory system. Walk the user through each step, adapting based on what they already have.

## `/setup`

### Step 1: Check Dependencies

Run these checks via Bash:

- `git --version` — required. If missing, stop and tell the user to install Git.
- `python3 --version` — required for hooks. If missing, warn and link to python.org.

### Step 2: Check for Existing Config

Look for `~/.config/bifrost/config`. If it exists, show current values and ask if they want to reconfigure or start fresh.

Also check for legacy configs (`~/.config/asgard/config`, `~/.config/munin/config`). If found, offer to migrate values.

### Step 3: Memory Repo

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

### Step 4: Machine Name

Ask for a machine name. This identifies the machine in inbox filenames. Suggest the hostname as default: run `hostname` via Bash. The name should be short, lowercase, hyphenated (e.g., `personal-laptop`, `home-desktop`). **Validate:** only allow `[a-z0-9-]` — reject names with spaces, slashes, or special characters.

### Step 5: Rules Scope

Ask where to plant the rules file (AskUserQuestion, single-select):
- **Global (recommended)** — `~/.claude/rules/bifrost.md` — active in all projects
- **Project only** — `.claude/rules/bifrost.md` — active only in current project

### Step 6: Write Config File

```bash
mkdir -p ~/.config/bifrost
cat > ~/.config/bifrost/config << EOF
BIFROST_REPO=<path>
BIFROST_MACHINE=<name>
BIFROST_JOURNAL_DAYS=2
EOF
```

### Step 7: Write Rules File

Write the rules file to the chosen location. **Critical: Do NOT hardcode the repo path.** Instead, instruct Claude to read the config file at runtime:

```markdown
# Bifrost: Memory Awareness

You have persistent memory. To find its location, read `~/.config/bifrost/config`
and use the `BIFROST_REPO` value.

## Session Context

Your core memory (MEMORY.md) and recent journal entries have been loaded as
session context automatically by the Bifrost bootstrap hook. You don't need to
re-read MEMORY.md unless you need to verify a specific fact.

The layers below require explicit Read/Grep when relevant:

| Layer | Path (relative to BIFROST_REPO) | Use |
|-------|------|-----|
| Core memory | `MEMORY.md` | Stable facts — already loaded as context |
| Procedures | `procedures/` | Learned workflows — Read when doing multi-step tasks |
| Journal | `journal/` | Recent events and decisions — Grep for temporal context |
| Context trees | `context-trees/` | Project status and relationships |

## When to Recall

Before planning or making decisions that could benefit from historical context:
- Use Grep on `journal/` and `procedures/` for specific topics
- For deep searches across all layers, use `/recall <topic>`

## Corrections

When the user corrects you about something memory should know, note the
correction explicitly: "Noted correction: <what changed>." This flags it
for future consolidation.

## Constraints

- Memory files are **read-only during sessions** — never edit them directly
- Don't recite memory to the user — use it silently to inform your behavior
```

### Step 8: Verification

Confirm everything is wired up:
- Config file exists and has correct values
- Rules file exists at chosen path
- Memory repo is accessible and has `MEMORY.md`
- Git remote is configured (warn if not — syncing won't work without one)
- Report: "Bifrost is configured. Memory will load at session start and transcripts will be captured at session end."
