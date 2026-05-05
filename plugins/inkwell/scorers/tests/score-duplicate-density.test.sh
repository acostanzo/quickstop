#!/usr/bin/env bash
# score-duplicate-density.test.sh — exercise
# scorers/score-duplicate-density.sh against the inkwell-duplicates,
# inkwell-marked, and plain fixtures.
#
# Cases:
#   1. inkwell-duplicates fixture → scorer emits a populated
#      observation with one near-duplicate pair across two docs.
#      Expected density 0.5000.
#   2. inkwell-marked fixture (no near-duplicates) → populated
#      observation with zero pairs and density 0.0000.
#   3. Plain fixture → empty stdout (empty-scope short-circuit).
#   4. Triple-run determinism on the populated paths.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-duplicate-density.sh"
DUPS="$HERE/fixtures/inkwell-duplicates"
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

# ---- inkwell-duplicates: 1 pair, density 0.5
out=$(triple_run "$DUPS")
assert_eq "dups id"      "inkwell-duplicate-density" "$(echo "$out" | jq -r .id)"
assert_eq "dups kind"    "ratio"                     "$(echo "$out" | jq -r .kind)"
assert_eq "dups pairs"   "1"                         "$(echo "$out" | jq -r .evidence.near_duplicate_pairs)"
assert_eq "dups total"   "2"                         "$(echo "$out" | jq -r .evidence.total_inkwell_docs)"
assert_eq "dups density" "0.5000"                    "$(echo "$out" | jq -r .evidence.density)"

# ---- inkwell-marked (no dups): 0 pairs, density 0.0
out=$(triple_run "$MARKED")
assert_eq "marked pairs"   "0"      "$(echo "$out" | jq -r .evidence.near_duplicate_pairs)"
assert_eq "marked total"   "5"      "$(echo "$out" | jq -r .evidence.total_inkwell_docs)"
assert_eq "marked density" "0.0000" "$(echo "$out" | jq -r .evidence.density)"

# ---- plain: empty-scope
out=$(triple_run "$PLAIN")
assert_eq "plain empty stdout" "" "$out"

if (( fail == 0 )); then
  echo "score-duplicate-density.test.sh: PASS"
  exit 0
else
  echo "score-duplicate-density.test.sh: FAIL" >&2
  exit 1
fi
