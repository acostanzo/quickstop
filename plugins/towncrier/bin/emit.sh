#!/usr/bin/env bash
# towncrier emit — read a Claude Code hook payload on stdin, wrap it in a
# structured envelope, and dispatch to the configured transport.
#
# Hard guarantees:
#   - Returns within ~2s even if the transport is unreachable.
#   - On any transport failure, appends the envelope to the default fallback
#     file so events are never silently dropped.
#   - Always exits 0 and writes nothing to stdout, so Claude's hook flow is
#     never altered by this script (PermissionRequest stays pass-through).

set -u

EVENT_NAME="${1:-Unknown}"

CONFIG_DIR="${HOME}/.towncrier"
CONFIG_FILE="${CONFIG_DIR}/config.json"
FALLBACK_FILE="${CONFIG_DIR}/events.jsonl"
TIMEOUT_SECONDS=2

# Locate a timeout binary. GNU coreutils ships `timeout`; macOS users typically
# install `gtimeout` via `brew install coreutils`. If neither is present we fall
# back to running the dispatcher unbounded — the hook-level timeout in
# hooks.json (5s) becomes the only backstop.
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
fi

PAYLOAD="$(cat)"
[ -z "$PAYLOAD" ] && PAYLOAD='{}'

cfg() {
  [ -r "$CONFIG_FILE" ] || return 1
  jq -r "$1 // empty" "$CONFIG_FILE" 2>/dev/null
}

TRANSPORT="${TOWNCRIER_TRANSPORT:-}"
[ -z "$TRANSPORT" ] && TRANSPORT="$(cfg '.transport')"
[ -z "$TRANSPORT" ] && TRANSPORT="file:${FALLBACK_FILE}"

if [ -r "$CONFIG_FILE" ]; then
  if jq -e --arg e "$EVENT_NAME" '.skip_events // [] | index($e)' "$CONFIG_FILE" >/dev/null 2>&1; then
    exit 0
  fi
fi

gen_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  elif [ -r /proc/sys/kernel/random/uuid ]; then
    cat /proc/sys/kernel/random/uuid
  else
    printf '%08x-%04x-%04x-%04x-%012x\n' \
      "$RANDOM$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM" "$RANDOM$RANDOM$RANDOM"
  fi
}

ID="$(gen_uuid)"
# UTC RFC 3339 — portable across GNU and BSD `date`. Strict parsers (e.g. Go's
# time.RFC3339) require the trailing `Z` rather than `+0000`.
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOST="$(hostname 2>/dev/null || echo unknown)"
SESSION_ID="$(printf '%s' "$PAYLOAD" | jq -r '.session_id // ""' 2>/dev/null)"
CWD="$(printf '%s' "$PAYLOAD" | jq -r '.cwd // ""' 2>/dev/null)"
# $PPID of this script is the shell that ran us, which Claude invoked.
# That shell's parent is Claude itself; fall back to $PPID if /proc isn't available.
CLAUDE_PID="$(awk '/^PPid:/ {print $2}' "/proc/$PPID/status" 2>/dev/null || echo "$PPID")"

ENVELOPE="$(jq -cn \
  --arg id "$ID" \
  --arg ts "$TS" \
  --arg type "hook.${EVENT_NAME}" \
  --arg host "$HOST" \
  --arg sid "$SESSION_ID" \
  --argjson pid "${CLAUDE_PID:-0}" \
  --arg cwd "$CWD" \
  --argjson data "$PAYLOAD" \
  '{id:$id, ts:$ts, source:"claude-hook", type:$type, host:$host, session_id:$sid, pid:$pid, cwd:$cwd, data:$data}' 2>/dev/null)"

if [ -z "$ENVELOPE" ]; then
  ENVELOPE="$(jq -cn \
    --arg id "$ID" \
    --arg ts "$TS" \
    --arg type "hook.${EVENT_NAME}" \
    --arg host "$HOST" \
    --arg sid "$SESSION_ID" \
    --argjson pid "${CLAUDE_PID:-0}" \
    --arg cwd "$CWD" \
    --arg raw "$PAYLOAD" \
    '{id:$id, ts:$ts, source:"claude-hook", type:$type, host:$host, session_id:$sid, pid:$pid, cwd:$cwd, data:{raw:$raw, parse_error:true}}')"
fi

fallback() {
  mkdir -p "$CONFIG_DIR" 2>/dev/null
  printf '%s\n' "$ENVELOPE" >> "$FALLBACK_FILE" 2>/dev/null || true
}

expand_path() {
  # Expand a leading `~` or `~/` to $HOME — bash parameter expansion of `${1#file:}`
  # does NOT do tilde expansion, so we do it explicitly.
  local p="$1"
  case "$p" in
    "~")    printf '%s' "$HOME" ;;
    "~/"*)  printf '%s' "${HOME}/${p#\~/}" ;;
    *)      printf '%s' "$p" ;;
  esac
}

with_timeout() {
  # Run "$@" under the resolved timeout binary, or unbounded if neither is available.
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" "$TIMEOUT_SECONDS" "$@"
  else
    "$@"
  fi
}

dispatch_file() {
  local path
  path="$(expand_path "${1#file:}")"
  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir" 2>/dev/null || return 1
  # Wrap the append in a timeout: a path that resolves to a fifo, a stalled NFS
  # mount, or a full disk could otherwise block indefinitely.
  printf '%s\n' "$ENVELOPE" | with_timeout tee -a "$path" >/dev/null
}

dispatch_fifo() {
  local path
  path="$(expand_path "${1#fifo:}")"
  [ -p "$path" ] || return 1
  # Blocking open on a fifo with no reader would hang; timeout bounds it.
  printf '%s\n' "$ENVELOPE" | with_timeout tee "$path" >/dev/null
}

dispatch_http() {
  command -v curl >/dev/null 2>&1 || return 1
  curl -s --max-time "$TIMEOUT_SECONDS" --fail \
    -H 'Content-Type: application/json' \
    -X POST \
    --data-binary "$ENVELOPE" \
    "$1" >/dev/null 2>&1
}

case "$TRANSPORT" in
  file:*)
    dispatch_file "$TRANSPORT" || fallback
    ;;
  fifo:*)
    dispatch_fifo "$TRANSPORT" || fallback
    ;;
  http://*|https://*)
    dispatch_http "$TRANSPORT" || fallback
    ;;
  *)
    fallback
    ;;
esac

exit 0
