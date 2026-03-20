#!/usr/bin/env bash
# enforce-ownership.sh
# PreToolUse hook for Bash — enforces engineering ownership by removing
# automated AI co-author trailers and generated-by footers from commits
# and PR descriptions before execution.
#
# Uses substitution (not line deletion) to preserve trailing quote
# characters when attribution appears inline rather than in a HEREDOC.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")

# Only process git commit and gh pr create commands
if ! printf '%s\n' "$COMMAND" | grep -qE '(git commit|gh pr create)'; then
  exit 0
fi

# Remove automated co-author trailers and generated-by footers.
# Every Bash call this hook sees is from Claude, so any Co-Authored-By
# trailer is automated. [^"\x27\\]* preserves trailing quote characters.
CLEANED=$(printf '%s\n' "$COMMAND" | perl -pe '
  s/[Cc]o-[Aa]uthored-[Bb]y:[^"\x27\\]*//g;
  s/.*[Gg]enerated (?:with|by).*[Cc]laude[^"\x27\\]*//g;
')

# Collapse consecutive blank lines
CLEANED=$(printf '%s\n' "$CLEANED" | cat -s)

# If nothing changed, pass through silently
if [ "$COMMAND" = "$CLEANED" ]; then
  exit 0
fi

# Rewrite the command with ownership enforced
jq -n --arg cmd "$CLEANED" '{
  "hookSpecificOutput": {
    "updatedInput": {
      "command": $cmd
    }
  }
}'
