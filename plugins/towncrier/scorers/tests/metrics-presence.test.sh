#!/usr/bin/env bash
# metrics-presence.test.sh — exercise score-metrics-presence.sh
# against per-language fixtures (full setup, imported-unused,
# nothing-configured, empty). Triple-runs each for byte-equivalence.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-metrics-presence.sh"
FIXTURES="$HERE/fixtures/metrics-presence"
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

# ---- python-prometheus: prometheus_client + 3 sites
out=$(triple_run "$FIXTURES/python-prometheus")
assert_eq "py-prom id"          "metrics-instrumentation-count" "$(echo "$out" | jq -r .id)"
assert_eq "py-prom kind"        "count"                          "$(echo "$out" | jq -r .kind)"
assert_eq "py-prom language"    "python"                         "$(echo "$out" | jq -r .evidence.language)"
assert_eq "py-prom configured"  "1"                              "$(echo "$out" | jq -r .evidence.configured)"
assert_eq "py-prom sites"       "3"                              "$(echo "$out" | jq -r .evidence.metrics_sites)"

# ---- python-otel-metrics: opentelemetry.metrics + 3 sites
out=$(triple_run "$FIXTURES/python-otel-metrics")
assert_eq "py-otel configured"  "1" "$(echo "$out" | jq -r .evidence.configured)"
assert_eq "py-otel sites"       "3" "$(echo "$out" | jq -r .evidence.metrics_sites)"

# ---- python-imported-unused: import line present, ZERO call sites.
# Acceptance bar: distinguishes "imported but unused" (configured: 1,
# metrics_sites: 0, EMITTED) from "not configured at all" (omitted).
out=$(triple_run "$FIXTURES/python-imported-unused")
assert_eq "py-unused configured" "1" "$(echo "$out" | jq -r .evidence.configured)"
assert_eq "py-unused sites"      "0" "$(echo "$out" | jq -r .evidence.metrics_sites)"

# ---- python-none: no library import, no sites → omitted (NOT 0/0).
out=$(triple_run "$FIXTURES/python-none")
assert_eq "py-none no output (not configured at all)" "" "$out"

# ---- ts-prom-client: prom-client + 3 new Counter/Histogram/Gauge + 1 .observe
out=$(triple_run "$FIXTURES/ts-prom-client")
assert_eq "ts language"    "typescript" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "ts configured"  "1"          "$(echo "$out" | jq -r .evidence.configured)"
assert_eq "ts sites"       "4"          "$(echo "$out" | jq -r .evidence.metrics_sites)"

# ---- go-prometheus: prometheus/client_golang + 3 NewCounter/Hist/Gauge
out=$(triple_run "$FIXTURES/go-prometheus")
assert_eq "go language"    "go" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "go configured"  "1"  "$(echo "$out" | jq -r .evidence.configured)"
assert_eq "go sites"       "3"  "$(echo "$out" | jq -r .evidence.metrics_sites)"

# ---- rust-metrics: Cargo.toml [dependencies] metrics = "..." + 3 macros
out=$(triple_run "$FIXTURES/rust-metrics")
assert_eq "rust language"   "rust" "$(echo "$out" | jq -r .evidence.language)"
assert_eq "rust configured" "1"    "$(echo "$out" | jq -r .evidence.configured)"
assert_eq "rust sites"      "3"    "$(echo "$out" | jq -r .evidence.metrics_sites)"

# ---- empty: no language → empty-scope omit
out=$(triple_run "$FIXTURES/empty")
assert_eq "empty no output" "" "$out"

if (( fail == 0 )); then
  echo "metrics-presence.test.sh: PASS"
  exit 0
else
  echo "metrics-presence.test.sh: FAIL" >&2
  exit 1
fi
