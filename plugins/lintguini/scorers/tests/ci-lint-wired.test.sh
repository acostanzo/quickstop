#!/usr/bin/env bash
# ci-lint-wired.test.sh — exercise score-ci-lint-wired.sh against
# CI fixtures: github-wired, github-bare, multi-surface, no-ci, empty.
# Triple-runs each for byte-equivalence.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-ci-lint-wired.sh"
FIXTURES="$HERE/fixtures/ci-lint-wired"
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

# github-wired: one workflow, lint invoked → 1/1
out=$(triple_run "$FIXTURES/github-wired")
assert_eq "github-wired id"        "ci-lint-wired-ratio" "$(echo "$out" | jq -r .id)"
assert_eq "github-wired kind"      "ratio"               "$(echo "$out" | jq -r .kind)"
assert_eq "github-wired detected"  "1"                   "$(echo "$out" | jq -r .evidence.ci_surfaces_detected)"
assert_eq "github-wired wired"     "1"                   "$(echo "$out" | jq -r .evidence.ci_surfaces_with_lint)"
assert_eq "github-wired ratio"     "1.0000"              "$(echo "$out" | jq -r .evidence.ratio)"

# github-bare: one workflow, no lint → 0/1
out=$(triple_run "$FIXTURES/github-bare")
assert_eq "github-bare detected"  "1"      "$(echo "$out" | jq -r .evidence.ci_surfaces_detected)"
assert_eq "github-bare wired"     "0"      "$(echo "$out" | jq -r .evidence.ci_surfaces_with_lint)"
assert_eq "github-bare ratio"     "0.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# multi-surface: github workflow + Makefile, both wired → 2/2
out=$(triple_run "$FIXTURES/multi-surface")
assert_eq "multi-surface detected" "2"      "$(echo "$out" | jq -r .evidence.ci_surfaces_detected)"
assert_eq "multi-surface wired"    "2"      "$(echo "$out" | jq -r .evidence.ci_surfaces_with_lint)"
assert_eq "multi-surface ratio"    "1.0000" "$(echo "$out" | jq -r .evidence.ratio)"

# no-ci: only README.md → empty-scope, omit
out=$(triple_run "$FIXTURES/no-ci")
assert_eq "no-ci no output" "" "$out"

# empty: nothing
out=$(triple_run "$FIXTURES/empty")
assert_eq "empty no output" "" "$out"

if (( fail == 0 )); then
  echo "ci-lint-wired.test.sh: PASS"
  exit 0
else
  echo "ci-lint-wired.test.sh: FAIL" >&2
  exit 1
fi
