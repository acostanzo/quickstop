#!/bin/bash
# detect-worktree.sh - Detect current worktree status and output formatted info
# Usage: detect-worktree.sh [--json]

set -euo pipefail

OUTPUT_JSON=false
[[ "${1:-}" == "--json" ]] && OUTPUT_JSON=true

# Check if we're in a git repository
if ! git rev-parse --git-dir &>/dev/null; then
    if $OUTPUT_JSON; then
        echo '{"is_git_repo": false}'
    else
        echo "Not in a git repository"
    fi
    exit 0
fi

# Get git directory and current directory
GIT_DIR=$(git rev-parse --git-dir)
CURRENT_DIR=$(pwd)
GIT_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null || echo "$CURRENT_DIR")

# Get current branch or detached HEAD info
BRANCH=$(git branch --show-current 2>/dev/null || true)
if [[ -z "$BRANCH" ]]; then
    BRANCH="(detached HEAD)"
    COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    BRANCH="$BRANCH at $COMMIT"
fi

# Determine worktree type
if [[ "$GIT_DIR" == *"/.git/worktrees/"* ]]; then
    WORKTREE_TYPE="linked"
    # Extract main worktree path from the gitdir structure
    MAIN_GIT_DIR=$(echo "$GIT_DIR" | sed 's|/worktrees/.*||')
    MAIN_WORKTREE=$(dirname "$MAIN_GIT_DIR")

    # Get worktree name from path
    WORKTREE_NAME=$(basename "$GIT_DIR")
elif [[ -f "$GIT_DIR" ]]; then
    # .git is a file pointing to the actual git dir (linked worktree)
    WORKTREE_TYPE="linked"
    ACTUAL_GIT_DIR=$(cat "$GIT_DIR" | sed 's/gitdir: //')
    MAIN_GIT_DIR=$(echo "$ACTUAL_GIT_DIR" | sed 's|/worktrees/.*||')
    MAIN_WORKTREE=$(dirname "$MAIN_GIT_DIR")
    WORKTREE_NAME=$(basename "$ACTUAL_GIT_DIR")
else
    WORKTREE_TYPE="main"
    MAIN_WORKTREE="$GIT_TOPLEVEL"
    WORKTREE_NAME="main"
fi

# Get total worktree count
WORKTREE_COUNT=$(git worktree list 2>/dev/null | wc -l | xargs)

# Check for uncommitted changes
if git diff --quiet && git diff --staged --quiet; then
    HAS_CHANGES=false
else
    HAS_CHANGES=true
fi

# Check for untracked files
UNTRACKED_COUNT=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | xargs)

if $OUTPUT_JSON; then
    cat << EOF
{
  "is_git_repo": true,
  "worktree_type": "$WORKTREE_TYPE",
  "worktree_name": "$WORKTREE_NAME",
  "branch": "$BRANCH",
  "current_path": "$GIT_TOPLEVEL",
  "main_worktree": "$MAIN_WORKTREE",
  "worktree_count": $WORKTREE_COUNT,
  "has_uncommitted_changes": $HAS_CHANGES,
  "untracked_files": $UNTRACKED_COUNT
}
EOF
else
    # Pretty formatted output
    echo "╭─ Worktree Status ──────────────────────────────╮"
    printf "│  %-44s │\n" "Type: $WORKTREE_TYPE worktree"
    printf "│  %-44s │\n" "Branch: $BRANCH"
    printf "│  %-44s │\n" "Path: $GIT_TOPLEVEL"
    if [[ "$WORKTREE_TYPE" == "linked" ]]; then
        printf "│  %-44s │\n" "Main: $MAIN_WORKTREE"
    fi
    printf "│  %-44s │\n" "Total worktrees: $WORKTREE_COUNT"
    if $HAS_CHANGES; then
        printf "│  %-44s │\n" "⚠ Uncommitted changes present"
    fi
    echo "╰────────────────────────────────────────────────╯"
fi
