#!/usr/bin/env bash
# eval-categorize.test.sh — exhaustive tests for the eval-categorize helper.
#
# Run: ./eval-categorize.test.sh
# Exits 0 on all-green, non-zero on any failing case.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER="$SCRIPT_DIR/eval-categorize.sh"

if [[ ! -x "$HELPER" ]]; then
  echo "FAIL: helper not found or not executable: $HELPER" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d -t eval-categorize-test.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

PASS=0
FAIL=0
FAILURES=()

# write_fixture <name> <stdout_content>  [<stderr_content>]
# Returns paths via globals STDOUT_PATH, STDERR_PATH.
write_fixture() {
  local name="$1" stdout_content="$2" stderr_content="${3:-}"
  STDOUT_PATH="$WORK_DIR/$name.stdout"
  STDERR_PATH="$WORK_DIR/$name.stderr"
  printf '%s' "$stdout_content" > "$STDOUT_PATH"
  printf '%s' "$stderr_content" > "$STDERR_PATH"
}

# expect <name> <expected_category> <args...>
# args... is the full argv after --stdout (which is set automatically).
expect() {
  local name="$1" expected_cat="$2"; shift 2
  local out
  if ! out="$("$HELPER" --stdout "$STDOUT_PATH" "$@" 2>&1)"; then
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: helper exited non-zero. Output: $out")
    return
  fi
  local got
  got="$(echo "$out" | jq -r '.category')"
  if [[ "$got" == "$expected_cat" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: expected category=$expected_cat, got $got. Output: $out")
  fi
}

expect_sub() {
  local name="$1" expected_cat="$2" expected_sub="$3"; shift 3
  local out
  if ! out="$("$HELPER" --stdout "$STDOUT_PATH" "$@" 2>&1)"; then
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: helper exited non-zero. Output: $out")
    return
  fi
  local got_cat got_sub
  got_cat="$(echo "$out" | jq -r '.category')"
  got_sub="$(echo "$out" | jq -r '.sub_reason')"
  if [[ "$got_cat" == "$expected_cat" && "$got_sub" == "$expected_sub" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: expected ($expected_cat / $expected_sub), got ($got_cat / $got_sub). Output: $out")
  fi
}

# --- contract-violation (highest priority — passed-in flag) ---

write_fixture "contract_passthrough" '{"composite_score":100}' ''
expect_sub "contract violation passed in" "contract-violation" "dimensions-empty" \
  --exit-code 0 --stderr "$STDERR_PATH" --contract "dimensions-empty"

write_fixture "contract_partial" '{"composite_score":50,"dimensions":[{"dimension":"agents-md","score":0}]}' ''
expect_sub "contract violation, partial dims" "contract-violation" "dimensions-partial:claude-code-config|code-documentation" \
  --exit-code 0 --stderr "$STDERR_PATH" --contract "dimensions-partial:claude-code-config|code-documentation"

# --- exit-nonzero (next priority — CLI failure) ---

write_fixture "exit_nonzero" "" "claude: command timed out"
expect_sub "exit nonzero" "exit-nonzero" "exit_code=1" \
  --exit-code 1 --stderr "$STDERR_PATH"

write_fixture "exit_137" "{partial output}" "killed by SIGKILL"
expect_sub "exit 137 (killed)" "exit-nonzero" "exit_code=137" \
  --exit-code 137 --stderr "$STDERR_PATH"

# --- refusal-or-empty ---

write_fixture "empty_stdout" "" ""
expect_sub "empty stdout" "refusal-or-empty" "empty" \
  --exit-code 0 --stderr "$STDERR_PATH"

write_fixture "whitespace_only" $'   \n\n   \t  ' ""
expect_sub "whitespace-only stdout" "refusal-or-empty" "empty" \
  --exit-code 0 --stderr "$STDERR_PATH"

write_fixture "refusal_apology" "I'm sorry, I cannot perform this audit without access to the repository." ""
expect_sub "refusal — apology" "refusal-or-empty" "refusal" \
  --exit-code 0 --stderr "$STDERR_PATH"

write_fixture "refusal_cant" "I can't help with that request." ""
expect_sub "refusal — can't" "refusal-or-empty" "refusal" \
  --exit-code 0 --stderr "$STDERR_PATH"

write_fixture "refusal_unable" "I am unable to access the file system from this context." ""
expect_sub "refusal — unable" "refusal-or-empty" "refusal" \
  --exit-code 0 --stderr "$STDERR_PATH"

write_fixture "no_json_freeform" "Looks like nothing notable to report on this codebase." ""
expect_sub "no json, no refusal phrase" "refusal-or-empty" "no-json" \
  --exit-code 0 --stderr "$STDERR_PATH"

# --- partial-emission (truncated mid-stream) ---

write_fixture "truncated_mid_object" '{"composite_score":75,"dimensions":[{"dimension":"agents-md"' ""
expect "truncated open JSON" "partial-emission" \
  --exit-code 0 --stderr "$STDERR_PATH"

write_fixture "truncated_one_brace_short" '{"a":{"b":1}' ""
expect "truncated, one closing brace short" "partial-emission" \
  --exit-code 0 --stderr "$STDERR_PATH"

# --- prose-contamination ---

write_fixture "prose_preamble" 'Here is the audit result:
{"composite_score":75,"composite_grade":"C","dimensions":[]}' ""
expect "prose preamble around valid JSON" "prose-contamination" \
  --exit-code 0 --stderr "$STDERR_PATH"

write_fixture "prose_postamble" '{"composite_score":75,"composite_grade":"C","dimensions":[]}

Let me know if you need anything else!' ""
expect "prose postamble around valid JSON" "prose-contamination" \
  --exit-code 0 --stderr "$STDERR_PATH"

write_fixture "prose_both_sides" 'Sure, here you go:
{"a":1,"b":[2,3]}
Hope that helps.' ""
expect "prose on both sides of valid JSON" "prose-contamination" \
  --exit-code 0 --stderr "$STDERR_PATH"

# --- other (unrecognized) ---

write_fixture "two_json_objects" '{"a":1}{"b":2}' ""
expect "two concatenated JSON objects" "other" \
  --exit-code 0 --stderr "$STDERR_PATH"

write_fixture "balanced_but_garbage" '{ this is not valid json at all }' ""
expect "balanced braces, not parseable, not prose-wrapped" "other" \
  --exit-code 0 --stderr "$STDERR_PATH"

# --- output shape ---

shape_check() {
  local name="$1"; shift
  local out
  out="$("$HELPER" --stdout "$STDOUT_PATH" "$@" 2>&1)"
  local key_count
  key_count="$(echo "$out" | jq -r 'keys | length')"
  if [[ "$key_count" == "3" ]] \
     && echo "$out" | jq -e 'has("category") and has("sub_reason") and has("evidence")' >/dev/null \
     && echo "$out" | jq -e '.evidence | has("stdout_head") and has("stdout_tail") and has("stderr_tail")' >/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("output shape ($name): out=$out")
  fi
}

write_fixture "shape_prose" 'Here is the result:
{"a":1}' ""
shape_check "prose contamination" --exit-code 0 --stderr "$STDERR_PATH"

write_fixture "shape_empty" "" ""
shape_check "empty stdout" --exit-code 0 --stderr "$STDERR_PATH"

write_fixture "shape_exit_nonzero" "" "boom"
shape_check "exit nonzero" --exit-code 2 --stderr "$STDERR_PATH"

# --- caller-side errors (rc=2) ---

expect_caller_error() {
  local name="$1"; shift
  local out rc
  out="$("$HELPER" "$@" 2>&1)"
  rc=$?
  if (( rc == 2 )); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: expected rc=2, got rc=$rc. Output: $out")
  fi
}

expect_caller_error "missing --stdout" --exit-code 0
expect_caller_error "missing --exit-code" --stdout "$WORK_DIR/empty_stdout.stdout"
expect_caller_error "stdout file missing" --stdout "/tmp/this-file-should-not-exist-$$" --exit-code 0
expect_caller_error "non-integer exit code" --stdout "$WORK_DIR/empty_stdout.stdout" --exit-code "abc"

# --- summary ---

echo
echo "eval-categorize tests: $PASS passed, $FAIL failed"
if (( FAIL > 0 )); then
  echo
  echo "Failures:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
