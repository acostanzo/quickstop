#!/bin/bash
# session-start.sh - Auto-sync gitignored config files from main worktree
# Silently syncs missing configs when starting Claude in a linked worktree

# Check if we're in a git repository
if ! git rev-parse --git-dir &>/dev/null; then
    exit 0
fi

# Get the absolute git directory path
GIT_DIR=$(git rev-parse --absolute-git-dir 2>/dev/null) || exit 0

# Check if this is a linked worktree (not main)
if [[ "$GIT_DIR" != *"/.git/worktrees/"* ]]; then
    exit 0
fi

# Get current worktree path
CURRENT_WORKTREE=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# Get main worktree path
MAIN_GIT_DIR=$(echo "$GIT_DIR" | sed 's|/worktrees/.*||')
MAIN_WORKTREE=$(dirname "$MAIN_GIT_DIR")

# Verify main worktree exists
if [[ ! -d "$MAIN_WORKTREE" ]]; then
    exit 0
fi

# Skip patterns (regeneratable files/directories)
SKIP_PATTERNS="node_modules|\.pnpm-store|vendor|\.bundle|\.venv|venv|__pycache__|\.pyc|\.eggs|\.egg-info|build|dist|target|out|\.gradle|\.next|\.nuxt|\.cache|\.parcel-cache|\.turbo|\.terraform|\.serverless"

# Get gitignored files from main worktree (excluding skip patterns)
MAIN_GITIGNORED=$(git -C "$MAIN_WORKTREE" ls-files --others --ignored --exclude-standard 2>/dev/null | grep -Ev "$SKIP_PATTERNS") || true

if [[ -z "$MAIN_GITIGNORED" ]]; then
    exit 0
fi

# Sync missing files
SYNCED_COUNT=0
SYNCED_FILES=()

while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    SOURCE="$MAIN_WORKTREE/$file"
    TARGET="$CURRENT_WORKTREE/$file"

    # Only sync if file exists in main but not in current worktree
    if [[ -f "$SOURCE" && ! -e "$TARGET" ]]; then
        # Create target directory if needed
        TARGET_DIR=$(dirname "$TARGET")
        mkdir -p "$TARGET_DIR" 2>/dev/null

        # Copy file preserving permissions
        if cp -a "$SOURCE" "$TARGET" 2>/dev/null; then
            ((SYNCED_COUNT++)) || true
            SYNCED_FILES+=("$file")
        fi
    fi
done <<< "$MAIN_GITIGNORED"

# Output summary if files were synced
if [[ $SYNCED_COUNT -gt 0 ]]; then
    if [[ $SYNCED_COUNT -eq 1 ]]; then
        echo "🌳 Synced 1 config file from main: ${SYNCED_FILES[0]}"
    else
        echo "🌳 Synced $SYNCED_COUNT config files from main: ${SYNCED_FILES[*]}"
    fi
fi
