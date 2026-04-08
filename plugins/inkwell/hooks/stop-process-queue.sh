#!/usr/bin/env bash
# stop-process-queue.sh
# Stop hook — checks .inkwell-queue.json for pending doc tasks.
# If tasks exist, sends a systemMessage telling Claude to process them.

set -euo pipefail

# Derive project root — CWD may be a subdirectory
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
QUEUE_FILE="$PROJECT_ROOT/.inkwell-queue.json"

# No queue file → nothing to do
if [ ! -f "$QUEUE_FILE" ]; then
  exit 0
fi

# Require jq
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# Read and validate queue
QUEUE=$(cat "$QUEUE_FILE" 2>/dev/null) || exit 0
if ! printf '%s' "$QUEUE" | jq 'type == "array"' >/dev/null 2>&1; then
  exit 0
fi

# Check if queue has entries
TASK_COUNT=$(printf '%s' "$QUEUE" | jq 'length')
if [ "$TASK_COUNT" -eq 0 ]; then
  exit 0
fi

# Build a summary of pending tasks for the system message
TASK_SUMMARY=$(printf '%s' "$QUEUE" | jq -r '[.[] | .type] | group_by(.) | map("\(length) \(.[0])") | join(", ")')

# Output a JSON response with systemMessage instructing Claude to process the queue
# systemMessage must be at top level — nested inside hookSpecificOutput is silently ignored
cat <<ENDJSON
{
  "systemMessage": "Inkwell: ${TASK_COUNT} pending documentation tasks (${TASK_SUMMARY}) in .inkwell-queue.json. Dispatch the doc-writer agent (subagent_type: \"inkwell:doc-writer\") now. In the agent prompt, explicitly instruct it to: (1) process all tasks in the queue, (2) write docs to the paths configured in .inkwell.json, (3) clear the queue to [], and (4) create a single 'docs:' prefixed commit staging the generated docs and cleared queue. All four steps are required — do not let the agent return until the commit exists."
}
ENDJSON
