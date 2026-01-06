#!/bin/bash
# sync-gitignored.sh - Sync gitignored files from source worktree to target
# Usage: sync-gitignored.sh <source_worktree> <target_worktree>

set -euo pipefail

SOURCE="${1:?Usage: sync-gitignored.sh <source_worktree> <target_worktree>}"
TARGET="${2:?Usage: sync-gitignored.sh <source_worktree> <target_worktree>}"

# Resolve to absolute paths
SOURCE=$(cd "$SOURCE" && pwd)
TARGET=$(cd "$TARGET" && pwd)

# Find .worktreeignore file (check repo root first, then .git/info/)
WORKTREEIGNORE=""
if [[ -f "$SOURCE/.worktreeignore" ]]; then
    WORKTREEIGNORE="$SOURCE/.worktreeignore"
elif [[ -f "$SOURCE/.git/info/worktreeignore" ]]; then
    WORKTREEIGNORE="$SOURCE/.git/info/worktreeignore"
fi

# Default skip patterns (heavy defaults)
DEFAULT_SKIP_PATTERNS=(
    ".git"
    "node_modules"
    ".pnpm-store"
    "vendor"
    ".bundle"
    ".venv"
    "venv"
    "__pycache__"
    "*.pyc"
    ".eggs"
    "*.egg-info"
    "build"
    "dist"
    "target"
    "out"
    ".gradle"
    ".next"
    ".nuxt"
    ".cache"
    ".parcel-cache"
    ".turbo"
)

# Build rsync exclude arguments
EXCLUDE_ARGS=()

# Add default patterns
for pattern in "${DEFAULT_SKIP_PATTERNS[@]}"; do
    EXCLUDE_ARGS+=("--exclude=$pattern")
done

# Add patterns from .worktreeignore if it exists
if [[ -n "$WORKTREEIGNORE" && -f "$WORKTREEIGNORE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # Trim whitespace
        line=$(echo "$line" | xargs)
        [[ -n "$line" ]] && EXCLUDE_ARGS+=("--exclude=$line")
    done < "$WORKTREEIGNORE"
fi

# Get list of gitignored files in source
cd "$SOURCE"
GITIGNORED_FILES=$(git ls-files --others --ignored --exclude-standard 2>/dev/null || true)

if [[ -z "$GITIGNORED_FILES" ]]; then
    echo "No gitignored files found in source worktree."
    exit 0
fi

# Create a temporary file list
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

echo "$GITIGNORED_FILES" > "$TEMP_FILE"

# Count files for reporting
TOTAL_COUNT=$(wc -l < "$TEMP_FILE" | xargs)
SYNCED_COUNT=0
SKIPPED_COUNT=0

echo "Syncing gitignored files from $SOURCE to $TARGET..."
echo "Using .worktreeignore: ${WORKTREEIGNORE:-<defaults only>}"
echo ""

# Process each gitignored file
while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    # Check if file matches any skip pattern
    SKIP=false
    for pattern in "${DEFAULT_SKIP_PATTERNS[@]}"; do
        # Handle glob patterns
        if [[ "$file" == *"$pattern"* ]] || [[ "$file" == "$pattern" ]] || [[ "$file" == "$pattern/"* ]]; then
            SKIP=true
            break
        fi
    done

    # Also check .worktreeignore patterns
    if [[ -n "$WORKTREEIGNORE" && -f "$WORKTREEIGNORE" && "$SKIP" == "false" ]]; then
        while IFS= read -r pattern || [[ -n "$pattern" ]]; do
            [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
            pattern=$(echo "$pattern" | xargs)
            if [[ "$file" == *"$pattern"* ]] || [[ "$file" == "$pattern" ]] || [[ "$file" == "$pattern/"* ]]; then
                SKIP=true
                break
            fi
        done < "$WORKTREEIGNORE"
    fi

    if [[ "$SKIP" == "true" ]]; then
        ((SKIPPED_COUNT++)) || true
        continue
    fi

    # Create target directory if needed
    TARGET_DIR=$(dirname "$TARGET/$file")
    mkdir -p "$TARGET_DIR"

    # Copy the file
    if [[ -e "$SOURCE/$file" ]]; then
        cp -a "$SOURCE/$file" "$TARGET/$file" 2>/dev/null || true
        ((SYNCED_COUNT++)) || true
        echo "  ✓ $file"
    fi

done < "$TEMP_FILE"

echo ""
echo "Sync complete!"
echo "  Synced: $SYNCED_COUNT files"
echo "  Skipped: $SKIPPED_COUNT files (matched skip patterns)"
