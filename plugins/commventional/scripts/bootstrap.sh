#!/bin/bash
# Commventional — Inject conventional commit and comment rules into session
#
# Outputs additionalContext with three rule sets:
# 1. Conventional Commits format (all commits)
# 2. PR title/description conventions
# 3. Conventional Comments format (review feedback)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_FILE="${SCRIPT_DIR}/rules.md"

if [[ ! -f "$RULES_FILE" ]]; then
  exit 0
fi

RULES=$(cat "$RULES_FILE")

# JSON-escape the rules
if command -v python3 &>/dev/null; then
  ESCAPED=$(printf '%s' "$RULES" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
else
  RULES="${RULES//\\/\\\\}"
  RULES="${RULES//\"/\\\"}"
  ESCAPED="\"$RULES\""
fi

cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ${ESCAPED}
  }
}
ENDJSON
