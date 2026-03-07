#!/bin/bash
# Asgard — Bootstrap memory into Claude Code session
# Reads memory files from configured repo and injects as additionalContext
#
# Fixes over Bifrost v1:
# - B-1: Priority-based loading with budget tracking (not naive truncation)
# - B-2: Injects warnings via additionalContext instead of silently exiting
# - B-3: Configurable journal window via ASGARD_JOURNAL_DAYS (default 2)
# - B-4: Validates python3 and surfaces error if missing

set -euo pipefail

CONFIG_FILE="${HOME}/.config/asgard/config"

# --- Helper: output a warning as additionalContext ---
warn_and_exit() {
  local msg="$1"
  cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$msg"
  }
}
ENDJSON
  exit 0
}

# Check config exists (B-2: warn instead of silent exit)
if [[ ! -f "$CONFIG_FILE" ]]; then
  warn_and_exit "Asgard: not configured — run /asgard setup"
fi

# Read config values safely (no arbitrary code execution)
ASGARD_REPO=$(grep '^ASGARD_REPO=' "$CONFIG_FILE" | cut -d= -f2- || true)
ASGARD_MACHINE=$(grep '^ASGARD_MACHINE=' "$CONFIG_FILE" | cut -d= -f2- || true)
ASGARD_JOURNAL_DAYS=$(grep '^ASGARD_JOURNAL_DAYS=' "$CONFIG_FILE" | cut -d= -f2- || true)
ASGARD_CONTEXT_CHARS=$(grep '^ASGARD_CONTEXT_CHARS=' "$CONFIG_FILE" | cut -d= -f2- || true)

# Defaults (B-3: configurable journal window)
ASGARD_JOURNAL_DAYS="${ASGARD_JOURNAL_DAYS:-2}"
ASGARD_CONTEXT_CHARS="${ASGARD_CONTEXT_CHARS:-12000}"

# Validate required config
if [[ -z "${ASGARD_REPO:-}" ]]; then
  warn_and_exit "Asgard: ASGARD_REPO not set in config — run /asgard setup"
fi

# Validate machine name format
if [[ -n "${ASGARD_MACHINE:-}" && ! "$ASGARD_MACHINE" =~ ^[a-z0-9-]+$ ]]; then
  warn_and_exit "Asgard: invalid machine name '${ASGARD_MACHINE}' — must be [a-z0-9-]+"
fi

# Expand ~ in repo path
ASGARD_REPO="${ASGARD_REPO/#\~/$HOME}"

# Check repo exists (B-2: warn instead of silent exit)
if [[ ! -d "$ASGARD_REPO" ]]; then
  warn_and_exit "Asgard: memory repo not found at ${ASGARD_REPO}"
fi

# Check python3 (B-4: validate and surface error)
if ! command -v python3 &>/dev/null; then
  warn_and_exit "Asgard: python3 not found — memory loading unavailable"
fi

# Pull latest (short SSH timeout to avoid blocking session start)
# B-2: warn on failure instead of silently continuing
PULL_FAILED=""
GIT_SSH_COMMAND="ssh -o ConnectTimeout=3" git -C "$ASGARD_REPO" pull --quiet 2>/dev/null || PULL_FAILED="true"

# --- B-1: Priority-based loading with budget tracking ---
CONTEXT=""
BUDGET=$ASGARD_CONTEXT_CHARS

append_with_budget() {
  local content="$1"
  local content_len=${#content}
  if [[ $content_len -le $BUDGET ]]; then
    CONTEXT+="$content"
    CONTEXT+=$'\n\n'
    BUDGET=$((BUDGET - content_len - 2))
    return 0
  else
    # Partial fill with remaining budget
    if [[ $BUDGET -gt 100 ]]; then
      CONTEXT+="${content:0:$BUDGET}"
      CONTEXT+=$'\n\n[Asgard: context truncated — consider trimming memory files]'
      BUDGET=0
    fi
    return 1
  fi
}

# Priority 1: MEMORY.md (always — highest priority)
if [[ -f "$ASGARD_REPO/MEMORY.md" ]]; then
  append_with_budget "$(cat "$ASGARD_REPO/MEMORY.md")" || true
fi

# Priority 2: Procedures index
if [[ $BUDGET -gt 0 && -f "$ASGARD_REPO/procedures/procedures.md" ]]; then
  append_with_budget "$(cat "$ASGARD_REPO/procedures/procedures.md")" || true
fi

# Priority 3: Journals newest-first, up to ASGARD_JOURNAL_DAYS (B-3)
if [[ $BUDGET -gt 0 ]]; then
  for i in $(seq 0 $((ASGARD_JOURNAL_DAYS - 1))); do
    # Cross-platform date math: GNU (-d) and BSD/macOS (-v)
    JDATE=$(date -d "$i days ago" +%Y-%m-%d 2>/dev/null || date -v-${i}d +%Y-%m-%d 2>/dev/null || true)
    if [[ -n "$JDATE" && -f "$ASGARD_REPO/journal/$JDATE.md" ]]; then
      JCONTENT="# Journal — $JDATE"$'\n'"$(cat "$ASGARD_REPO/journal/$JDATE.md")"
      append_with_budget "$JCONTENT" || break
    fi
  done
fi

# Prepend pull failure warning if applicable (B-2)
if [[ -n "$PULL_FAILED" ]]; then
  CONTEXT="[Asgard: git pull failed — memory may be stale]"$'\n\n'"$CONTEXT"
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
