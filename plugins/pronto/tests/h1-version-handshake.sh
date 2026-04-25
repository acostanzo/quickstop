#!/usr/bin/env bash
# h1-version-handshake.sh — integration smoke for Phase 2 PR H1 (compatible_pronto enforcement).
#
# Exercises the full shell-level pipeline that SKILL.md drives at runtime:
#   1. Read sibling plugin.json
#   2. Extract pronto.compatible_pronto via jq
#   3. Invoke compatible-pronto-check.sh with pronto's running version
#   4. Assert the helper's branch matches expectation
#
# Three fake-sibling fixtures (in_range, out_of_range, unset) cover the three
# ADR-004 §2 outcomes. Run: ./h1-version-handshake.sh
# Exits 0 on all-green, non-zero on any failing case.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PRONTO_PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
HELPER="$PRONTO_PLUGIN_ROOT/skills/audit/compatible-pronto-check.sh"

if [[ ! -x "$HELPER" ]]; then
  echo "FAIL: helper not found or not executable: $HELPER" >&2
  exit 1
fi

# Use pronto's actual running version — the test exercises the same value SKILL.md uses.
PRONTO_VERSION="$(jq -r '.version' "$PRONTO_PLUGIN_ROOT/.claude-plugin/plugin.json")"
if [[ -z "$PRONTO_VERSION" || "$PRONTO_VERSION" == "null" ]]; then
  echo "FAIL: could not read pronto's version from plugin.json" >&2
  exit 1
fi

# Build a tmpdir of fake siblings — three plugin.json files with distinct
# compatible_pronto declarations.
FIXTURE_DIR="$(mktemp -d -t pronto-h1-handshake.XXXXXX)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

mkdir -p "$FIXTURE_DIR/in_range" "$FIXTURE_DIR/out_of_range" "$FIXTURE_DIR/unset"

# Fixture A: in_range — declares a range that includes pronto's version.
#   ">=0.1.0 <99.0.0" comfortably covers any plausible pronto version.
cat > "$FIXTURE_DIR/in_range/plugin.json" <<EOF
{
  "name": "fake-in-range-sibling",
  "version": "1.0.0",
  "pronto": {
    "compatible_pronto": ">=0.1.0 <99.0.0",
    "audits": [{"dimension": "lint-posture", "command": "/fake:audit --json"}]
  }
}
EOF

# Fixture B: out_of_range — declares a range that excludes any pronto version below 99.0.0.
cat > "$FIXTURE_DIR/out_of_range/plugin.json" <<EOF
{
  "name": "fake-out-of-range-sibling",
  "version": "2.5.1",
  "pronto": {
    "compatible_pronto": ">=99.0.0",
    "audits": [{"dimension": "lint-posture", "command": "/fake:audit --json"}]
  }
}
EOF

# Fixture C: unset — pronto block exists but no compatible_pronto field.
cat > "$FIXTURE_DIR/unset/plugin.json" <<EOF
{
  "name": "fake-unset-sibling",
  "version": "0.9.0",
  "pronto": {
    "audits": [{"dimension": "lint-posture", "command": "/fake:audit --json"}]
  }
}
EOF

PASS=0
FAIL=0
FAILURES=()

# check_fixture <fixture_name> <expected_branch>
check_fixture() {
  local name="$1" expected="$2"
  local manifest="$FIXTURE_DIR/$name/plugin.json"

  # Mirror SKILL.md Phase 2's extraction: `pronto.compatible_pronto // ""`.
  local range
  range="$(jq -r '.pronto.compatible_pronto // ""' "$manifest")"

  local helper_out
  if ! helper_out="$("$HELPER" "$PRONTO_VERSION" "$range" 2>&1)"; then
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: helper exited non-zero. Output: $helper_out")
    return
  fi

  local got_branch
  got_branch="$(echo "$helper_out" | jq -r '.branch')"
  if [[ "$got_branch" == "$expected" ]]; then
    PASS=$((PASS + 1))
    echo "PASS $name → $got_branch"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: expected branch=$expected, got $got_branch. Output: $helper_out")
  fi

  # Sanity: message is non-empty and mentions the relevant context.
  local message
  message="$(echo "$helper_out" | jq -r '.message')"
  if [[ -z "$message" ]]; then
    FAIL=$((FAIL + 1))
    FAILURES+=("$name: helper message is empty")
  fi
}

echo "Pronto running version: $PRONTO_VERSION"
echo "Fixture dir: $FIXTURE_DIR"
echo

check_fixture "in_range"     "in_range"
check_fixture "out_of_range" "out_of_range"
check_fixture "unset"        "unset"

echo
echo "h1-version-handshake: $PASS passed, $FAIL failed"
if (( FAIL > 0 )); then
  echo
  echo "Failures:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
