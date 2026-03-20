#!/usr/bin/env bash
# pr-ownership-check.sh
# PostToolUse hook for Bash — safety net that checks PRs after creation
# and edits out any automated attribution that slipped through.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Cheap pre-filter: skip JSON parsing entirely for non-PR Bash calls.
# This avoids jq overhead on every Bash invocation (the common case).
INPUT=$(cat)
if ! printf '%s\n' "$INPUT" | grep -q 'gh pr'; then
  exit 0
fi

COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
STDOUT=$(jq -r '.tool_output.stdout // empty' <<< "$INPUT")

# Process gh pr create and gh pr edit commands
if ! printf '%s\n' "$COMMAND" | grep -qE 'gh pr (create|edit)'; then
  exit 0
fi

# Extract PR URL: try stdout first (gh pr create), then command args (gh pr edit <url>),
# then fall back to current branch context (gh pr edit without explicit URL).
PR_URL=$(printf '%s\n' "$STDOUT" | grep -oE 'https://github\.com/[^/]+/[^/]+/pull/[0-9]+' | head -1)

if [ -z "$PR_URL" ]; then
  PR_URL=$(printf '%s\n' "$COMMAND" | grep -oE 'https://github\.com/[^/]+/[^/]+/pull/[0-9]+' | head -1)
fi

if [ -z "$PR_URL" ]; then
  PR_URL=$(gh pr view --json url --jq '.url' 2>/dev/null) || true
fi

if [ -z "$PR_URL" ]; then
  exit 0
fi

# Fetch current PR body
BODY=$(gh pr view "$PR_URL" --json body --jq '.body' 2>/dev/null) || exit 0

# Check for automated attribution patterns
if ! printf '%s\n' "$BODY" | grep -qiE '(Co-Authored-By:|Generated (with|by).*Claude)'; then
  exit 0
fi

# Strip attribution and clean up.
# Uses [^\n]* (not [^"\x27\\]*) because we're operating on the raw PR body
# from the API, not a shell-quoted command string like enforce-ownership.sh.
CLEANED=$(printf '%s\n' "$BODY" | perl -pe '
  s/[Cc]o-[Aa]uthored-[Bb]y:[^\n]*//g;
  s/.*[Gg]enerated (?:with|by).*[Cc]laude[^\n]*//g;
')
CLEANED=$(printf '%s\n' "$CLEANED" | cat -s)
CLEANED=$(printf '%s\n' "$CLEANED" | sed -e 's/[[:space:]]*$//')

# Use --body-file to safely handle bodies with shell-special characters
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
printf '%s' "$CLEANED" > "$TMPFILE"
gh pr edit "$PR_URL" --body-file "$TMPFILE" >/dev/null 2>&1 || true
