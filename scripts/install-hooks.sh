#!/bin/bash
# install-hooks.sh - Install git hooks for this repository

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_SOURCE="$REPO_ROOT/scripts/git-hooks"
HOOKS_DEST="$REPO_ROOT/.git/hooks"

echo "Installing git hooks..."

for hook in "$HOOKS_SOURCE"/*; do
    if [[ -f "$hook" ]]; then
        hook_name=$(basename "$hook")
        cp "$hook" "$HOOKS_DEST/$hook_name"
        chmod +x "$HOOKS_DEST/$hook_name"
        echo "  Installed: $hook_name"
    fi
done

echo "Done!"
