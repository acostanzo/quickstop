# Arborist Plugin

> Component: Git worktree configuration synchronization

## Purpose

Arborist automatically syncs gitignored configuration files (like `.env`, `.npmrc`, local configs) from the main worktree to linked worktrees. This solves the problem of having to manually copy configuration files when working with git worktrees.

## Version

Current: **3.1.0**

## Architecture

```
arborist/
├── .claude-plugin/
│   └── plugin.json           # Plugin metadata
├── commands/
│   └── tend.md               # Interactive sync command
├── hooks/
│   ├── hooks.json            # SessionStart hook registration
│   └── session-start.sh      # Auto-sync script
└── README.md
```

## Components

### SessionStart Hook

**Purpose:** Automatically sync missing config files when Claude starts in a linked worktree.

**File:** `/Users/acostanzo/Code/quickstop/plugins/arborist/hooks/session-start.sh`

**Behavior:**
1. Detects if current directory is a linked git worktree (not main)
2. Identifies the main worktree location
3. Lists gitignored files in main worktree
4. Filters out regeneratable directories (node_modules, build, .venv, etc.)
5. Copies missing files to current worktree
6. Reports synced files count

**Skip Patterns (auto-excluded):**
- `node_modules`, `.pnpm-store`, `vendor`, `.bundle`
- `.venv`, `venv`, `__pycache__`, `.pyc`, `.eggs`, `.egg-info`
- `build`, `dist`, `target`, `out`, `.gradle`
- `.next`, `.nuxt`, `.cache`, `.parcel-cache`, `.turbo`
- `.terraform`, `.serverless`

### Tend Command

**Purpose:** Interactive manual sync with source worktree selection.

**File:** `/Users/acostanzo/Code/quickstop/plugins/arborist/commands/tend.md`

**Workflow:**
1. List available worktrees
2. Prompt user to select source (main recommended)
3. Find gitignored files in source that are missing in current
4. Offer "Sync all" or "Customize" mode
5. If customize, show file selection with sizes
6. Execute copy operations
7. Report results

**Allowed Tools:** Bash, Read, Write, AskUserQuestion

## Hook Registration

**File:** `/Users/acostanzo/Code/quickstop/plugins/arborist/hooks/hooks.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

## Data Flow

```
Claude Code Session Start
         │
         ▼
    SessionStart hook
         │
         ▼
    session-start.sh
         │
         ├── Not a linked worktree? → Exit silently
         │
         ├── Get main worktree path
         │
         ├── List gitignored files: git ls-files --others --ignored --exclude-standard
         │
         ├── Filter out skip patterns (node_modules, build, etc.)
         │
         ├── For each file:
         │   ├── Exists in main but not in current?
         │   │   └── Copy with: cp -a
         │
         └── Report: "Synced N config files from main: file1, file2, ..."
```

## Key Implementation Details

### Worktree Detection

```bash
GIT_DIR=$(git rev-parse --absolute-git-dir)
# Linked worktrees have path like: /repo/.git/worktrees/branch-name
if [[ "$GIT_DIR" != *"/.git/worktrees/"* ]]; then
    exit 0  # Not a linked worktree
fi
```

### Main Worktree Resolution

```bash
MAIN_GIT_DIR=$(echo "$GIT_DIR" | sed 's|/worktrees/.*||')
MAIN_WORKTREE=$(dirname "$MAIN_GIT_DIR")
```

### File Copy Preservation

```bash
cp -a "$SOURCE" "$TARGET"  # Preserves permissions, timestamps
```

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Silent operation | Auto-sync should not interrupt workflow; only reports when files synced |
| Main-to-linked direction | Main is typically the authoritative source for configs |
| Skip regeneratable dirs | node_modules etc. should be regenerated, not copied |
| Sync only missing files | Never overwrites existing files (safe operation) |
| SessionStart timing | Ensures configs are available before user starts working |

---

**Last Updated:** 2025-01-25
