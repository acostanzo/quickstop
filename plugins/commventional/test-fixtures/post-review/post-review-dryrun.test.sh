#!/usr/bin/env bash
# post-review-dryrun.test.sh — exercise bin/commventional-post-review.sh
# against the locked JSON contract emitted by review-formatter.
#
# The deterministic translation half (JSON-in → gh-api-call-out) is what
# this test pins. The agent's synthesis (raw review feedback → JSON) is
# the LLM half and is intentionally untested here.
#
# Cases:
#   1. Dry-run rendering — sample-review.json (verdict + 3 comments)
#      produces a gh api invocation referencing the right API path,
#      with verdict body, event, and a 3-element comments array whose
#      bodies preserve the conventional-comments shape.
#   2. Validation rejection — a comment missing `path` exits 2 with a
#      clear stderr message naming the offending field.
#   3. Empty-comments edge case — verdict-only review still produces a
#      valid gh api invocation with comments: [] and the correct
#      verdict event (APPROVE in this fixture).
#   4. Triple-run determinism — same JSON in → byte-equivalent gh api
#      invocation out across three back-to-back invocations.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
POSTER="$PLUGIN_ROOT/bin/commventional-post-review.sh"

FIX_FULL="$SCRIPT_DIR/sample-review.json"
FIX_BAD="$SCRIPT_DIR/sample-review-missing-path.json"
FIX_EMPTY="$SCRIPT_DIR/sample-review-empty.json"

# Fully-qualified PR identifier so the dry-run path can resolve owner/
# repo/number without calling out to gh. Combined with --head-sha the
# poster never touches the network or gh auth in this test.
FAKE_PR="fake-owner/fake-repo#9999"
FAKE_SHA="testshafake000000000000000000000000000000"

fail=0

if [[ ! -x "$POSTER" ]]; then
  echo "FATAL: poster not executable: $POSTER" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FATAL: jq required" >&2
  exit 2
fi

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL [$label]: expected '$expected', got '$actual'" >&2
    fail=1
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "FAIL [$label]: expected to contain '$needle'" >&2
    echo "  actual: $haystack" >&2
    fail=1
  fi
}

assert_match() {
  local label="$1" pattern="$2" haystack="$3"
  if ! printf '%s\n' "$haystack" | grep -Eq "$pattern"; then
    echo "FAIL [$label]: expected pattern '$pattern' to match" >&2
    echo "  actual: $haystack" >&2
    fail=1
  fi
}

# Run the poster in dry-run mode. The first line of stdout is the gh
# api command line; lines 2+ are the JSON body. Returns full stdout.
run_dryrun() {
  local fixture="$1"
  cat "$fixture" | "$POSTER" "$FAKE_PR" --dry-run --head-sha "$FAKE_SHA"
}

# extract_body — return the JSON body portion of a dry-run output
# (everything after the first line).
extract_body() {
  printf '%s\n' "$1" | tail -n +2
}

# -------------------------------------------------------------------
# Case 1 — full review: 3 comments render correctly.
# -------------------------------------------------------------------
out_full=$(run_dryrun "$FIX_FULL")

# First line is the gh api command.
first_line=$(printf '%s\n' "$out_full" | head -n 1)
assert_eq "case1: gh api command line" \
  "gh api -X POST repos/fake-owner/fake-repo/pulls/9999/reviews --input -" \
  "$first_line"

body_full=$(extract_body "$out_full")

# Body parses as JSON.
if ! printf '%s' "$body_full" | jq -e '.' >/dev/null 2>&1; then
  echo "FAIL [case1: body not valid JSON]" >&2
  echo "  body: $body_full" >&2
  fail=1
fi

# commit_id, event, body fields surfaced from the fixture.
got_sha=$(printf '%s' "$body_full" | jq -r '.commit_id')
assert_eq "case1: commit_id" "$FAKE_SHA" "$got_sha"

got_event=$(printf '%s' "$body_full" | jq -r '.event')
assert_eq "case1: event" "COMMENT" "$got_event"

got_body=$(printf '%s' "$body_full" | jq -r '.body')
assert_contains "case1: verdict body" "Nice work overall." "$got_body"

# 3 comments in the array.
nc=$(printf '%s' "$body_full" | jq -r '.comments | length')
assert_eq "case1: 3 comments" "3" "$nc"

# First comment renders as `label: subject\n\ndiscussion`.
c0_body=$(printf '%s' "$body_full" | jq -r '.comments[0].body')
assert_contains "case1: c0 label+subject" \
  "suggestion: Extract this repeated pattern into a helper" "$c0_body"
assert_contains "case1: c0 discussion" \
  "null-check-then-transform appears on lines 42, 67, and 91" "$c0_body"

# Praise comment (third) has no discussion — body is just `label: subject`.
c2_body=$(printf '%s' "$body_full" | jq -r '.comments[2].body')
assert_eq "case1: c2 (praise, no discussion)" \
  "praise: Clean separation of concerns in this module" "$c2_body"

# side defaults preserved.
c0_side=$(printf '%s' "$body_full" | jq -r '.comments[0].side')
assert_eq "case1: c0 side" "RIGHT" "$c0_side"

# path/line surfaced.
c1_path=$(printf '%s' "$body_full" | jq -r '.comments[1].path')
assert_eq "case1: c1 path" "src/api.ts" "$c1_path"
c1_line=$(printf '%s' "$body_full" | jq -r '.comments[1].line')
assert_eq "case1: c1 line" "15" "$c1_line"

# -------------------------------------------------------------------
# Case 2 — validation rejection: missing `path` exits 2 with the
# offending field named in stderr.
# -------------------------------------------------------------------
err_bad=$(cat "$FIX_BAD" | "$POSTER" "$FAKE_PR" --dry-run --head-sha "$FAKE_SHA" 2>&1 >/dev/null)
rc_bad=$?
assert_eq "case2: exit code 2 for missing path" "2" "$rc_bad"
assert_contains "case2: stderr names missing field" \
  "comments[1].path is required" "$err_bad"

# -------------------------------------------------------------------
# Case 3 — empty comments[] is a valid review (verdict-only). Dry-run
# produces a gh api call with comments: [].
# -------------------------------------------------------------------
out_empty=$(run_dryrun "$FIX_EMPTY")
body_empty=$(extract_body "$out_empty")

if ! printf '%s' "$body_empty" | jq -e '.' >/dev/null 2>&1; then
  echo "FAIL [case3: body not valid JSON]" >&2
  echo "  body: $body_empty" >&2
  fail=1
fi

empty_event=$(printf '%s' "$body_empty" | jq -r '.event')
assert_eq "case3: APPROVE event passed through" "APPROVE" "$empty_event"

empty_nc=$(printf '%s' "$body_empty" | jq -r '.comments | length')
assert_eq "case3: empty comments[] length 0" "0" "$empty_nc"

empty_body=$(printf '%s' "$body_empty" | jq -r '.body')
assert_contains "case3: verdict body" "LGTM." "$empty_body"

# -------------------------------------------------------------------
# Case 4 — triple-run determinism on the dry-run output.
# -------------------------------------------------------------------
r1=$(run_dryrun "$FIX_FULL")
r2=$(run_dryrun "$FIX_FULL")
r3=$(run_dryrun "$FIX_FULL")
if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
  echo "FAIL [case4: triple-run dry-run diverged]" >&2
  diff <(printf '%s' "$r1") <(printf '%s' "$r2") | head -20 >&2
  fail=1
fi

if (( fail == 0 )); then
  echo "post-review-dryrun.test.sh: PASS"
  exit 0
else
  echo "post-review-dryrun.test.sh: FAIL" >&2
  exit 1
fi
