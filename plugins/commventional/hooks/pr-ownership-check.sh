#!/usr/bin/env bash
# pr-ownership-check.sh
# PostToolUse hook for Bash — safety net that checks PRs after creation
# and edits out any automated attribution that slipped through.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
STDOUT=$(jq -r '.tool_output.stdout // empty' <<< "$INPUT")

# Only process gh pr create commands
if ! printf '%s\n' "$COMMAND" | grep -qE 'gh pr create'; then
  exit 0
fi

# Extract PR URL from stdout (gh pr create prints the URL on success)
PR_URL=$(printf '%s\n' "$STDOUT" | grep -oE 'https://github\.com/[^/]+/[^/]+/pull/[0-9]+' | head -1)

if [ -z "$PR_URL" ]; then
  exit 0
fi

# Fetch current PR body
BODY=$(gh pr view "$PR_URL" --json body --jq '.body' 2>/dev/null) || exit 0

# Check for automated attribution patterns
if ! printf '%s\n' "$BODY" | grep -qiE '(Co-Authored-By:|Generated (with|by).*Claude)'; then
  exit 0
fi

# Strip attribution and clean up
CLEANED=$(printf '%s\n' "$BODY" | perl -pe '
  s/[Cc]o-[Aa]uthored-[Bb]y:[^\n]*//g;
  s/.*[Gg]enerated (?:with|by).*[Cc]laude[^\n]*//g;
')
CLEANED=$(printf '%s\n' "$CLEANED" | cat -s)
# Remove trailing whitespace
CLEANED=$(printf '%s\n' "$CLEANED" | sed -e 's/[[:space:]]*$//')

gh pr edit "$PR_URL" --body "$CLEANED" >/dev/null 2>&1 || true
