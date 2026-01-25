#!/bin/bash
# Guilty Spark - SessionStart Hook
# Initializes docs/ directory and reports staleness

set -e

DOCS_DIR="docs"
INDEX_FILE="$DOCS_DIR/INDEX.md"
STALE_DAYS=7

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    exit 0
fi

# Check if docs/ directory exists
if [ ! -d "$DOCS_DIR" ]; then
    # Run init script to create the documentation structure
    bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-spark.sh"
    echo "Guilty Spark: Initialized docs/ directory"
    exit 0
fi

# Check if INDEX.md exists
if [ ! -f "$INDEX_FILE" ]; then
    bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-spark.sh"
    echo "Guilty Spark: Restored missing INDEX.md"
    exit 0
fi

# Check for staleness (last modified >7 days ago)
if [ "$(uname)" = "Darwin" ]; then
    # macOS
    LAST_MODIFIED=$(stat -f %m "$INDEX_FILE")
else
    # Linux
    LAST_MODIFIED=$(stat -c %Y "$INDEX_FILE")
fi

CURRENT_TIME=$(date +%s)
AGE_DAYS=$(( (CURRENT_TIME - LAST_MODIFIED) / 86400 ))

if [ $AGE_DAYS -gt $STALE_DAYS ]; then
    echo "Guilty Spark: Documentation may be stale (last updated $AGE_DAYS days ago)"
fi

exit 0
