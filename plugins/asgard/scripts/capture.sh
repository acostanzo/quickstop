#!/bin/bash
# Asgard — Capture session transcript to memory inbox
# Runs async on SessionEnd — zero noise, zero blocking
#
# Fix over Bifrost v1:
# - B-5: Basic validation of stdin JSON structure before processing

set -euo pipefail

CONFIG_FILE="${HOME}/.config/asgard/config"

# Check config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "asgard: config not found at $CONFIG_FILE" >&2
  exit 0
fi

# Read config values safely (no arbitrary code execution)
ASGARD_REPO=$(grep '^ASGARD_REPO=' "$CONFIG_FILE" | cut -d= -f2- || true)
ASGARD_MACHINE=$(grep '^ASGARD_MACHINE=' "$CONFIG_FILE" | cut -d= -f2- || true)

# Validate required config
if [[ -z "${ASGARD_REPO:-}" || -z "${ASGARD_MACHINE:-}" ]]; then
  echo "asgard: ASGARD_REPO or ASGARD_MACHINE not set in config" >&2
  exit 0
fi

# Validate machine name format
if [[ ! "$ASGARD_MACHINE" =~ ^[a-z0-9-]+$ ]]; then
  echo "asgard: invalid machine name '${ASGARD_MACHINE}'" >&2
  exit 0
fi

# Expand ~ in repo path
ASGARD_REPO="${ASGARD_REPO/#\~/$HOME}"

# Check repo exists
if [[ ! -d "$ASGARD_REPO" ]]; then
  echo "asgard: memory repo not found at ${ASGARD_REPO}" >&2
  exit 0
fi

# Read session info from stdin JSON (Claude Code SessionEnd hook contract)
# B-5: Single python3 call validates JSON and extracts fields (or exits on bad input)
INPUT=$(cat)
PARSED=$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("transcript_path", ""), d.get("session_id", ""), d.get("cwd", ""), sep="\t")
except (json.JSONDecodeError, ValueError):
    sys.exit(1)
' 2>/dev/null) || {
  echo "asgard: invalid JSON on stdin" >&2
  exit 0
}

IFS=$'\t' read -r TRANSCRIPT_PATH SESSION_ID CWD <<< "$PARSED"

# Need a transcript to capture
if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Generate inbox filename (include session ID fragment to prevent same-second collisions)
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
SID_SHORT="${SESSION_ID:0:8}"
INBOX_FILE="$ASGARD_REPO/inbox/${TIMESTAMP}-${ASGARD_MACHINE}-${SID_SHORT}.md"

# Ensure inbox directory exists
mkdir -p "$ASGARD_REPO/inbox"

# Generate YAML frontmatter with properly escaped values
TIMESTAMP_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
FRONTMATTER=$(python3 -c '
import sys, json
machine, sid, cwd, ts = sys.argv[1:5]
print("---")
print(f"machine: {json.dumps(machine)}")
print(f"session_id: {json.dumps(sid)}")
print(f"cwd: {json.dumps(cwd)}")
print(f"timestamp: {json.dumps(ts)}")
print("---")
' "$ASGARD_MACHINE" "$SESSION_ID" "$CWD" "$TIMESTAMP_UTC")

# Write frontmatter + transcript content
{
  printf '%s\n\n' "$FRONTMATTER"
  cat "$TRANSCRIPT_PATH"
} > "$INBOX_FILE"

# Pull (rebase to handle concurrent pushes), add, commit, push — silent, best-effort
cd "$ASGARD_REPO"
INBOX_FILENAME="inbox/${TIMESTAMP}-${ASGARD_MACHINE}-${SID_SHORT}.md"
GIT_SSH_COMMAND="ssh -o ConnectTimeout=3" git pull --rebase --quiet 2>/dev/null || true
git add "$INBOX_FILENAME"
git commit --quiet -m "session: ${ASGARD_MACHINE} $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || true
GIT_SSH_COMMAND="ssh -o ConnectTimeout=3" git push --quiet 2>/dev/null || true
