#!/usr/bin/env bash
# eval-categorize.sh — classify a failed /pronto:audit invocation.
#
# Takes the captured stdout, stderr, and exit code from a single audit
# run and emits a single-line JSON object describing the failure mode.
# Designed to be called inline from eval.sh and standalone for post-hoc
# batch categorization of preserved run directories.
#
# Categories (per phase-2 PR H2a spec):
#   prose-contamination   stdout contains valid JSON wrapped in prose
#                         (chat preamble, postamble, or both)
#   partial-emission      stdout has unbalanced braces — JSON truncated
#                         mid-stream (suggests timeout/abort)
#   refusal-or-empty      stdout is empty, whitespace-only, or contains
#                         a refusal/apology with no JSON content
#   contract-violation    stdout parses as JSON but pronto's contract is
#                         not met (composite missing, dimensions partial,
#                         stub emission, etc). Passed in via --contract.
#   exit-nonzero          claude CLI exited non-zero. Sub-reason carries
#                         the exit code; stderr last line is captured.
#   other                 none of the above (parse failure that's not
#                         truncation; unrecognized shape).
#
# Output shape (single-line JSON to stdout):
#   {
#     "category":   "<one of the above>",
#     "sub_reason": "<short string giving more detail>",
#     "evidence":   {
#       "stdout_head": "<first 500 chars of stdout, or null>",
#       "stdout_tail": "<last 200 chars of stdout, or null>",
#       "stderr_tail": "<last 500 chars of stderr, or null>"
#     }
#   }
#
# Usage:
#   eval-categorize.sh --stdout <path> --exit-code <int> \
#                      [--stderr <path>] [--contract <violation-string>]
#
# Exit codes:
#   0  classification succeeded (always — even "other" is a result)
#   2  caller-side bug (missing required arg, file not readable)

set -uo pipefail

err() {
  echo "eval-categorize: $*" >&2
  exit 2
}

STDOUT_FILE=""
STDERR_FILE=""
EXIT_CODE=""
CONTRACT_VIOLATION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stdout)    STDOUT_FILE="${2:-}"; shift 2 ;;
    --stderr)    STDERR_FILE="${2:-}"; shift 2 ;;
    --exit-code) EXIT_CODE="${2:-}";   shift 2 ;;
    --contract)  CONTRACT_VIOLATION="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) err "unknown argument: $1" ;;
  esac
done

[[ -n "$STDOUT_FILE" ]] || err "missing required --stdout"
[[ -n "$EXIT_CODE"   ]] || err "missing required --exit-code"
[[ -f "$STDOUT_FILE" ]] || err "stdout file not readable: $STDOUT_FILE"
if [[ -n "$STDERR_FILE" && ! -f "$STDERR_FILE" ]]; then
  err "stderr file not readable: $STDERR_FILE"
fi
if ! [[ "$EXIT_CODE" =~ ^-?[0-9]+$ ]]; then
  err "--exit-code must be an integer (got: $EXIT_CODE)"
fi

# Excerpt helpers — bounded reads so a 50MB pathological stdout doesn't
# bloat eval-results.json. jq -Rs handles arbitrary bytes safely.
excerpt_head() {
  local file="$1" n="$2"
  if [[ ! -s "$file" ]]; then echo null; return; fi
  head -c "$n" "$file" | jq -Rs .
}

excerpt_tail() {
  local file="$1" n="$2"
  if [[ ! -s "$file" ]]; then echo null; return; fi
  tail -c "$n" "$file" | jq -Rs .
}

STDOUT_HEAD=$(excerpt_head "$STDOUT_FILE" 500)
STDOUT_TAIL=$(excerpt_tail "$STDOUT_FILE" 200)
if [[ -n "$STDERR_FILE" ]]; then
  STDERR_TAIL=$(excerpt_tail "$STDERR_FILE" 500)
else
  STDERR_TAIL=null
fi

emit() {
  local category="$1" sub_reason="$2"
  jq -n \
    --arg category   "$category" \
    --arg sub_reason "$sub_reason" \
    --argjson stdout_head "$STDOUT_HEAD" \
    --argjson stdout_tail "$STDOUT_TAIL" \
    --argjson stderr_tail "$STDERR_TAIL" \
    '{
       category:   $category,
       sub_reason: $sub_reason,
       evidence: {
         stdout_head: $stdout_head,
         stdout_tail: $stdout_tail,
         stderr_tail: $stderr_tail
       }
     }' \
  | jq -c .
  exit 0
}

# --- Decision ladder ---------------------------------------------------------

