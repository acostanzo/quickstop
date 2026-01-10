#!/bin/bash
# mise-mcp.sh - Find mise binary and run MCP server
#
# This wrapper is needed because Claude Code's MCP process may not have
# mise in its PATH (especially on macOS with Homebrew in /opt/homebrew/bin)

# Common mise installation locations
MISE_CANDIDATES=(
    "$HOME/.local/bin/mise"
    "/opt/homebrew/bin/mise"
    "/usr/local/bin/mise"
    "/home/linuxbrew/.linuxbrew/bin/mise"
)

# Find mise
MISE_BIN=""
for candidate in "${MISE_CANDIDATES[@]}"; do
    if [[ -x "$candidate" ]]; then
        MISE_BIN="$candidate"
        break
    fi
done

# Also try PATH as last resort
if [[ -z "$MISE_BIN" ]]; then
    MISE_BIN=$(command -v mise 2>/dev/null || true)
fi

if [[ -z "$MISE_BIN" ]]; then
    echo "mise not found" >&2
    exit 1
fi

exec "$MISE_BIN" mcp "$@"
