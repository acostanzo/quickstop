#!/usr/bin/env bash
# structured-logging-ratio.test.sh — exercise
# score-structured-logging-ratio.sh against per-language fixtures.
# Triple-runs each for byte-equivalence (the determinism invariant
# from the 2c2 ticket).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-structured-logging-ratio.sh"
FIXTURES="$HERE/fixtures/structured-logging"
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

# ---- python-structured: 5 logger.* calls, 0 print → ratio 1.0
out=$(triple_run "$FIXTURES/python-structured")
assert_eq "py-struct id"        "structured-logging-ratio" "$(echo "$out" | jq -r .id)"
assert_eq "py-struct kind"      "ratio"                    "$(echo "$out" | jq -r .kind)"
assert_eq "py-struct language"  "python"                   "$(echo "$out" | jq -r .evidence.language)"
assert_eq "py-struct struct"    "5"                        "$(echo "$out" | jq -r .evidence.structured_sites)"
assert_eq "py-struct total"     "5"                        "$(echo "$out" | jq -r .evidence.total_sites)"
assert_eq "py-struct ratio"     "1.0000"                   "$(echo "$out" | jq -r .evidence.ratio)"

# ---- python-mixed: 3 structured + 7 print → ratio 0.3
out=$(triple_run "$FIXTURES/python-mixed")
assert_eq "py-mixed struct"     "3"      "$(echo "$out" | jq -r .evidence.structured_sites)"
assert_eq "py-mixed total"      "10"     "$(echo "$out" | jq -r .evidence.total_sites)"
assert_eq "py-mixed ratio"      "0.3000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- python-freeform: 4 print, 0 structured → ratio 0.0 (emitted, NOT empty-scoped)
out=$(triple_run "$FIXTURES/python-freeform")
assert_eq "py-free struct"      "0"      "$(echo "$out" | jq -r .evidence.structured_sites)"
assert_eq "py-free total"       "4"      "$(echo "$out" | jq -r .evidence.total_sites)"
assert_eq "py-free ratio"       "0.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- ts-pino: 4 logger.* calls, 0 console.* → ratio 1.0
out=$(triple_run "$FIXTURES/ts-pino")
assert_eq "ts-pino language"    "typescript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ts-pino struct"      "4"          "$(echo "$out" | jq -r .evidence.structured_sites)"
assert_eq "ts-pino total"       "4"          "$(echo "$out" | jq -r .evidence.total_sites)"
assert_eq "ts-pino ratio"       "1.0000"     "$(echo "$out" | jq -r .evidence.ratio)"

# ---- ts-mixed: THE BAIT CASE — pino imported, but half the emit
# sites are console.log → ratio 0.4 (< 0.5, the explicit 2c2 acceptance bar).
out=$(triple_run "$FIXTURES/ts-mixed")
assert_eq "ts-mixed language"   "typescript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ts-mixed struct"     "4"          "$(echo "$out" | jq -r .evidence.structured_sites)"
assert_eq "ts-mixed total"      "10"         "$(echo "$out" | jq -r .evidence.total_sites)"
assert_eq "ts-mixed ratio"      "0.4000"     "$(echo "$out" | jq -r .evidence.ratio)"
ratio_below_half=$(awk -v r="$(echo "$out" | jq -r .evidence.ratio)" \
  'BEGIN { print (r < 0.5) ? "yes" : "no" }')
assert_eq "ts-mixed bait-acceptance (ratio < 0.5)" "yes" "$ratio_below_half"

# ---- go-zerolog: 4 slog.{Info|Warn|Error|Debug} → ratio 1.0
out=$(triple_run "$FIXTURES/go-zerolog")
assert_eq "go-zero language"    "go"     "$(echo "$out" | jq -r .evidence.language)"
assert_eq "go-zero struct"      "4"      "$(echo "$out" | jq -r .evidence.structured_sites)"
assert_eq "go-zero ratio"       "1.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- go-freeform: 5 fmt.* calls → ratio 0.0
out=$(triple_run "$FIXTURES/go-freeform")
assert_eq "go-free struct"      "0"      "$(echo "$out" | jq -r .evidence.structured_sites)"
assert_eq "go-free total"       "5"      "$(echo "$out" | jq -r .evidence.total_sites)"
assert_eq "go-free ratio"       "0.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- rust-tracing: 4 tracing::* calls → ratio 1.0
out=$(triple_run "$FIXTURES/rust-tracing")
assert_eq "rust language"       "rust"   "$(echo "$out" | jq -r .evidence.language)"
assert_eq "rust struct"         "4"      "$(echo "$out" | jq -r .evidence.structured_sites)"
assert_eq "rust ratio"          "1.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- empty: no language → empty-scope omit
out=$(triple_run "$FIXTURES/empty")
assert_eq "empty no output" "" "$out"

if (( fail == 0 )); then
  echo "structured-logging-ratio.test.sh: PASS"
  exit 0
else
  echo "structured-logging-ratio.test.sh: FAIL" >&2
  exit 1
fi
