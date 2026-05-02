#!/usr/bin/env bash
# link-health.test.sh — exercise score-link-health.sh against the
# empty-scope fixture and the vendored-broken fixture. Behaviour
# branches on lychee availability:
#
#   lychee on PATH  -> verify counts against the vendored fixture
#                      (3 broken links, 1 broken anchor across N
#                      scanned). Triple-run determinism check.
#   lychee absent   -> verify empty stdout + stderr notice, exit 0.
#
# The empty-scope fixture (no README, no docs/) always asserts empty
# stdout regardless of lychee availability.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-link-health.sh"
FIXTURES="$HERE/fixtures/link-health"
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

# ---- empty: no README.md, no docs/ → empty-scope short-circuit
out=$(triple_run "$FIXTURES/empty")
assert_eq "empty no output" "" "$out"

# ---- vendored-broken: branch on lychee availability
if command -v lychee >/dev/null 2>&1; then
  out=$(triple_run "$FIXTURES/vendored-broken")
  assert_eq "vendored-broken id"   "broken-internal-links-count" "$(echo "$out" | jq -r .id)"
  assert_eq "vendored-broken kind" "count"                       "$(echo "$out" | jq -r .kind)"
  # broken: at least 3 (the three deliberately-broken on-disk links).
  # The exact count may include the broken anchor depending on how
  # lychee categorises anchor failures across versions; assert >=3.
  broken=$(echo "$out" | jq -r '.evidence.broken')
  if (( broken < 3 )); then
    echo "FAIL [vendored-broken broken count]: expected >=3, got $broken" >&2
    fail=1
  fi
  scanned=$(echo "$out" | jq -r '.evidence.scanned')
  if (( scanned < 1 )); then
    echo "FAIL [vendored-broken scanned]: expected >=1, got $scanned" >&2
    fail=1
  fi
  echo "  vendored-broken (lychee present): broken=$broken, scanned=$scanned"
else
  # Tool-absent branch: empty stdout, exit 0.
  out=$("$SCORER" "$FIXTURES/vendored-broken" 2>/dev/null)
  assert_eq "vendored-broken (lychee absent) no stdout" "" "$out"
  # Stderr notice should mention lychee.
  err=$("$SCORER" "$FIXTURES/vendored-broken" 2>&1 >/dev/null)
  if [[ "$err" != *"lychee"* ]]; then
    echo "FAIL [vendored-broken (lychee absent) stderr]: notice missing 'lychee'; got: $err" >&2
    fail=1
  fi
  echo "  vendored-broken (lychee absent): tool-absent branch verified"
fi

if (( fail == 0 )); then
  echo "link-health.test.sh: PASS"
  exit 0
else
  echo "link-health.test.sh: FAIL" >&2
  exit 1
fi
