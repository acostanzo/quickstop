#!/bin/bash
# check-plugin-versions.sh - Verify plugin versions are bumped when files change
#
# Compares current branch against origin/main (or specified base) and checks
# that any modified plugins have had their version numbers updated.
#
# Usage:
#   ./scripts/check-plugin-versions.sh              # Compare against origin/main
#   ./scripts/check-plugin-versions.sh HEAD~1       # Compare against previous commit
#   ./scripts/check-plugin-versions.sh main         # Compare against local main

set -euo pipefail

BASE_REF="${1:-origin/main}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_ROOT"

# Get list of changed files
CHANGED_FILES=$(git diff --name-only "$BASE_REF" 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null || echo "")

if [[ -z "$CHANGED_FILES" ]]; then
    echo "No changes detected."
    exit 0
fi

# Find which plugins have changes (excluding README which doesn't require version bump)
CHANGED_PLUGINS=()
while IFS= read -r file; do
    if [[ "$file" =~ ^plugins/([^/]+)/ ]]; then
        plugin="${BASH_REMATCH[1]}"
        # Skip if only README changed
        if [[ "$file" != "plugins/$plugin/README.md" ]]; then
            if [[ ! " ${CHANGED_PLUGINS[*]:-} " =~ " $plugin " ]]; then
                CHANGED_PLUGINS+=("$plugin")
            fi
        fi
    fi
done <<< "$CHANGED_FILES"

if [[ ${#CHANGED_PLUGINS[@]} -eq 0 ]]; then
    echo "No plugin code changes detected (only READMEs or non-plugin files)."
    exit 0
fi

echo "Plugins with code changes: ${CHANGED_PLUGINS[*]}"
echo ""

ERRORS=0

for plugin in "${CHANGED_PLUGINS[@]}"; do
    PLUGIN_JSON="plugins/$plugin/.claude-plugin/plugin.json"

    if [[ ! -f "$PLUGIN_JSON" ]]; then
        echo "WARNING: $plugin has no plugin.json"
        continue
    fi

    # Check if plugin.json version changed
    OLD_VERSION=$(git show "$BASE_REF:$PLUGIN_JSON" 2>/dev/null | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -o '[0-9][0-9.]*' || echo "")
    NEW_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$PLUGIN_JSON" | grep -o '[0-9][0-9.]*' || echo "")

    if [[ -z "$OLD_VERSION" ]]; then
        echo "✓ $plugin: New plugin (v$NEW_VERSION)"
    elif [[ "$OLD_VERSION" == "$NEW_VERSION" ]]; then
        echo "✗ $plugin: Version NOT bumped (still v$OLD_VERSION)"
        echo "  Changed files:"
        echo "$CHANGED_FILES" | grep "^plugins/$plugin/" | grep -v "README.md" | sed 's/^/    /'
        ERRORS=$((ERRORS + 1))
    else
        echo "✓ $plugin: Version bumped v$OLD_VERSION → v$NEW_VERSION"
    fi
done

echo ""

# Check marketplace.json
if [[ " ${CHANGED_FILES} " =~ "plugins/" ]] && [[ ! " ${CHANGED_FILES} " =~ ".claude-plugin/marketplace.json" ]]; then
    echo "WARNING: Plugin files changed but marketplace.json was not updated."
    echo "         Remember to update the version in marketplace.json too!"
    ERRORS=$((ERRORS + 1))
fi

# Check README.md
if [[ " ${CHANGED_FILES} " =~ "plugins/" ]] && [[ ! " ${CHANGED_FILES} " =~ "README.md" ]]; then
    echo "WARNING: Plugin files changed but README.md was not updated."
    echo "         Remember to update the version in the README plugin table!"
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
    echo "Found $ERRORS issue(s). Please bump version numbers before pushing."
    exit 1
else
    echo "All version checks passed!"
    exit 0
fi
