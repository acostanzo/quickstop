#!/usr/bin/env bash
# enforce-no-ai-credit.sh
# PreToolUse hook for Bash — deterministically strips AI attribution
# from git commits and PR descriptions before execution.
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

# Strip AI co-author trailers and generated-by footers.
# [^"\x27\\]* stops before quotes/backslashes, preserving any
# trailing structural characters (closing quotes) on the line.
# .* prefix on Generated patterns consumes emoji prefixes.
CLEANED=$(printf '%s\n' "$COMMAND" | perl -pe '
  s/[Cc]o-[Aa]uthored-[Bb]y:.*(?:[Cc]laude|noreply\@anthropic|[Cc]opilot)[^"\x27\\]*//g;
  s/.*[Gg]enerated (?:with|by).*[Cc]laude[^"\x27\\]*//g;
')

# Collapse consecutive blank lines
CLEANED=$(printf '%s\n' "$CLEANED" | cat -s)

# If nothing changed, pass through silently
if [ "$COMMAND" = "$CLEANED" ]; then
  exit 0
fi

# Rewrite the command with attribution stripped
jq -n --arg cmd "$CLEANED" '{
  "hookSpecificOutput": {
    "updatedInput": {
      "command": $cmd
    }
  }
}'
