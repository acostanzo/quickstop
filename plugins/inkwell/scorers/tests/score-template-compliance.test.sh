#!/usr/bin/env bash
# score-template-compliance.test.sh — exercise
# scorers/score-template-compliance.sh against the inkwell-marked and
# plain fixtures.
#
# Cases (per the T5 brief):
#   1. Inkwell-marked fixture → scorer emits a populated observation.
#      The fixture has 5 inkwell-marked docs, 4 of which are
#      Diátaxis-valid + carry title/updated; 1 has an invalid
#      template value (counted as non-compliant). Expected ratio
#      0.8000.
#   2. Plain fixture (no inkwell frontmatter) → empty stdout
#      (empty-scope short-circuit, no observation, exit 0).
#   3. Triple-run determinism on the populated path.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-template-compliance.sh"
MARKED="$HERE/fixtures/inkwell-marked"
PLAIN="$HERE/fixtures/plain"
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL [$label]: expected '$expected', got '$actual'" >&2
    fail=1
  fi
}

triple_run() {
  local fixture="$1"
  local r1 r2 r3
  r1=$("$SCORER" "$fixture")
  r2=$("$SCORER" "$fixture")
  r3=$("$SCORER" "$fixture")
  if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
    echo "FAIL [$(basename "$fixture")]: triple-run output diverged" >&2
    echo "  r1=$r1" >&2
    echo "  r2=$r2" >&2
    echo "  r3=$r3" >&2
    fail=1
  fi
  printf '%s' "$r1"
}

# ---- inkwell-marked: populated observation
out=$(triple_run "$MARKED")
assert_eq "marked id"        "inkwell-template-compliance" "$(echo "$out" | jq -r .id)"
assert_eq "marked kind"      "ratio"                       "$(echo "$out" | jq -r .kind)"
assert_eq "marked compliant" "4"                           "$(echo "$out" | jq -r .evidence.compliant)"
assert_eq "marked total"     "5"                           "$(echo "$out" | jq -r .evidence.total)"
assert_eq "marked ratio"     "0.8000"                      "$(echo "$out" | jq -r .evidence.ratio)"

# ---- plain: empty-scope short-circuit
out=$(triple_run "$PLAIN")
assert_eq "plain empty stdout" "" "$out"

if (( fail == 0 )); then
  echo "score-template-compliance.test.sh: PASS"
  exit 0
else
  echo "score-template-compliance.test.sh: FAIL" >&2
  exit 1
fi
