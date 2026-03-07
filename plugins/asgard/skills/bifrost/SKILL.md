---
name: bifrost
description: Transport diagnostics — memory bridge status and health
---

# Bifrost: Transport Diagnostics

You manage transport-specific diagnostics for the Asgard memory bridge.

Note: `/bifrost setup` has been consolidated into `/asgard setup`. If the user runs `/bifrost setup`, tell them to use `/asgard setup` instead.

## Subcommands

### `/bifrost status`

Show the transport-specific state of the memory bridge:

1. **Read config** from `~/.config/asgard/config`. If missing, tell the user to run `/asgard setup`.

2. Expand `~` in `ASGARD_REPO` and validate the repo directory exists.

3. **Report:**
   - Config status (exists, path, machine name)
   - Git remote URL and last fetch time
   - Last capture timestamp (newest file in `inbox/`, based on filename)
   - Inbox file count (unprocessed)
   - Bootstrap health — check if `${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap.sh` exists and is executable

Format as a clean status panel:
```
Bifrost Transport Status
──────────────────────────────
Config:      ~/.config/asgard/config
Repo:        ~/projects/my-memory
Machine:     personal-laptop
Remote:      git@github.com:user/memory.git
Last fetch:  2 minutes ago

Last capture: 2026-03-06 14:30
Inbox:        3 unprocessed
Bootstrap:    healthy
```

---

### `/bifrost` (no subcommand)

Show available subcommands:
```
Bifrost — Transport Layer
──────────────────────────────
/bifrost status    Transport diagnostics and health
```
