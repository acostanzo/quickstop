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

# Check for route/API file changes → api-contract task
ROUTE_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -E '^(src/routes/|src/api/|app/controllers/|routes/|api/)' || true)
if [ -z "$ROUTE_FILES" ]; then
  # Check file contents for route patterns (app.get, app.post, router., @Get, @Post, etc.)
  ROUTE_FILES=$(for f in $CHANGED_FILES; do
    if [ -f "$f" ] && grep -qlE 'app\.(get|post|put|patch|delete)\(|router\.(get|post|put|patch|delete|use|all|route)\(|@(Get|Post|Put|Patch|Delete)' "$f" 2>/dev/null; then
      printf '%s\n' "$f"
    fi
  done)
fi
if [ -n "$ROUTE_FILES" ]; then
  ROUTE_JSON=$(printf '%s\n' "$ROUTE_FILES" | jq -R . | jq -s .)
  TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
    --arg msg "$COMMIT_MSG" \
    --arg ts "$TIMESTAMP" \
    --argjson files "$ROUTE_JSON" \
    '. + [{type: "api-contract", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
fi

# Check for environment/config file changes → env-config task
ENV_FILES=$(printf '%s\n' "$CHANGED_FILES" | grep -E '(^\.env|^config/|^src/config/)' || true)
if [ -z "$ENV_FILES" ]; then
  # Check each changed source file individually for env variable references
  ENV_FILES=$(for f in $(printf '%s\n' "$CHANGED_FILES" | grep -E '\.(ts|js|tsx|jsx|py|go|rs)$'); do
    if [ -f "$f" ] && grep -qlE 'process\.env\.|os\.environ|Deno\.env' "$f" 2>/dev/null; then
      printf '%s\n' "$f"
    fi
  done)
fi
if [ -n "$ENV_FILES" ]; then
  ENV_JSON=$(printf '%s\n' "$ENV_FILES" | jq -R . | jq -s .)
  TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
    --arg msg "$COMMIT_MSG" \
    --arg ts "$TIMESTAMP" \
    --argjson files "$ENV_JSON" \
    '. + [{type: "env-config", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
fi

# Check for new model/entity/type files → domain-scaffold task
NEW_MODEL_FILES=$(git diff HEAD~1 --diff-filter=A --name-only 2>/dev/null | grep -E '^(src/models/|src/entities/|src/types/|models/|domain/)' || true)
if [ -n "$NEW_MODEL_FILES" ]; then
  MODEL_JSON=$(printf '%s\n' "$NEW_MODEL_FILES" | jq -R . | jq -s .)
  TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
    --arg msg "$COMMIT_MSG" \
    --arg ts "$TIMESTAMP" \
    --argjson files "$MODEL_JSON" \
    '. + [{type: "domain-scaffold", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
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
