#!/usr/bin/env bash
# cases.test.sh — invariant-C regression suite for the v2.0 trailer-stripping
# capability. Pipes each case's input through bin/strip-trailers.sh and
# asserts byte-equivalence with the expected value pinned in cases.json.
#
# The expected values were derived (once, at fixture-creation time) by
# running the exact perl substitution chain that v1.x's
# hooks/enforce-ownership.sh shipped — see generate-cases.sh for the
# canonical chain. Drift between bin/strip-trailers.sh and these expected
# values is a ship-blocker per the migration ticket.
#
# Run: ./cases.test.sh
# Exits 0 on all-green, non-zero on any failing case.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STRIPPER="$PLUGIN_ROOT/bin/strip-trailers.sh"
CASES="$SCRIPT_DIR/cases.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "FATAL: jq required" >&2
  exit 2
fi
if [[ ! -x "$STRIPPER" ]]; then
  echo "FATAL: stripper not executable: $STRIPPER" >&2
  exit 2
fi
if [[ ! -f "$CASES" ]]; then
  echo "FATAL: cases.json not found: $CASES" >&2
  exit 2
fi

PASS=0
FAIL=0
FAILURES=()

note_pass() { PASS=$((PASS + 1)); }
note_fail() {
  FAIL=$((FAIL + 1))
  FAILURES+=("$1")
}

NUM_CASES=$(jq 'length' "$CASES")

for ((i = 0; i < NUM_CASES; i++)); do
  name=$(jq -r ".[$i].name" "$CASES")
  input=$(jq -r ".[$i].input" "$CASES")
  expected=$(jq -r ".[$i].expected" "$CASES")

  actual=$(printf '%s' "$input" | bash "$STRIPPER" 2>/dev/null) || {
    note_fail "$name: stripper exited non-zero"
    continue
  }

  if [[ "$actual" == "$expected" ]]; then
    note_pass
  else
    note_fail "$name: output diverged from expected"
    {
      echo "  --- expected ---"
      printf '%s\n' "$expected" | sed 's/^/    /'
      echo "  --- actual ---"
      printf '%s\n' "$actual" | sed 's/^/    /'
    } >&2
  fi
done

echo
if (( FAIL == 0 )); then
  echo "OK — $PASS / $NUM_CASES cases passed"
  exit 0
else
  echo "FAIL — $PASS passed, $FAIL failed (of $NUM_CASES)" >&2
  for msg in "${FAILURES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi
