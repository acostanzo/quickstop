#!/usr/bin/env bash
# compatible-pronto-check.test.sh — exhaustive shell tests for the compatible-pronto helper.
#
# Run: ./compatible-pronto-check.test.sh
# Exits 0 on all-green, non-zero on any failing case.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER="$SCRIPT_DIR/compatible-pronto-check.sh"

PASS=0
FAIL=0
FAILURES=()

# expect_branch <test_name> <pronto_version> <range> <expected_branch>
expect_branch() {
  local name="$1" pv="$2" range="$3" expected="$4"
  local out
  if ! out="$("$HELPER" "$pv" "$range" 2>&1)"; then
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: helper exited non-zero. Output: $out")
    return
  fi
  local got
  got="$(echo "$out" | jq -r '.branch')"
  if [[ "$got" == "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: expected branch=$expected, got $got. Output: $out")
  fi
}

# expect_error <test_name> <pronto_version> <range>
expect_error() {
  local name="$1" pv="$2" range="$3"
  local out rc
  out="$("$HELPER" "$pv" "$range" 2>&1)"
  rc=$?
  if (( rc == 0 )); then
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: expected non-zero exit, got 0. Output: $out")
  else
    PASS=$((PASS + 1))
  fi
}

# --- in_range cases ---

expect_branch "exact match"               "0.1.4" "=0.1.4"        "in_range"
expect_branch "exact match (no op)"       "0.1.4" "0.1.4"         "in_range"
expect_branch "minimum, equal"            "0.1.4" ">=0.1.4"       "in_range"
expect_branch "minimum, above"            "0.2.0" ">=0.1.4"       "in_range"
expect_branch "minimum, major above"      "1.0.0" ">=0.1.4"       "in_range"
expect_branch "maximum, below"            "0.1.4" "<0.2.0"        "in_range"
expect_branch "maximum, far below"        "0.0.1" "<0.2.0"        "in_range"
expect_branch "bounded, lower edge"       "0.1.0" ">=0.1.0 <0.3.0" "in_range"
expect_branch "bounded, middle"           "0.2.0" ">=0.1.0 <0.3.0" "in_range"
expect_branch "bounded, just below upper" "0.2.99" ">=0.1.0 <0.3.0" "in_range"

# --- out_of_range cases ---

expect_branch "exact mismatch"               "0.1.5" "=0.1.4"        "out_of_range"
expect_branch "minimum, below"               "0.0.9" ">=0.1.0"       "out_of_range"
expect_branch "minimum, just below"          "0.0.999" ">=0.1.0"     "out_of_range"
expect_branch "maximum, equal (exclusive)"   "0.2.0" "<0.2.0"        "out_of_range"
expect_branch "maximum, above"               "0.3.0" "<0.2.0"        "out_of_range"
expect_branch "bounded, below lower"         "0.0.5" ">=0.1.0 <0.3.0" "out_of_range"
expect_branch "bounded, equal upper (excl.)" "0.3.0" ">=0.1.0 <0.3.0" "out_of_range"
expect_branch "bounded, above upper"         "0.5.0" ">=0.1.0 <0.3.0" "out_of_range"
expect_branch "future-major against >=99"    "1.0.0" ">=99.0.0"      "out_of_range"

# --- unset cases ---

expect_branch "unset (empty range)"        "0.1.4" ""    "unset"
expect_branch "unset (whitespace only)"    "0.1.4" "   " "unset"

# --- error cases ---

expect_error "missing pronto_version"   ""         ">=0.1.0"
expect_error "non-semver pronto"        "1.0"      ">=0.1.0"
expect_error "non-semver pronto (text)" "abc"      ">=0.1.0"
expect_error "non-semver in clause"     "0.1.4"    ">=0.1"
expect_error "garbage clause"           "0.1.4"    ">>0.1.0"
expect_error "prerelease in pronto"     "1.0.0-rc" ">=0.1.0"
expect_error "prerelease in clause"     "0.1.4"    ">=0.1.0-rc"

# --- output shape ---

shape_check() {
  local pv="$1" range="$2"
  local out
  out="$("$HELPER" "$pv" "$range" 2>&1)"
  # Must be a single-line JSON object with exactly the two expected keys.
  local key_count
  key_count="$(echo "$out" | jq -r 'keys | length')"
  if [[ "$key_count" == "2" ]] \
     && echo "$out" | jq -e 'has("branch") and has("message")' >/dev/null \
     && echo "$out" | jq -r '.message' | grep -qv '^$'; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("output shape: pv=$pv range=$range out=$out")
  fi
}

shape_check "0.1.4" ">=0.1.0"      # in_range branch
shape_check "0.1.4" ">=99.0.0"     # out_of_range branch
shape_check "0.1.4" ""             # unset branch

# --- summary ---

echo
echo "compatible-pronto-check tests: $PASS passed, $FAIL failed"
if (( FAIL > 0 )); then
  echo
  echo "Failures:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
