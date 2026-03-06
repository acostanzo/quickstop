#!/bin/bash
# Bifrost — Capture session transcript to memory inbox
# Runs async on SessionEnd — zero noise, zero blocking

set -euo pipefail

CONFIG_FILE="${HOME}/.config/bifrost/config"

# Check config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

# Read config values safely (no arbitrary code execution)
BIFROST_REPO=$(grep '^BIFROST_REPO=' "$CONFIG_FILE" | cut -d= -f2-)
BIFROST_MACHINE=$(grep '^BIFROST_MACHINE=' "$CONFIG_FILE" | cut -d= -f2-)

# Validate required config
if [[ -z "${BIFROST_REPO:-}" || -z "${BIFROST_MACHINE:-}" ]]; then
  exit 0
fi

# Validate machine name format (defense in depth — SKILL.md also validates during setup)
if [[ ! "$BIFROST_MACHINE" =~ ^[a-z0-9-]+$ ]]; then
  exit 0
fi

# Expand ~ in repo path
BIFROST_REPO="${BIFROST_REPO/#\~/$HOME}"

# Check repo exists
if [[ ! -d "$BIFROST_REPO" ]]; then
  exit 0
fi

# Read session info from stdin JSON (Claude Code SessionEnd hook contract)
# Expected fields: transcript_path, session_id, cwd
INPUT=$(cat)
IFS=$'\t' read -r TRANSCRIPT_PATH SESSION_ID CWD <<< "$(printf '%s' "$INPUT" | python3 -c '
import sys,json
d=json.load(sys.stdin)
print(d.get("transcript_path",""), d.get("session_id",""), d.get("cwd",""), sep="\t")
' 2>/dev/null || printf '')"

# Need a transcript to capture
if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Generate inbox filename (include session ID fragment to prevent same-second collisions)
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
SID_SHORT="${SESSION_ID:0:8}"
INBOX_FILE="$BIFROST_REPO/inbox/${TIMESTAMP}-${BIFROST_MACHINE}-${SID_SHORT}.md"

# Ensure inbox directory exists
mkdir -p "$BIFROST_REPO/inbox"

# Generate YAML frontmatter with properly escaped values (json.dumps handles special chars)
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
' "$BIFROST_MACHINE" "$SESSION_ID" "$CWD" "$TIMESTAMP_UTC")

# Write frontmatter + transcript content
{
  printf '%s\n\n' "$FRONTMATTER"
  cat "$TRANSCRIPT_PATH"
} > "$INBOX_FILE"

# Pull (rebase to handle concurrent pushes), add, commit, push — silent, best-effort
cd "$BIFROST_REPO"
INBOX_FILENAME="inbox/${TIMESTAMP}-${BIFROST_MACHINE}-${SID_SHORT}.md"
GIT_SSH_COMMAND="ssh -o ConnectTimeout=3" git pull --rebase --quiet 2>/dev/null || true
git add "$INBOX_FILENAME"
git commit --quiet -m "session: ${BIFROST_MACHINE} $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || true
GIT_SSH_COMMAND="ssh -o ConnectTimeout=3" git push --quiet 2>/dev/null || true
