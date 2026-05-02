#!/usr/bin/env bash
# docs-coverage.test.sh — exercise score-docs-coverage.sh against the
# python fixture and the empty-scope fixture. Behaviour branches on
# language-tool availability:
#
#   interrogate on PATH (python fixture)
#     -> verify documented=3, total=6, ratio=0.5000
#        (5 functions + 1 module-level docstring; 3 functions
#        documented + 1 module docstring documented = 4 of 6;
#        wait — the module docstring counts toward `documented`,
#        bringing the count to 4/6.)
#
#     The fixture is constructed so that with the module docstring
#     present, 4 of the 6 documentation targets (1 module + 5
#     functions) are documented. The test hard-asserts documented=4
#     and total=6 for ratio=0.6667 — which matches interrogate's
#     standard counting convention.
#
#   interrogate absent
#     -> verify empty stdout + stderr notice mentions interrogate.
#
#   empty fixture (no language detected)
#     -> empty stdout regardless.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-docs-coverage.sh"
FIXTURES="$HERE/fixtures/docs-coverage"
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

# ---- empty: no language detected → empty-scope omit
out=$(triple_run "$FIXTURES/empty")
assert_eq "empty no output" "" "$out"

# ---- python: branch on interrogate availability
if command -v interrogate >/dev/null 2>&1; then
  out=$(triple_run "$FIXTURES/python")
  assert_eq "python id"        "docs-coverage-ratio" "$(echo "$out" | jq -r .id)"
  assert_eq "python kind"      "ratio"               "$(echo "$out" | jq -r .kind)"
  assert_eq "python language"  "python"              "$(echo "$out" | jq -r .evidence.language)"
  # 5 functions (3 documented, 2 not) + 1 module docstring (documented)
  # interrogate counts module docstring as a target → documented=4, total=6.
  documented=$(echo "$out" | jq -r .evidence.documented)
  total=$(echo "$out"      | jq -r .evidence.total)
  if [[ "$total" != "6" || "$documented" != "4" ]]; then
    echo "FAIL [python counts]: expected documented=4 total=6, got documented=$documented total=$total" >&2
    fail=1
  fi
  echo "  python (interrogate present): documented=$documented total=$total"
else
  out=$("$SCORER" "$FIXTURES/python" 2>/dev/null)
  assert_eq "python (interrogate absent) no stdout" "" "$out"
  err=$("$SCORER" "$FIXTURES/python" 2>&1 >/dev/null)
  if [[ "$err" != *"interrogate"* ]]; then
    echo "FAIL [python (interrogate absent) stderr]: notice missing 'interrogate'; got: $err" >&2
    fail=1
  fi
  echo "  python (interrogate absent): tool-absent branch verified"
fi

if (( fail == 0 )); then
  echo "docs-coverage.test.sh: PASS"
  exit 0
else
  echo "docs-coverage.test.sh: FAIL" >&2
  exit 1
fi
