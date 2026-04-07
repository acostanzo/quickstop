#!/usr/bin/env bash
# post-commit-queue.sh
# PostToolUse hook for Bash — detects git commits and queues doc tasks.
# Must complete in <2s. Only detects and queues — never writes docs.
# Reads detection rules from .inkwell.json. Falls back to changelog-only without config/jq.

set -euo pipefail

# Derive project root — CWD may be a subdirectory
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0

# Read hook input from stdin
INPUT=$(cat)

# Fast pre-filter: skip JSON parsing if this isn't a git commit
if ! printf '%s\n' "$INPUT" | grep -q 'git commit'; then
  exit 0
fi

# Check for jq — needed for JSON processing
HAS_JQ=false
if command -v jq >/dev/null 2>&1; then
  HAS_JQ=true
fi

# Extract the command that was executed (needs jq)
if [ "$HAS_JQ" = true ]; then
  COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
  if ! printf '%s\n' "$COMMAND" | grep -qE 'git commit'; then
    exit 0
  fi
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

CONFIG_FILE="$PROJECT_ROOT/.inkwell.json"

# Without jq or without config: fall back to changelog-only detection
if [ "$HAS_JQ" != true ] || [ ! -f "$CONFIG_FILE" ]; then
  # Changelog detection doesn't need config — it's commit-message based
  if printf '%s\n' "$COMMIT_MSG" | grep -qE '^(feat|fix|refactor|perf|security|revert)(\(.+\))?(!)?:'; then
    if [ "$HAS_JQ" = true ]; then
      ALL_FILES_JSON=$(printf '%s\n' "$CHANGED_FILES" | jq -R . | jq -s .)
      QUEUE_FILE="$PROJECT_ROOT/.inkwell-queue.json"
      TASK=$(jq -n --arg commit "$COMMIT_HASH" \
        --arg msg "$COMMIT_MSG" \
        --arg ts "$TIMESTAMP" \
        --argjson files "$ALL_FILES_JSON" \
        '[{type: "changelog", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
      if [ -f "$QUEUE_FILE" ]; then
        EXISTING=$(cat "$QUEUE_FILE" 2>/dev/null) || EXISTING="[]"
        if ! printf '%s' "$EXISTING" | jq 'type == "array"' >/dev/null 2>&1; then
          EXISTING="[]"
        fi
      else
        EXISTING="[]"
      fi
      MERGED=$(jq -s '.[0] + .[1]' <<< "$EXISTING"$'\n'"$TASK")
      printf '%s\n' "$MERGED" | jq '.' > "$QUEUE_FILE"
    fi
  fi
  exit 0
fi

# --- Config-driven detection ---

CONFIG=$(cat "$CONFIG_FILE")

# Helper: check if a doc type is enabled in config
is_enabled() {
  local doc_type="$1"
  printf '%s' "$CONFIG" | jq -e --arg t "$doc_type" '.docs[$t].enabled == true' >/dev/null 2>&1
}

# Helper: get paths array for a doc type
get_paths() {
  local doc_type="$1"
  printf '%s' "$CONFIG" | jq -r --arg t "$doc_type" '.docs[$t].paths // [] | .[]' 2>/dev/null
}

# Helper: get patterns array for a doc type
get_patterns() {
  local doc_type="$1"
  printf '%s' "$CONFIG" | jq -r --arg t "$doc_type" '.docs[$t].patterns // [] | .[]' 2>/dev/null
}

# Helper: match changed files against glob patterns using bash
# Returns matching files, one per line
match_files_by_path() {
  local doc_type="$1"
  local matched=""
  while IFS= read -r glob_pattern; do
    [ -z "$glob_pattern" ] && continue
    while IFS= read -r file; do
      # Use bash pattern matching via case statement for glob support
      # Convert glob ** to regex-friendly form for matching
      local regex_pattern
      regex_pattern=$(printf '%s' "$glob_pattern" | sed -e 's#\.#\\.#g' -e 's#?#.#g' -e 's#\*\*/#DBLSTARSLASH#g' -e 's#\*\*#.*#g' -e 's#\*#[^/]*#g' -e 's#DBLSTARSLASH#(.*/)?#g')
      if printf '%s\n' "$file" | grep -qE "^${regex_pattern}$"; then
        matched="${matched}${file}"$'\n'
      fi
    done <<< "$CHANGED_FILES"
  done < <(get_paths "$doc_type")
  printf '%s' "$matched" | grep -v '^$' | sort -u || true
}

# Helper: match changed files by content patterns
match_files_by_content() {
  local doc_type="$1"
  local matched=""
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    while IFS= read -r file; do
      if [ -f "$PROJECT_ROOT/$file" ] && grep -qlE "$pattern" "$PROJECT_ROOT/$file" 2>/dev/null; then
        matched="${matched}${file}"$'\n'
      fi
    done <<< "$CHANGED_FILES"
  done < <(get_patterns "$doc_type")
  printf '%s' "$matched" | grep -v '^$' | sort -u || true
}

# Build task list
TASKS="[]"

# --- api-reference: match by configured paths ---
if is_enabled "api-reference"; then
  SRC_FILES=$(match_files_by_path "api-reference")
  if [ -n "$SRC_FILES" ]; then
    FILES_JSON=$(printf '%s\n' "$SRC_FILES" | jq -R . | jq -s .)
    TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
      --arg msg "$COMMIT_MSG" \
      --arg ts "$TIMESTAMP" \
      --argjson files "$FILES_JSON" \
      '. + [{type: "api-reference", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
  fi
fi

# --- changelog: commit-message based (no path matching needed) ---
if is_enabled "changelog"; then
  if printf '%s\n' "$COMMIT_MSG" | grep -qE '^(feat|fix|refactor|perf|security|revert)(\(.+\))?(!)?:'; then
    ALL_FILES_JSON=$(printf '%s\n' "$CHANGED_FILES" | jq -R . | jq -s .)
    TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
      --arg msg "$COMMIT_MSG" \
      --arg ts "$TIMESTAMP" \
      --argjson files "$ALL_FILES_JSON" \
      '. + [{type: "changelog", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
  fi
fi

# --- architecture: structural heuristic (no path matching needed) ---
if is_enabled "architecture"; then
  NEW_DIRS=$(git diff HEAD~1 --diff-filter=A --name-only 2>/dev/null | cut -d/ -f1 | sort -u | wc -l)
  if [ "$NEW_DIRS" -gt 5 ]; then
    ALL_FILES_JSON=$(printf '%s\n' "$CHANGED_FILES" | jq -R . | jq -s .)
    TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
      --arg msg "$COMMIT_MSG" \
      --arg ts "$TIMESTAMP" \
      --argjson files "$ALL_FILES_JSON" \
      '. + [{type: "architecture", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
  fi
fi

# --- index: match doc file changes by configured paths ---
if is_enabled "index"; then
  DOC_FILES=$(match_files_by_path "index")
  if [ -n "$DOC_FILES" ]; then
    DOC_FILES_JSON=$(printf '%s\n' "$DOC_FILES" | jq -R . | jq -s .)
    TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
      --arg msg "$COMMIT_MSG" \
      --arg ts "$TIMESTAMP" \
      --argjson files "$DOC_FILES_JSON" \
      '. + [{type: "index", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
  fi
fi

# --- api-contract: match by paths then fall back to content patterns ---
if is_enabled "api-contract"; then
  ROUTE_FILES=$(match_files_by_path "api-contract")
  if [ -z "$ROUTE_FILES" ]; then
    ROUTE_FILES=$(match_files_by_content "api-contract")
  fi
  if [ -n "$ROUTE_FILES" ]; then
    ROUTE_JSON=$(printf '%s\n' "$ROUTE_FILES" | jq -R . | jq -s .)
    TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
      --arg msg "$COMMIT_MSG" \
      --arg ts "$TIMESTAMP" \
      --argjson files "$ROUTE_JSON" \
      '. + [{type: "api-contract", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
  fi
fi

# --- env-config: match by paths then fall back to content patterns ---
if is_enabled "env-config"; then
  ENV_FILES=$(match_files_by_path "env-config")
  if [ -z "$ENV_FILES" ]; then
    ENV_FILES=$(match_files_by_content "env-config")
  fi
  if [ -n "$ENV_FILES" ]; then
    ENV_JSON=$(printf '%s\n' "$ENV_FILES" | jq -R . | jq -s .)
    TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
      --arg msg "$COMMIT_MSG" \
      --arg ts "$TIMESTAMP" \
      --argjson files "$ENV_JSON" \
      '. + [{type: "env-config", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
  fi
fi

# --- domain-scaffold: match newly added files by configured paths ---
if is_enabled "domain-scaffold"; then
  NEW_FILES=$(git diff HEAD~1 --diff-filter=A --name-only 2>/dev/null) || NEW_FILES=""
  if [ -n "$NEW_FILES" ]; then
    # Match new files against configured paths
    MODEL_FILES=""
    while IFS= read -r glob_pattern; do
      [ -z "$glob_pattern" ] && continue
      while IFS= read -r file; do
        local_regex=$(printf '%s' "$glob_pattern" | sed -e 's#\.#\\.#g' -e 's#?#.#g' -e 's#\*\*/#DBLSTARSLASH#g' -e 's#\*\*#.*#g' -e 's#\*#[^/]*#g' -e 's#DBLSTARSLASH#(.*/)?#g')
        if printf '%s\n' "$file" | grep -qE "^${local_regex}$"; then
          MODEL_FILES="${MODEL_FILES}${file}"$'\n'
        fi
      done <<< "$NEW_FILES"
    done < <(get_paths "domain-scaffold")
    MODEL_FILES=$(printf '%s' "$MODEL_FILES" | grep -v '^$' | sort -u || true)
    if [ -n "$MODEL_FILES" ]; then
      MODEL_JSON=$(printf '%s\n' "$MODEL_FILES" | jq -R . | jq -s .)
      TASKS=$(printf '%s' "$TASKS" | jq --arg commit "$COMMIT_HASH" \
        --arg msg "$COMMIT_MSG" \
        --arg ts "$TIMESTAMP" \
        --argjson files "$MODEL_JSON" \
        '. + [{type: "domain-scaffold", commit: $commit, message: $msg, files: $files, timestamp: $ts}]')
    fi
  fi
fi

# If no tasks were generated, exit
TASK_COUNT=$(printf '%s' "$TASKS" | jq 'length')
if [ "$TASK_COUNT" -eq 0 ]; then
  exit 0
fi

# Append to existing queue (or create new one)
QUEUE_FILE="$PROJECT_ROOT/.inkwell-queue.json"
if [ -f "$QUEUE_FILE" ]; then
  EXISTING=$(cat "$QUEUE_FILE" 2>/dev/null) || EXISTING="[]"
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
