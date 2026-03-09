#!/bin/bash
# Bifrost — Capture session transcript to memory inbox
# Runs async on SessionEnd — zero noise, zero blocking
#
# Fix over original Bifrost:
# - B-5: Basic validation of stdin JSON structure before processing

set -euo pipefail

CONFIG_FILE="${HOME}/.config/bifrost/config"

# Check config exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "bifrost: config not found at $CONFIG_FILE" >&2
  exit 0
fi

# Read config values safely (no arbitrary code execution)
BIFROST_REPO=$(grep '^BIFROST_REPO=' "$CONFIG_FILE" | cut -d= -f2- || true)
BIFROST_MACHINE=$(grep '^BIFROST_MACHINE=' "$CONFIG_FILE" | cut -d= -f2- || true)

# Validate required config
if [[ -z "${BIFROST_REPO:-}" || -z "${BIFROST_MACHINE:-}" ]]; then
  echo "bifrost: BIFROST_REPO or BIFROST_MACHINE not set in config" >&2
  exit 0
fi

# Validate machine name format
if [[ ! "$BIFROST_MACHINE" =~ ^[a-z0-9-]+$ ]]; then
  echo "bifrost: invalid machine name '${BIFROST_MACHINE}'" >&2
  exit 0
fi

# Expand ~ in repo path
BIFROST_REPO="${BIFROST_REPO/#\~/$HOME}"

# Check repo exists
if [[ ! -d "$BIFROST_REPO" ]]; then
  echo "bifrost: memory repo not found at ${BIFROST_REPO}" >&2
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
  echo "bifrost: invalid JSON on stdin" >&2
  exit 0
}

IFS=$'\t' read -r TRANSCRIPT_PATH SESSION_ID CWD <<< "$PARSED"

# Need a transcript to capture
if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Skip if session was inside the memory repo — avoid feedback loops
RESOLVED_REPO=$(cd "$BIFROST_REPO" && pwd -P)
RESOLVED_CWD=$(cd "$CWD" 2>/dev/null && pwd -P || echo "")
if [[ -n "$RESOLVED_CWD" && ( "$RESOLVED_CWD" == "$RESOLVED_REPO" || "$RESOLVED_CWD" == "$RESOLVED_REPO"/* ) ]]; then
  echo "bifrost: skipping capture — session was inside memory repo" >&2
  exit 0
fi

# Generate inbox filename (include session ID fragment to prevent same-second collisions)
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
SID_SHORT="${SESSION_ID:0:8}"
INBOX_FILE="$BIFROST_REPO/inbox/${TIMESTAMP}-${BIFROST_MACHINE}-${SID_SHORT}.jsonl"

# Ensure inbox directory exists
mkdir -p "$BIFROST_REPO/inbox"

# Write pure JSONL: metadata as first line, then raw transcript
# The transcript is already JSONL (Claude Code's native format)
TIMESTAMP_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
{
  python3 -c '
import sys, json
meta = {
    "_type": "bifrost_meta",
    "machine": sys.argv[1],
    "session_id": sys.argv[2],
    "cwd": sys.argv[3],
    "timestamp": sys.argv[4]
}
print(json.dumps(meta))
' "$BIFROST_MACHINE" "$SESSION_ID" "$CWD" "$TIMESTAMP_UTC"
  cat "$TRANSCRIPT_PATH"
} > "$INBOX_FILE"

# Pull (rebase to handle concurrent pushes), add, commit, push — silent, best-effort
cd "$BIFROST_REPO"
INBOX_FILENAME="inbox/${TIMESTAMP}-${BIFROST_MACHINE}-${SID_SHORT}.jsonl"
GIT_SSH_COMMAND="ssh -o ConnectTimeout=3" git pull --rebase --quiet 2>/dev/null || true
git add "$INBOX_FILENAME"
git commit --quiet -m "session: ${BIFROST_MACHINE} $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || true
GIT_SSH_COMMAND="ssh -o ConnectTimeout=3" git push --quiet 2>/dev/null || true
