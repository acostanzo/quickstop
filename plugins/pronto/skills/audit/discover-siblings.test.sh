#!/usr/bin/env bash
# discover-siblings.test.sh — shell tests for the discover-siblings helper.
#
# Run: ./discover-siblings.test.sh
# Exits 0 on all-green, non-zero on any failing case.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER="$SCRIPT_DIR/discover-siblings.sh"

PASS=0
FAIL=0
FAILURES=()

ok() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); FAILURES+=("$1"); }

# ---- helpers ----

# Build a fixture parent dir with a bunch of sibling plugins. Args:
#   $1 = parent dir to populate
# Layout:
#   <parent>/pronto/.claude-plugin/plugin.json     — the "running" plugin
#   <parent>/inkwell/.claude-plugin/plugin.json    — sibling with pronto.audits
#   <parent>/skillet/.claude-plugin/plugin.json    — sibling without pronto.audits
#   <parent>/oddball/                              — directory with no plugin.json
#   <parent>/notaplugin/.claude-plugin/plugin.json — plugin.json missing .name
build_fixture() {
  local parent="$1"
  mkdir -p "$parent/pronto/.claude-plugin"
  cat >"$parent/pronto/.claude-plugin/plugin.json" <<'EOF'
{ "name": "pronto", "version": "9.9.9" }
EOF

  mkdir -p "$parent/inkwell/.claude-plugin"
  cat >"$parent/inkwell/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "inkwell",
  "version": "1.2.3",
  "pronto": {
    "compatible_pronto": ">=0.3.0",
    "audits": [{ "dimension": "code-documentation", "command": "/inkwell:audit --json" }]
  }
}
EOF

  mkdir -p "$parent/skillet/.claude-plugin"
  cat >"$parent/skillet/.claude-plugin/plugin.json" <<'EOF'
{ "name": "skillet", "version": "0.2.1" }
EOF

  mkdir -p "$parent/oddball"
  : >"$parent/oddball/marker"

  mkdir -p "$parent/notaplugin/.claude-plugin"
  cat >"$parent/notaplugin/.claude-plugin/plugin.json" <<'EOF'
{ "version": "0.0.1" }
EOF
}

# ---- test 1: happy path ----

TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT

build_fixture "$TMPROOT"

if ! out=$("$HELPER" "$TMPROOT/pronto" 2>&1); then
  fail "happy-path: helper exited non-zero. Output: $out"
else
  names=$(echo "$out" | jq -r 'map(.name) | join(",")')
  if [[ "$names" == "inkwell,skillet" ]]; then ok; else
    fail "happy-path: expected names='inkwell,skillet' (sorted, pronto excluded, oddball/notaplugin skipped), got '$names'"
  fi

  inkwell=$(echo "$out" | jq -c '.[] | select(.name == "inkwell")')
  inkwell_audits=$(echo "$inkwell" | jq -r '.native_declarations | length')
  if [[ "$inkwell_audits" == "1" ]]; then ok; else
    fail "happy-path: inkwell native_declarations length=$inkwell_audits (expected 1)"
  fi

  inkwell_compat=$(echo "$inkwell" | jq -r '.compatible_pronto')
  if [[ "$inkwell_compat" == ">=0.3.0" ]]; then ok; else
    fail "happy-path: inkwell compatible_pronto='$inkwell_compat' (expected '>=0.3.0')"
  fi

  inkwell_root=$(echo "$inkwell" | jq -r '.plugin_root')
  if [[ "$inkwell_root" == "$TMPROOT/inkwell" ]]; then ok; else
    fail "happy-path: inkwell plugin_root='$inkwell_root' (expected '$TMPROOT/inkwell')"
  fi

  skillet=$(echo "$out" | jq -c '.[] | select(.name == "skillet")')
  skillet_audits=$(echo "$skillet" | jq -r '.native_declarations')
  if [[ "$skillet_audits" == "[]" ]]; then ok; else
    fail "happy-path: skillet native_declarations='$skillet_audits' (expected '[]')"
  fi

  skillet_compat=$(echo "$skillet" | jq -r '.compatible_pronto')
  if [[ "$skillet_compat" == "" ]]; then ok; else
    fail "happy-path: skillet compatible_pronto='$skillet_compat' (expected empty string)"
  fi
fi

# ---- test 2: empty parent (only pronto) ----

EMPTY_ROOT="$(mktemp -d)"
mkdir -p "$EMPTY_ROOT/pronto/.claude-plugin"
cat >"$EMPTY_ROOT/pronto/.claude-plugin/plugin.json" <<'EOF'
{ "name": "pronto", "version": "9.9.9" }
EOF
if ! out=$("$HELPER" "$EMPTY_ROOT/pronto" 2>&1); then
  fail "empty-parent: helper exited non-zero. Output: $out"
elif [[ "$out" == "[]" ]]; then ok; else
  fail "empty-parent: expected '[]', got '$out'"
fi
rm -rf "$EMPTY_ROOT"

# ---- test 3: missing arg ----

if "$HELPER" >/dev/null 2>&1; then
  fail "missing-arg: expected non-zero exit, got 0"
else ok; fi

# ---- test 4: nonexistent CLAUDE_PLUGIN_ROOT ----

if "$HELPER" "/nonexistent/path/$$" >/dev/null 2>&1; then
  fail "nonexistent-root: expected non-zero exit, got 0"
else ok; fi

# ---- summary ----

echo
echo "Pass: $PASS"
echo "Fail: $FAIL"
if (( FAIL > 0 )); then
  printf '  - %s\n' "${FAILURES[@]}"
  exit 1
fi
exit 0
