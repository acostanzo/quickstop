#!/usr/bin/env bash
# readme-quality.test.sh — exercise score-readme-quality.sh against
# four fixtures (full, partial, bare, empty). Each populated fixture
# is triple-run to verify byte-equivalent output across runs (the
# determinism invariant from the 2a2 ticket).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-readme-quality.sh"
FIXTURES="$HERE/fixtures/readme"
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

# ---- full: all five arrival questions answered → ratio 1.0
out=$(triple_run "$FIXTURES/full")
assert_eq "full id"       "readme-arrival-coverage" "$(echo "$out" | jq -r .id)"
assert_eq "full kind"     "ratio"                   "$(echo "$out" | jq -r .kind)"
assert_eq "full matched"  "5"                       "$(echo "$out" | jq -r .evidence.matched)"
assert_eq "full expected" "5"                       "$(echo "$out" | jq -r .evidence.expected)"
assert_eq "full ratio"    "1.0000"                  "$(echo "$out" | jq -r .evidence.ratio)"

# ---- partial: Q1 (body text), Q3 (Installation), Q5 (docs/ link) → 3/5
out=$(triple_run "$FIXTURES/partial")
assert_eq "partial matched" "3"      "$(echo "$out" | jq -r .evidence.matched)"
assert_eq "partial ratio"   "0.6000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- bare: H1 only, two empty sections, no body → zero questions hit
out=$(triple_run "$FIXTURES/bare")
assert_eq "bare matched" "0"      "$(echo "$out" | jq -r .evidence.matched)"
assert_eq "bare ratio"   "0.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- empty: no README.md → empty-scope short-circuit (empty stdout)
out=$(triple_run "$FIXTURES/empty")
assert_eq "empty no output" "" "$out"

if (( fail == 0 )); then
  echo "readme-quality.test.sh: PASS"
  exit 0
else
  echo "readme-quality.test.sh: FAIL" >&2
  exit 1
fi
