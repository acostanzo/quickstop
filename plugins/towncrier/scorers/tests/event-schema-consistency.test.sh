#!/usr/bin/env bash
# event-schema-consistency.test.sh — exercise
# score-event-schema-consistency.sh against per-language fixtures
# (clean, bait, ts-mixed, empty). Triple-runs each for byte-equivalence
# (the determinism invariant from the 2c2 ticket).
#
# python-bait carries the explicit 2c2 acceptance bar:
# 3 well-shaped + 7 freeform-structured -> ratio 0.30 across runs.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-event-schema-consistency.sh"
FIXTURES="$HERE/fixtures/event-schema-consistency"
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

# ---- python-clean: 3 logger.info calls, all event= → ratio 1.0
out=$(triple_run "$FIXTURES/python-clean")
assert_eq "py-clean id"            "event-schema-consistency-ratio" "$(echo "$out" | jq -r .id)"
assert_eq "py-clean kind"          "ratio"                          "$(echo "$out" | jq -r .kind)"
assert_eq "py-clean language"      "python"                         "$(echo "$out" | jq -r .evidence.language)"
assert_eq "py-clean well_shaped"   "3"                              "$(echo "$out" | jq -r .evidence.well_shaped_events)"
assert_eq "py-clean total"         "3"                              "$(echo "$out" | jq -r .evidence.total_events)"
assert_eq "py-clean ratio"         "1.0000"                         "$(echo "$out" | jq -r .evidence.ratio)"
assert_eq "py-clean distinct"      "3"                              "$(echo "$out" | jq -r .evidence.distinct_schemas)"

# ---- python-bait: THE ACCEPTANCE BAR — 3 well-shaped + 7 freeform-
# structured → ratio 0.3000 across three runs (deterministic, no
# float drift).
out=$(triple_run "$FIXTURES/python-bait")
assert_eq "py-bait well_shaped" "3"      "$(echo "$out" | jq -r .evidence.well_shaped_events)"
assert_eq "py-bait total"       "10"     "$(echo "$out" | jq -r .evidence.total_events)"
assert_eq "py-bait ratio"       "0.3000" "$(echo "$out" | jq -r .evidence.ratio)"
assert_eq "py-bait distinct"    "3"      "$(echo "$out" | jq -r .evidence.distinct_schemas)"

# ---- ts-mixed: 3 well-shaped object literals + 7 freeform → ratio 0.30
out=$(triple_run "$FIXTURES/ts-mixed")
assert_eq "ts-mixed language"    "typescript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ts-mixed well_shaped" "3"          "$(echo "$out" | jq -r .evidence.well_shaped_events)"
assert_eq "ts-mixed total"       "10"         "$(echo "$out" | jq -r .evidence.total_events)"
assert_eq "ts-mixed ratio"       "0.3000"     "$(echo "$out" | jq -r .evidence.ratio)"
assert_eq "ts-mixed distinct"    "3"          "$(echo "$out" | jq -r .evidence.distinct_schemas)"

# ---- empty: no language → empty-scope omit
out=$(triple_run "$FIXTURES/empty")
assert_eq "empty no output" "" "$out"

if (( fail == 0 )); then
  echo "event-schema-consistency.test.sh: PASS"
  exit 0
else
  echo "event-schema-consistency.test.sh: FAIL" >&2
  exit 1
fi
