#!/usr/bin/env bash
# post-commit-queue.sh
# PostToolUse hook for Bash — detects git commits and queues doc tasks.
# Must complete in <2s. Only detects and queues — never writes docs.

set -euo pipefail

# Require jq for JSON processing
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Read hook input from stdin
INPUT=$(cat)

# Fast pre-filter: skip JSON parsing if this isn't a git commit
if ! printf '%s\n' "$INPUT" | grep -q 'git commit'; then
  exit 0
fi

# Extract the command that was executed
COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")

# Only process git commit commands (not git commit --amend in most cases)
if ! printf '%s\n' "$COMMAND" | grep -qE 'git commit'; then
  exit 0
fi

# Get the commit message from the most recent commit
COMMIT_MSG=$(git log -1 --format="%s" 2>/dev/null) || exit 0
COMMIT_HASH=$(git log -1 --format="%H" 2>/dev/null) || exit 0
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Skip docs-only commits (our own output)
if printf '%s\n' "$COMMIT_MSG" | grep -qE '^docs(\(.+\))?:'; then
  exit 0
fi

# Get changed files from the commit
CHANGED_FILES=$(git diff HEAD~1 --name-only 2>/dev/null) || exit 0

if [ -z "$CHANGED_FILES" ]; then
  exit 0
fi

# Build task list based on what changed
TASKS="[]"

# Check for source code changes → api-reference task
SRC_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -E '^(src|lib|app)/' || true)
if [ -n "$SRC_FILES" ]; then
  FILES_JSON=$(printf '%s\n' "$SRC_FILES" | jq -R . | jq -s .)
  TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
    --arg msg "$COMMIT_MSG" \
    --arg ts "$TIMESTAMP" \
    --argjson files "$FILES_JSON" \
    '. + [{type: "api-reference", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
fi

# Check for feat/fix commits → changelog task
if printf '%s\n' "$COMMIT_MSG" | grep -qE '^(feat|fix|refactor|perf|security|revert)(\(.+\))?(!)?:'; then
  ALL_FILES_JSON=$(printf '%s\n' "$CHANGED_FILES" | jq -R . | jq -s .)
  TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
    --arg msg "$COMMIT_MSG" \
    --arg ts "$TIMESTAMP" \
    --argjson files "$ALL_FILES_JSON" \
    '. + [{type: "changelog", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
fi

# Check for new top-level directories or major restructuring → architecture task
NEW_DIRS=$(git diff HEAD~1 --diff-filter=A --name-only 2>/dev/null | cut -d/ -f1 | sort -u | wc -l)
if [ "$NEW_DIRS" -gt 5 ]; then
  ALL_FILES_JSON=$(printf '%s\n' "$CHANGED_FILES" | jq -R . | jq -s .)
  TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
    --arg msg "$COMMIT_MSG" \
    --arg ts "$TIMESTAMP" \
    --argjson files "$ALL_FILES_JSON" \
    '. + [{type: "architecture", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
fi

# Check for doc file changes → index task
DOC_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -E '^docs/' || true)
if [ -n "$DOC_FILES" ]; then
  DOC_FILES_JSON=$(printf '%s\n' "$DOC_FILES" | jq -R . | jq -s .)
  TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
    --arg msg "$COMMIT_MSG" \
    --arg ts "$TIMESTAMP" \
    --argjson files "$DOC_FILES_JSON" \
    '. + [{type: "index", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
fi

# If no tasks were generated, exit
TASK_COUNT=$(printf '%s' "$TASKS" | jq 'length')
if [ "$TASK_COUNT" -eq 0 ]; then
  exit 0
fi

# Append to existing queue (or create new one)
QUEUE_FILE=".inkwell-queue.json"
if [ -f "$QUEUE_FILE" ]; then
  EXISTING=$(cat "$QUEUE_FILE" 2>/dev/null) || EXISTING="[]"
  # Validate existing content is a JSON array
  if ! printf '%s' "$EXISTING" | jq 'type == "array"' >/dev/null 2>&1; then
    EXISTING="[]"
  fi
else
  EXISTING="[]"
fi

# Merge existing and new tasks
MERGED=$(jq -s '.[0] + .[1]' <<< "$EXISTING"$'\n'"$TASKS")
printf '%s\n' "$MERGED" | jq '.' > "$QUEUE_FILE"

exit 0
