#!/bin/bash
# session-start.sh - Activate mise in shims mode for Claude Code bash sessions
#
# Why shims mode? Claude Code runs non-interactive bash. The normal `mise activate bash`
# uses a prompt hook (PROMPT_COMMAND) that only fires when displaying the prompt - which
# never happens in non-interactive mode. Shims mode simply prepends ~/.local/share/mise/shims
# to PATH, which works perfectly in any bash context.

set -euo pipefail

# Must have CLAUDE_ENV_FILE to persist environment variables
[ -z "${CLAUDE_ENV_FILE:-}" ] && exit 0

# Find mise binary - check common installation locations
MISE_BIN=""
for candidate in "$HOME/.local/bin/mise" "/usr/local/bin/mise" "/opt/homebrew/bin/mise" "$(command -v mise 2>/dev/null || true)"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        MISE_BIN="$candidate"
        break
    fi
done

# No mise found - exit silently (user may not have mise installed)
[ -z "$MISE_BIN" ] && exit 0

# Capture environment before mise activation
ENV_BEFORE=$(export -p | sort)

# Activate mise in SHIMS mode (required for non-interactive bash)
eval "$("$MISE_BIN" activate bash --shims)"

# Capture environment after mise activation
ENV_AFTER=$(export -p | sort)

# Write environment diff to CLAUDE_ENV_FILE
# This persists the changes for all subsequent bash commands in the session
comm -13 <(echo "$ENV_BEFORE") <(echo "$ENV_AFTER") >> "$CLAUDE_ENV_FILE"

# Output status message
echo "mise activated (shims mode)"
