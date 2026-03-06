#!/bin/bash
# Bifrost — Bootstrap memory into Claude Code session
# Reads memory files from configured repo and injects as additionalContext

set -euo pipefail

CONFIG_FILE="${HOME}/.config/bifrost/config"

# Check config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0  # Silent exit — not configured yet
fi

# Read config values safely (no arbitrary code execution)
BIFROST_REPO=$(grep '^BIFROST_REPO=' "$CONFIG_FILE" | cut -d= -f2-)
BIFROST_MACHINE=$(grep '^BIFROST_MACHINE=' "$CONFIG_FILE" | cut -d= -f2-)

# Validate required config
if [[ -z "${BIFROST_REPO:-}" ]]; then
  exit 0
fi

# Expand ~ in repo path
BIFROST_REPO="${BIFROST_REPO/#\~/$HOME}"

# Check repo exists
if [[ ! -d "$BIFROST_REPO" ]]; then
  exit 0
fi

# Pull latest (short SSH timeout to avoid blocking session start)
GIT_SSH_COMMAND="ssh -o ConnectTimeout=3" git -C "$BIFROST_REPO" pull --quiet 2>/dev/null || true

# Build context from memory files
CONTEXT=""

# 1. Semantic memory (MEMORY.md)
if [[ -f "$BIFROST_REPO/MEMORY.md" ]]; then
  CONTEXT+="$(cat "$BIFROST_REPO/MEMORY.md")"
  CONTEXT+=$'\n\n'
fi

# 2. Procedural memory index
if [[ -f "$BIFROST_REPO/procedures/procedures.md" ]]; then
  CONTEXT+="$(cat "$BIFROST_REPO/procedures/procedures.md")"
  CONTEXT+=$'\n\n'
fi

# 3. Episodic memory (today + yesterday journals)
#    GNU date uses -d "yesterday", BSD/macOS uses -v-1d — try both, skip if neither works
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || true)

if [[ -f "$BIFROST_REPO/journal/$TODAY.md" ]]; then
  CONTEXT+="# Journal — $TODAY"$'\n'
  CONTEXT+="$(cat "$BIFROST_REPO/journal/$TODAY.md")"
  CONTEXT+=$'\n\n'
fi

if [[ -n "$YESTERDAY" && -f "$BIFROST_REPO/journal/$YESTERDAY.md" ]]; then
  CONTEXT+="# Journal — $YESTERDAY"$'\n'
  CONTEXT+="$(cat "$BIFROST_REPO/journal/$YESTERDAY.md")"
  CONTEXT+=$'\n\n'
fi

# Output as additionalContext if we have anything
if [[ -n "$CONTEXT" ]]; then
  if ! command -v python3 &>/dev/null; then
    echo "bifrost: python3 required for JSON escaping but not found" >&2
    exit 0
  fi

  # Escape for JSON: handle backslashes, quotes, newlines, tabs
  ESCAPED=$(printf '%s' "$CONTEXT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')

  cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ${ESCAPED}
  }
}
ENDJSON
fi
