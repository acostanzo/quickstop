#!/bin/bash
# session-start.sh - Check for missing gitignored config files in worktrees
# Sends macOS notification if configs are missing

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

# Count missing config files
MISSING_COUNT=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ ! -e "$CURRENT_WORKTREE/$file" ]]; then
        ((MISSING_COUNT++)) || true
    fi
done <<< "$MAIN_GITIGNORED"

# Only notify if there are missing files
if [[ $MISSING_COUNT -eq 0 ]]; then
    exit 0
fi

# Get branch name
BRANCH=$(git branch --show-current 2>/dev/null) || BRANCH="(detached)"

# Send macOS alert dialog
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ $MISSING_COUNT -eq 1 ]]; then
        MESSAGE="Missing 1 config file from main.\n\nRun /arborist:tend to sync."
    else
        MESSAGE="Missing $MISSING_COUNT config files from main.\n\nRun /arborist:tend to sync."
    fi

    osascript -e "display alert \"🌳 Worktree: $BRANCH\" message \"$MESSAGE\"" 2>/dev/null || true
fi
