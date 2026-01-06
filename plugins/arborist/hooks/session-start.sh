#!/bin/bash
# session-start.sh - Display worktree status on session start (only for linked worktrees)

set -euo pipefail

# Check if we're in a git repository
if ! git rev-parse --git-dir &>/dev/null; then
    exit 0
fi

# Get git directory
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)

# Check if this is a linked worktree (not main)
IS_LINKED=false
if [[ "$GIT_DIR" == *"/.git/worktrees/"* ]]; then
    IS_LINKED=true
elif [[ -f "$GIT_DIR" ]]; then
    # .git is a file pointing to the actual git dir (linked worktree)
    IS_LINKED=true
fi

# Only show status for linked worktrees
if [[ "$IS_LINKED" != "true" ]]; then
    exit 0
fi

# Get worktree details
GIT_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)
BRANCH=$(git branch --show-current 2>/dev/null || echo "(detached)")

# Get main worktree path
if [[ -f "$GIT_DIR" ]]; then
    ACTUAL_GIT_DIR=$(cat "$GIT_DIR" | sed 's/gitdir: //')
    MAIN_GIT_DIR=$(echo "$ACTUAL_GIT_DIR" | sed 's|/worktrees/.*||')
else
    MAIN_GIT_DIR=$(echo "$GIT_DIR" | sed 's|/worktrees/.*||')
fi
MAIN_WORKTREE=$(dirname "$MAIN_GIT_DIR")

# Helper to truncate paths (show ...end if too long)
truncate_path() {
    local path="$1"
    local max_len="$2"
    if [[ ${#path} -le $max_len ]]; then
        echo "$path"
    else
        echo "...${path: -$((max_len-3))}"
    fi
}

# Format values
BRANCH_FMT=$(truncate_path "$BRANCH" 36)
PATH_FMT=$(truncate_path "$GIT_TOPLEVEL" 38)
MAIN_FMT=$(truncate_path "$MAIN_WORKTREE" 38)

# Output the status box
cat << EOF
╭─ Worktree Status ──────────────────────────────╮
│  Type: linked worktree                         │
│  Branch: $(printf "%-36s" "$BRANCH_FMT") │
│  Path: $(printf "%-38s" "$PATH_FMT") │
│  Main: $(printf "%-38s" "$MAIN_FMT") │
╰────────────────────────────────────────────────╯
EOF
