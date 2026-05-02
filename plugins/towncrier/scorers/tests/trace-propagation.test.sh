#!/usr/bin/env bash
# trace-propagation.test.sh — exercise score-trace-propagation.sh
# against per-language fixtures (full instrumentation, bare SDK +
# untraced handlers, no handlers, empty). Triple-runs each for
# byte-equivalence.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-trace-propagation.sh"
FIXTURES="$HERE/fixtures/trace-propagation"
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

# ---- python-otel-full: 2 FastAPI handler files, both fully traced
out=$(triple_run "$FIXTURES/python-otel-full")
assert_eq "py-full id"          "trace-propagation-ratio" "$(echo "$out" | jq -r .id)"
assert_eq "py-full kind"        "ratio"                   "$(echo "$out" | jq -r .kind)"
assert_eq "py-full language"    "python"                  "$(echo "$out" | jq -r .evidence.language)"
assert_eq "py-full with_trace"  "2"                       "$(echo "$out" | jq -r .evidence.handlers_with_trace)"
assert_eq "py-full total"       "2"                       "$(echo "$out" | jq -r .evidence.handlers_total)"
assert_eq "py-full ratio"       "1.0000"                  "$(echo "$out" | jq -r .evidence.ratio)"

# ---- python-otel-bare: SDK setup but ZERO trace-context refs in
# handler files → ratio 0.0 (emitted; "infrastructure exists but
# isn't used" is a real signal worth surfacing).
out=$(triple_run "$FIXTURES/python-otel-bare")
assert_eq "py-bare with_trace" "0"      "$(echo "$out" | jq -r .evidence.handlers_with_trace)"
assert_eq "py-bare total"      "2"      "$(echo "$out" | jq -r .evidence.handlers_total)"
assert_eq "py-bare ratio"      "0.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- python-no-handlers: language detected but ZERO request-handler
# files → empty-scope omit. Acceptance bar: a CLI tool with no
# handler-shaped files shouldn't be falsely faulted for lacking
# trace propagation it never had occasion to need.
out=$(triple_run "$FIXTURES/python-no-handlers")
assert_eq "py-no-handlers no output (empty-scope)" "" "$out"

# ---- ts-otel-handlers: 2 express handler files, both traced
out=$(triple_run "$FIXTURES/ts-otel-handlers")
assert_eq "ts-full language"   "typescript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ts-full with_trace" "2"          "$(echo "$out" | jq -r .evidence.handlers_with_trace)"
assert_eq "ts-full total"      "2"          "$(echo "$out" | jq -r .evidence.handlers_total)"
assert_eq "ts-full ratio"      "1.0000"     "$(echo "$out" | jq -r .evidence.ratio)"

# ---- ts-handler-no-trace: 1 express handler file, no trace refs → ratio 0.0
out=$(triple_run "$FIXTURES/ts-handler-no-trace")
assert_eq "ts-no-trace with_trace" "0"      "$(echo "$out" | jq -r .evidence.handlers_with_trace)"
assert_eq "ts-no-trace total"      "1"      "$(echo "$out" | jq -r .evidence.handlers_total)"
assert_eq "ts-no-trace ratio"      "0.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- go-otel: 1 http.HandleFunc file, fully traced via tracer.Start
out=$(triple_run "$FIXTURES/go-otel")
assert_eq "go-otel language"   "go"     "$(echo "$out" | jq -r .evidence.language)"
assert_eq "go-otel with_trace" "1"      "$(echo "$out" | jq -r .evidence.handlers_with_trace)"
assert_eq "go-otel total"      "1"      "$(echo "$out" | jq -r .evidence.handlers_total)"
assert_eq "go-otel ratio"      "1.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# ---- empty: no language → empty-scope omit
out=$(triple_run "$FIXTURES/empty")
assert_eq "empty no output" "" "$out"

if (( fail == 0 )); then
  echo "trace-propagation.test.sh: PASS"
  exit 0
else
  echo "trace-propagation.test.sh: FAIL" >&2
  exit 1
fi