# 1. Contract violation explicitly passed in by the caller — preserve it.
#    eval.sh already runs the contract check; passing the string through
#    keeps the helper from re-implementing the same logic.
if [[ -n "$CONTRACT_VIOLATION" ]]; then
  emit "contract-violation" "$CONTRACT_VIOLATION"
fi

# 2. Non-zero exit code from the claude CLI itself — surface the code.
#    Stderr-tail in evidence captures any timeout/signal text. We do not
#    branch on stderr content here; the operator gets the raw tail and
#    decides. (Earlier draft branched on /timeout|killed/ matches but
#    that conflated CLI-level timeouts with model-side stop reasons,
#    which look different in stderr.)
if (( EXIT_CODE != 0 )); then
  emit "exit-nonzero" "exit_code=$EXIT_CODE"
fi

# Read stdout once for content checks. `cat` is fine — the file is
# already on disk and bounded by claude's actual output.
STDOUT_CONTENT="$(cat "$STDOUT_FILE")"
STDOUT_TRIMMED="$(printf '%s' "$STDOUT_CONTENT" | tr -d '[:space:]')"

# 3. Empty / whitespace-only stdout despite rc=0 — refusal or hung emit.
if [[ -z "$STDOUT_TRIMMED" ]]; then
  emit "refusal-or-empty" "empty"
fi

# 4. No JSON-object brace anywhere — likely a refusal or freeform reply.
#    (We don't try to detect arrays; pronto's audit contract is an object.)
if ! grep -q '{' "$STDOUT_FILE"; then
  # Common refusal/apology patterns. Not exhaustive — "other" catches the
  # rest. The point is naming the dominant pattern, not enumerating all.
  if echo "$STDOUT_CONTENT" | grep -qiE "i (can'?t|cannot|am unable|won'?t)|i'?m sorry|apolog(y|ies)|i'?m not able"; then
    emit "refusal-or-empty" "refusal"
  fi
  emit "refusal-or-empty" "no-json"
fi

# 5. JSON-shaped content present but full-stdout parse already failed
#    (eval.sh ran `jq -e .` before invoking this helper, so we know the
#    full doc doesn't parse). Distinguish prose-wrap from truncation.

# Brace balance: count { vs } across the full stdout. Open > close means
# the closing brace never arrived → partial emission. Equal counts but
# parse-fail means structurally broken JSON or prose around it.
BRACE_OPEN=$(tr -cd '{' < "$STDOUT_FILE" | wc -c | tr -d ' ')
BRACE_CLOSE=$(tr -cd '}' < "$STDOUT_FILE" | wc -c | tr -d ' ')

if (( BRACE_OPEN > BRACE_CLOSE )); then
  emit "partial-emission" "unbalanced_braces open=$BRACE_OPEN close=$BRACE_CLOSE"
fi

# 6. Brace counts match. Try to extract the largest top-level {...} block
#    and see if it parses on its own — if so, the failure is prose around
#    valid JSON (preamble, postamble, or both).
#
#    Strategy: find first `{` and last `}`, slice between them inclusive,
#    and try to parse. This handles "Here's the audit:\n{...}\nDone!" and
#    "{...}\n\nLet me know if you need anything else." It does NOT handle
#    multiple JSON blocks concatenated — that's "other" territory.
FIRST_BRACE=$(grep -bo '{' "$STDOUT_FILE" | head -n1 | cut -d: -f1)
LAST_BRACE=$(grep -bo '}' "$STDOUT_FILE" | tail -n1 | cut -d: -f1)

if [[ -n "$FIRST_BRACE" && -n "$LAST_BRACE" ]] && (( LAST_BRACE >= FIRST_BRACE )); then
  SLICE_LEN=$(( LAST_BRACE - FIRST_BRACE + 1 ))
  # `jq -es 'length == 1'`: -s slurps the input into an array of all
  # parsed values; the length==1 guard rejects two-objects-concatenated
  # like `{"a":1}{"b":2}` which `jq -e .` alone would accept (it stops
  # at the first complete value). For prose-wrap we want exactly one
  # JSON value in the slice.
  if dd if="$STDOUT_FILE" bs=1 skip="$FIRST_BRACE" count="$SLICE_LEN" 2>/dev/null \
       | jq -es 'length == 1' >/dev/null 2>&1; then
    emit "prose-contamination" "json_at_offset=$FIRST_BRACE-$LAST_BRACE"
  fi
fi

# 7. None of the above — structurally malformed JSON, multiple blocks, or
#    something we don't recognize. The evidence excerpts let an operator
#    look at it directly and propose a new bucket if a pattern emerges.
emit "other" "unrecognized_shape"
