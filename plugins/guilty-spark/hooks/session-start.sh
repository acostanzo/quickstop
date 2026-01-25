#!/bin/bash
# Guilty Spark - SessionStart Hook
# Initializes docs/ directory and reports staleness

set -e

DOCS_DIR="docs"
INDEX_FILE="$DOCS_DIR/INDEX.md"
STALE_DAYS=7

# Validate plugin root
if [ -z "$CLAUDE_PLUGIN_ROOT" ]; then
    echo "Guilty Spark: Error - CLAUDE_PLUGIN_ROOT not set" >&2
    exit 1
fi

if [ ! -d "$CLAUDE_PLUGIN_ROOT" ]; then
    echo "Guilty Spark: Error - Plugin directory not found: $CLAUDE_PLUGIN_ROOT" >&2
    exit 1
fi

INIT_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/init-spark.sh"
if [ ! -x "$INIT_SCRIPT" ]; then
    echo "Guilty Spark: Error - Init script not executable: $INIT_SCRIPT" >&2
    exit 1
fi

# Check if we're in a git repository
GIT_CHECK=$(git rev-parse --is-inside-work-tree 2>&1) || true
if [ "$GIT_CHECK" != "true" ]; then
    # Not a git repo or git error - skip silently for non-repos
    if echo "$GIT_CHECK" | grep -q "not a git repository"; then
        exit 0
    fi
    # Actual git error - warn but don't block
    if [ -n "$GIT_CHECK" ]; then
        echo "Guilty Spark: Warning - git check failed: $GIT_CHECK" >&2
    fi
    exit 0
fi

# Check if docs/ directory exists
if [ ! -d "$DOCS_DIR" ]; then
    if bash "$INIT_SCRIPT"; then
        echo "Guilty Spark: Initialized docs/ directory"
    else
        echo "Guilty Spark: Error - Failed to initialize docs/" >&2
        exit 1
    fi
    exit 0
fi

# Check if INDEX.md exists
if [ ! -f "$INDEX_FILE" ]; then
    if bash "$INIT_SCRIPT"; then
        echo "Guilty Spark: Restored missing INDEX.md"
    else
        echo "Guilty Spark: Error - Failed to restore INDEX.md" >&2
        exit 1
    fi
    exit 0
fi

# Check for staleness (last modified >7 days ago)
UNAME_RESULT=$(uname 2>/dev/null) || UNAME_RESULT="unknown"

case "$UNAME_RESULT" in
    Darwin)
        LAST_MODIFIED=$(stat -f %m "$INDEX_FILE" 2>/dev/null) || {
            echo "Guilty Spark: Warning - Could not determine file age" >&2
            exit 0
        }
        ;;
    Linux)
        LAST_MODIFIED=$(stat -c %Y "$INDEX_FILE" 2>/dev/null) || {
            echo "Guilty Spark: Warning - Could not determine file age" >&2
            exit 0
        }
        ;;
    *)
        # Unsupported OS - skip staleness check
        exit 0
        ;;
esac

CURRENT_TIME=$(date +%s 2>/dev/null) || {
    echo "Guilty Spark: Warning - Could not get current time" >&2
    exit 0
}

# Validate timestamp is numeric
if ! [[ "$CURRENT_TIME" =~ ^[0-9]+$ ]]; then
    exit 0
fi

AGE_DAYS=$(( (CURRENT_TIME - LAST_MODIFIED) / 86400 ))

if [ $AGE_DAYS -gt $STALE_DAYS ]; then
    echo "Guilty Spark: Documentation may be stale (last updated $AGE_DAYS days ago). Consider using /guilty-spark:checkpoint or asking The Monitor to update docs."
fi

exit 0
