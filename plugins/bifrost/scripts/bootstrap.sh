#!/bin/bash
# Bifrost — Bootstrap memory into Claude Code session
# Reads memory files from configured repo and injects as additionalContext
#
# Fixes over original Bifrost:
# - B-1: Priority-based loading with budget tracking (not naive truncation)
# - B-2: Injects warnings via additionalContext instead of silently exiting
# - B-3: Configurable journal window via BIFROST_JOURNAL_DAYS (default 2)
# - B-4: Validates python3 and surfaces error if missing

set -euo pipefail

CONFIG_FILE="${HOME}/.config/bifrost/config"

# --- Helper: output a warning as additionalContext ---
# JSON-escapes the message to handle quotes/backslashes in config-derived values.
# Uses python3 if available, falls back to bash string replacement.
warn_and_exit() {
  local msg="$1"
  local escaped
  if command -v python3 &>/dev/null; then
    escaped=$(python3 -c 'import sys,json; print(json.dumps(sys.argv[1]))' "$msg")
  else
    # Minimal bash escaping: backslashes first, then double quotes
    msg="${msg//\\/\\\\}"
    msg="${msg//\"/\\\"}"
    escaped="\"$msg\""
  fi
  cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ${escaped}
  }
}
ENDJSON
  exit 0
}

# Check config exists (B-2: warn instead of silent exit)
if [[ ! -f "$CONFIG_FILE" ]]; then
  warn_and_exit "Bifrost: not configured — run /setup"
fi

# Read config values safely (no arbitrary code execution)
BIFROST_REPO=$(grep '^BIFROST_REPO=' "$CONFIG_FILE" | cut -d= -f2- || true)
BIFROST_MACHINE=$(grep '^BIFROST_MACHINE=' "$CONFIG_FILE" | cut -d= -f2- || true)
BIFROST_JOURNAL_DAYS=$(grep '^BIFROST_JOURNAL_DAYS=' "$CONFIG_FILE" | cut -d= -f2- || true)
BIFROST_CONTEXT_CHARS=$(grep '^BIFROST_CONTEXT_CHARS=' "$CONFIG_FILE" | cut -d= -f2- || true)

# Defaults with integer validation — fall back to defaults if non-numeric
BIFROST_JOURNAL_DAYS="${BIFROST_JOURNAL_DAYS:-2}"
BIFROST_CONTEXT_CHARS="${BIFROST_CONTEXT_CHARS:-12000}"
[[ "$BIFROST_JOURNAL_DAYS" =~ ^[0-9]+$ ]] || BIFROST_JOURNAL_DAYS=2
[[ "$BIFROST_CONTEXT_CHARS" =~ ^[0-9]+$ ]] || BIFROST_CONTEXT_CHARS=12000

# Validate required config
if [[ -z "${BIFROST_REPO:-}" ]]; then
  warn_and_exit "Bifrost: BIFROST_REPO not set in config — run /setup"
fi

# Validate machine name format
if [[ -n "${BIFROST_MACHINE:-}" && ! "$BIFROST_MACHINE" =~ ^[a-z0-9-]+$ ]]; then
  warn_and_exit "Bifrost: invalid machine name '${BIFROST_MACHINE}' — must be [a-z0-9-]+"
fi

# Expand ~ in repo path
BIFROST_REPO="${BIFROST_REPO/#\~/$HOME}"

# Check repo exists (B-2: warn instead of silent exit)
if [[ ! -d "$BIFROST_REPO" ]]; then
  warn_and_exit "Bifrost: memory repo not found at ${BIFROST_REPO}"
fi

# Check python3 (B-4: validate and surface error)
if ! command -v python3 &>/dev/null; then
  warn_and_exit "Bifrost: python3 not found — memory loading unavailable"
fi

# Pull latest (short SSH timeout to avoid blocking session start)
# B-2: warn on failure instead of silently continuing
PULL_FAILED=""
GIT_SSH_COMMAND="ssh -o ConnectTimeout=3" git -C "$BIFROST_REPO" pull --quiet 2>/dev/null || PULL_FAILED="true"

# --- B-1: Priority-based loading with budget tracking ---
CONTEXT=""
BUDGET=$BIFROST_CONTEXT_CHARS

# Skip entire files that don't fit rather than truncating mid-content.
# Partial content is worse than missing content — Claude may hallucinate
# from a half-finished preference or a cut-off procedure step.
# Priority-based loading ensures the most important files come first.
append_if_fits() {
  local content="$1"
  local content_len=${#content}
  if [[ $content_len -le $BUDGET ]]; then
    CONTEXT+="$content"
    CONTEXT+=$'\n\n'
    BUDGET=$((BUDGET - content_len - 2))
    return 0
  fi
  # Doesn't fit — skip entirely
  return 1
}

# Priority 1: MEMORY.md (always — highest priority)
if [[ -f "$BIFROST_REPO/MEMORY.md" ]]; then
  append_if_fits "$(cat "$BIFROST_REPO/MEMORY.md")" || true
fi

# Priority 2: Procedures index
if [[ $BUDGET -gt 0 && -f "$BIFROST_REPO/procedures/procedures.md" ]]; then
  append_if_fits "$(cat "$BIFROST_REPO/procedures/procedures.md")" || true
fi

# Priority 3: Journals newest-first, up to BIFROST_JOURNAL_DAYS (B-3)
if [[ $BUDGET -gt 0 ]]; then
  for i in $(seq 0 $((BIFROST_JOURNAL_DAYS - 1))); do
    # Cross-platform date math: GNU (-d) and BSD/macOS (-v)
    JDATE=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null || true)
    if [[ -n "$JDATE" && -f "$BIFROST_REPO/journal/$JDATE.md" ]]; then
      JCONTENT="# Journal — $JDATE"$'\n'"$(cat "$BIFROST_REPO/journal/$JDATE.md")"
      append_if_fits "$JCONTENT" || break
    fi
  done
fi

# Prepend pull failure warning if applicable (B-2)
if [[ -n "$PULL_FAILED" ]]; then
  CONTEXT="[Bifrost: git pull failed — memory may be stale]"$'\n\n'"$CONTEXT"
fi

# Output as additionalContext if we have anything
if [[ -n "$CONTEXT" ]]; then
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
