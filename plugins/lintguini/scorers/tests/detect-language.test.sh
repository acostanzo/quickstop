#!/usr/bin/env bash
# detect-language.test.sh — exercise bin/lintguini-detect-language.sh
# and the underlying scorers/_common.sh::detect_languages helper.
#
# Coverage:
#   1. Every existing fixture under fixtures/formatter-presence/
#      maps to its expected primary language. The fixtures are
#      hand-curated to cover the rubric's six languages plus the
#      empty-repo case; if the helper drifts, every audit drifts
#      with it, so this is the load-bearing regression.
#   2. The plural detect_languages helper picks up a polyglot fixture
#      built ad-hoc under TMPDIR.
#   3. Triple-run determinism on both invocation modes.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPT="$PLUGIN_ROOT/bin/lintguini-detect-language.sh"
FIXTURES="$HERE/fixtures/formatter-presence"

PASS=0
FAIL=0
FAILURES=()

note_pass() { PASS=$((PASS + 1)); }
note_fail() {
  FAIL=$((FAIL + 1))
  FAILURES+=("$1")
}

if [[ ! -x "$SCRIPT" ]]; then
  echo "FATAL: $SCRIPT not executable" >&2
  exit 2
fi

triple_run_primary() {
  local fixture="$1"
  local r1 r2 r3
  r1=$("$SCRIPT" --primary "$fixture" 2>/dev/null)
  r2=$("$SCRIPT" --primary "$fixture" 2>/dev/null)
  r3=$("$SCRIPT" --primary "$fixture" 2>/dev/null)
  if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
    note_fail "$(basename "$fixture"): triple-run --primary diverged"
    return 1
  fi
  printf '%s' "$r1"
}

triple_run_all() {
  local fixture="$1"
  local r1 r2 r3
  r1=$("$SCRIPT" "$fixture" 2>/dev/null)
  r2=$("$SCRIPT" "$fixture" 2>/dev/null)
  r3=$("$SCRIPT" "$fixture" 2>/dev/null)
  if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
    note_fail "$(basename "$fixture"): triple-run all-mode diverged"
    return 1
  fi
  printf '%s' "$r1"
}

assert_primary() {
  local fixture="$1" expected="$2"
  local actual
  actual=$(triple_run_primary "$fixture") || return
  note_pass
  if [[ "$actual" == "$expected" ]]; then
    note_pass
  else
    note_fail "$(basename "$fixture"): expected primary='$expected' got '$actual'"
  fi
}

# Fixture → expected primary language. Mirrors the fixtures hand-built
# for the formatter-presence scorer; the same shape underlies every
# scorer's detection branch.
assert_primary "$FIXTURES/python-formatted"     "python"
assert_primary "$FIXTURES/python-unformatted"   "python"
assert_primary "$FIXTURES/js-biome-formatted"   "javascript"
assert_primary "$FIXTURES/js-prettier"          "javascript"
assert_primary "$FIXTURES/js-unformatted"       "javascript"
assert_primary "$FIXTURES/ts-formatted"         "typescript"
assert_primary "$FIXTURES/ts-unformatted"       "typescript"
assert_primary "$FIXTURES/rust-formatted"       "rust"
assert_primary "$FIXTURES/rust-unformatted"     "rust"
assert_primary "$FIXTURES/go"                   "go"
assert_primary "$FIXTURES/ruby-formatted"       "ruby"
assert_primary "$FIXTURES/ruby-unformatted"     "ruby"
assert_primary "$FIXTURES/empty"                ""

# Polyglot exercise. Build a fixture with python + rust + go markers
# under TMPDIR; assert detect_languages emits all three in stable
# rubric order (python > rust > go).
TMPROOT="$(mktemp -d -t lintguini-detect.XXXXXX)"
trap 'rm -rf "$TMPROOT"' EXIT

POLYGLOT="$TMPROOT/polyglot"
mkdir -p "$POLYGLOT"
touch "$POLYGLOT/pyproject.toml" "$POLYGLOT/Cargo.toml" "$POLYGLOT/go.mod"

actual=$(triple_run_all "$POLYGLOT")
expected=$'python\nrust\ngo'
if [[ "$actual" == "$expected" ]]; then
  note_pass
else
  note_fail "polyglot: expected python/rust/go in rubric order, got: $(echo "$actual" | tr '\n' ' ')"
fi

# Empty fixture in default mode: empty stdout, exit 0.
EMPTY_OUT=$("$SCRIPT" "$FIXTURES/empty" 2>/dev/null)
EMPTY_RC=$?
if [[ "$EMPTY_OUT" == "" && "$EMPTY_RC" == "0" ]]; then
  note_pass
else
  note_fail "empty fixture all-mode: expected empty stdout + exit 0, got '$EMPTY_OUT' rc=$EMPTY_RC"
fi

if (( FAIL == 0 )); then
  echo "detect-language.test.sh: PASS — $PASS checks"
  exit 0
else
  echo "detect-language.test.sh: FAIL — $PASS passed, $FAIL failed" >&2
  for msg in "${FAILURES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi
