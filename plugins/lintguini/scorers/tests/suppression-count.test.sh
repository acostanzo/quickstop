#!/usr/bin/env bash
# suppression-count.test.sh — exercise score-suppression-count.sh
# against per-language fixtures (clean, noisy, bait, go, empty).
# Triple-runs each for byte-equivalence.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-suppression-count.sh"
FIXTURES="$HERE/fixtures/suppression-count"
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
    fail=1
  fi
  printf '%s' "$r1"
}

# python-clean: 2 .py files, zero suppressions → emit count=0
out=$(triple_run "$FIXTURES/python-clean")
assert_eq "python-clean id"           "lint-suppression-count" "$(echo "$out" | jq -r .id)"
assert_eq "python-clean kind"         "count"                  "$(echo "$out" | jq -r .kind)"
assert_eq "python-clean language"     "python"                 "$(echo "$out" | jq -r .evidence.language)"
assert_eq "python-clean suppressions" "0"                      "$(echo "$out" | jq -r .evidence.suppressions)"
assert_eq "python-clean scanned"      "2"                      "$(echo "$out" | jq -r .evidence.files_scanned)"

# python-noisy: 4 .py files, 11 suppressions (verified by grep against fixture)
out=$(triple_run "$FIXTURES/python-noisy")
assert_eq "python-noisy suppressions" "11" "$(echo "$out" | jq -r .evidence.suppressions)"
assert_eq "python-noisy scanned"      "4"  "$(echo "$out" | jq -r .evidence.files_scanned)"

# js-bait: 3 .js files × 12 eslint-disable* markers each → 36 (post JS/TS
# dispatch split — the @ts-* fixtures (c.js / e.js) moved to ts-bait/
# under tsconfig.json dispatch). Still exercises the JS-only path's
# bait shape (concentrated suppressions across few files); the counted
# value is just lower because pure-JS bait has fewer marker shapes
# than mixed-JS-with-TS-helpers did before the split.
out=$(triple_run "$FIXTURES/js-bait")
assert_eq "js-bait language"     "javascript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "js-bait suppressions" "36"         "$(echo "$out" | jq -r .evidence.suppressions)"
assert_eq "js-bait scanned"      "3"          "$(echo "$out" | jq -r .evidence.files_scanned)"
assert_eq "js-bait threshold"    "50"         "$(echo "$out" | jq -r .evidence.threshold_high)"

# ts-bait: 5 .ts files × 12 markers each → 60. Mixed marker shapes
# exercise both the eslint-disable* and @ts-* branches of the TS regex:
#   a.ts: 12 @ts-ignore         b.ts: 12 @ts-expect-error
#   c.ts: 12 @ts-nocheck        d.ts: 12 // eslint-disable-next-line
#   e.ts: 12 // eslint-disable-line
# Verifies that the TS regex strictly supersets the JS regex (every
# JS marker is a TS marker too) and adds the @ts-* shapes.
out=$(triple_run "$FIXTURES/ts-bait")
assert_eq "ts-bait language"     "typescript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ts-bait suppressions" "60"         "$(echo "$out" | jq -r .evidence.suppressions)"
assert_eq "ts-bait scanned"      "5"          "$(echo "$out" | jq -r .evidence.files_scanned)"
assert_eq "ts-bait threshold"    "50"         "$(echo "$out" | jq -r .evidence.threshold_high)"

# go: 2 .go files, 1 //nolint marker
out=$(triple_run "$FIXTURES/go")
assert_eq "go language"     "go" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "go suppressions" "1"  "$(echo "$out" | jq -r .evidence.suppressions)"
assert_eq "go scanned"      "2"  "$(echo "$out" | jq -r .evidence.files_scanned)"

# empty: no language → omit
out=$(triple_run "$FIXTURES/empty")
assert_eq "empty no output" "" "$out"

if (( fail == 0 )); then
  echo "suppression-count.test.sh: PASS"
  exit 0
else
  echo "suppression-count.test.sh: FAIL" >&2
  exit 1
fi
