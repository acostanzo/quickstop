---
name: bifrost
description: Manage Bifrost memory bridge — setup, status, and diagnostics
---

# Bifrost Memory Bridge

You manage the Bifrost memory bridge. When the user runs `/bifrost`, determine what they need from the subcommand.

## Subcommands

### `/bifrost setup`

Full guided setup — from zero to working memory bridge. Walk the user through each step, adapting based on what they already have.

#### Step 1: Check dependencies

Run these checks via Bash:

- `git --version` — required. If missing, stop and tell the user to install Git.
- `python3 --version` — required for hooks. If missing, warn and link to python.org.

#### Step 2: Check for existing config

Look for `~/.config/bifrost/config`. If it exists, show current values and ask if they want to reconfigure or start fresh.

#### Step 3: Memory repo

Ask: "Do you have an existing memory repo, or should we create one?"

**If they have one:**
- Ask for the path. Validate it exists and is a git repo.
- Check for expected structure: `MEMORY.md`, `inbox/`, `journal/`, `procedures/`. If any are missing, offer to create them.

**If they need a new one:**
- Ask where to create it (e.g., `~/projects/my-memory`).
- Create the directory and initialize git: `git init`
- Scaffold the directory structure:
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

#### Step 4: Machine name

Ask for a machine name. This identifies the machine in inbox filenames. Suggest the hostname as default: run `hostname` via Bash. The name should be short, lowercase, hyphenated (e.g., `personal-laptop`, `home-desktop`). **Validate:** only allow `[a-z0-9-]` — reject names with spaces, slashes, or special characters.

#### Step 5: Write config

```bash
mkdir -p ~/.config/bifrost
cat > ~/.config/bifrost/config << EOF
BIFROST_REPO=<path>
BIFROST_MACHINE=<name>
EOF
```

#### Step 6: Verify

- Confirm config file was written
- Confirm memory repo is accessible and has `MEMORY.md`
- Confirm git remote is configured (warn if not — syncing won't work without one)
- Report: "Bifrost is configured. Memory will load at session start and transcripts will be captured at session end."

### `/bifrost status`

Show the current state of the memory bridge:

1. **Read config** from `~/.config/bifrost/config`. If missing, tell the user to run `/bifrost setup`.

2. **Report:**
   - Memory repo path and whether it exists
   - Machine name
   - Git remote URL and last fetch time
   - MEMORY.md line count (out of 200 cap)
   - Number of unprocessed files in `inbox/`
   - Today's journal: exists or not
   - Number of procedures in `procedures/`
   - Last commit date on main

Format as a clean status panel:
```
Bifrost Status
──────────────────────────────
Repo:       ~/projects/my-memory
Machine:    personal-laptop
Remote:     git@github.com:user/memory.git
Last fetch: 2 minutes ago

Memory:     45/200 lines
Inbox:      3 unprocessed
Journal:    today exists (12 entries)
Procedures: 5 files
Last commit: 2026-03-06 14:30
```

### `/bifrost` (no subcommand)

Show available subcommands:
- `/bifrost setup` — Set up memory repo, dependencies, and configuration
- `/bifrost status` — Show memory bridge status
