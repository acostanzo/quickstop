#!/usr/bin/env bash
# inkwell-corroborate.test.sh — exercise bin/inkwell-corroborate.sh
# against synthetic fixtures covering all three corroboration tiers
# and the graceful-degradation invariant from ADR-007.
#
# Cases:
#   1. Tier 1, file:symbol exists      — `src/auth/login.ts:validateSession`
#                                        on a fixture where both file
#                                        and symbol are real → verified.
#   2. Tier 1, file missing            — `path/to/missing.ts:foo` →
#                                        drift detected (file absent).
#   3. Tier 1, symbol missing          — file exists but symbol grep
#                                        fails → drift detected.
#   4. Tier 2, subagent unreachable    — INKWELL_CORROBORATE_SUBAGENT
#                                        set to a known-bad command;
#                                        bounded timeout exercised via
#                                        a low INKWELL_CORROBORATE_TIMEOUT;
#                                        result is `could not corroborate`,
#                                        exit 0, no crash.
#   5. Tier 3, conceptual statement    — input with no code-shape
#                                        signal and no behavioural
#                                        verbs → could not corroborate.
#   6. Triple-run determinism on Tier 1 + Tier 3 paths. Tier 2 is
#      non-deterministic by design and is not pinned beyond the
#      structural-shape check in case 4.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
CORROBORATE="$PLUGIN_ROOT/bin/inkwell-corroborate.sh"
fail=0

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

# Build a small repo that has src/auth/login.ts containing
# validateSession, plus an unrelated source file.
build_repo() {
  local repo="$1"
  rm -rf "$repo"
  mkdir -p "$repo/src/auth" "$repo/src/util"
  cat > "$repo/src/auth/login.ts" <<'EOF'
export function validateSession() {
  return true;
}

export function rotateRefresh(token: string) {
  return token + ":rotated";
}
EOF
  cat > "$repo/src/util/format.ts" <<'EOF'
export function formatDate(d: Date): string { return d.toISOString(); }
EOF
}

# ---------------------------------------------------------------------
# Case 1 — Tier 1, file:symbol exists.
# Both file and symbol are real. The dispatcher's emitted line should
# be `<citation>\tverified`.
# ---------------------------------------------------------------------

REPO="$(mktemp -d -t inkwell-corro-1.XXXXXX)"
build_repo "$REPO"

case1_chunks="### docs/auth/sessions.md#sessions

# Sessions

The function \`src/auth/login.ts:validateSession\` is the JWT verifier.
"

case1_out="$(printf '%s' "$case1_chunks" \
  | INKWELL_CORROBORATE_SUBAGENT=/bin/false bash "$CORROBORATE" "$REPO" 2>/dev/null)"
assert_contains "tier1 file:symbol exists — verified line emitted" \
  "docs/auth/sessions.md#sessions"$'\t'"verified" "$case1_out"
rm -rf "$REPO"

# ---------------------------------------------------------------------
# Case 2 — Tier 1, file missing.
# `path/to/missing.ts:foo` — file does not exist anywhere under the
# repo. Result: drift detected.
# ---------------------------------------------------------------------

REPO="$(mktemp -d -t inkwell-corro-2.XXXXXX)"
build_repo "$REPO"

case2_chunks="### docs/missing.md#missing

# Missing

References \`path/to/missing.ts:foo\` which doesn't exist.
"

case2_out="$(printf '%s' "$case2_chunks" \
  | INKWELL_CORROBORATE_SUBAGENT=/bin/false bash "$CORROBORATE" "$REPO" 2>/dev/null)"
assert_contains "tier1 file missing — drift detected emitted" \
  "drift detected" "$case2_out"
assert_contains "tier1 file missing — names the missing path" \
  "path/to/missing.ts" "$case2_out"
rm -rf "$REPO"

# ---------------------------------------------------------------------
# Case 3 — Tier 1, symbol missing.
# File exists, but the grep for the symbol fails.
# ---------------------------------------------------------------------

REPO="$(mktemp -d -t inkwell-corro-3.XXXXXX)"
build_repo "$REPO"

case3_chunks="### docs/auth/sessions.md#sessions

# Sessions

The function \`src/auth/login.ts:nonExistentSymbol\` is referenced.
"

case3_out="$(printf '%s' "$case3_chunks" \
  | INKWELL_CORROBORATE_SUBAGENT=/bin/false bash "$CORROBORATE" "$REPO" 2>/dev/null)"
assert_contains "tier1 symbol missing — drift detected emitted" \
  "drift detected" "$case3_out"
assert_contains "tier1 symbol missing — names the missing symbol" \
  "nonExistentSymbol" "$case3_out"
rm -rf "$REPO"

# ---------------------------------------------------------------------
# Case 4 — Tier 2, subagent unreachable.
# Sentence with behavioural shape ("verifies", "rotates", "the default
# is") triggers Tier 2 dispatch. Subagent path is set to a definitely-
# bad command (`/nonexistent/agent`); the dispatcher must catch this
# and return `could not corroborate` for the affected claim, exit 0,
# no crash. Bounded timeout is also exercised via a 1s cap so a hung
# subagent path can't wedge the test suite.
# ---------------------------------------------------------------------

REPO="$(mktemp -d -t inkwell-corro-4.XXXXXX)"
build_repo "$REPO"

case4_chunks="### docs/concepts/auth.md#authentication

# Authentication

The middleware verifies the session and rotates the refresh token
when the access token is within five minutes of expiry. The default
is to renew silently.
"

case4_exit=0
case4_out="$(printf '%s' "$case4_chunks" \
  | INKWELL_CORROBORATE_SUBAGENT=/nonexistent/agent \
    INKWELL_CORROBORATE_TIMEOUT=1 \
    bash "$CORROBORATE" "$REPO" 2>/dev/null)" || case4_exit=$?
assert_eq "tier2 unreachable — exit 0" "0" "$case4_exit"
assert_contains "tier2 unreachable — could not corroborate emitted" \
  "could not corroborate" "$case4_out"
rm -rf "$REPO"

# ---------------------------------------------------------------------
# Case 5 — Tier 3, conceptual statement.
# Input has no code-shape signal and no behavioural verbs, so the
# dispatcher emits a single `could not corroborate` line.
# ---------------------------------------------------------------------

REPO="$(mktemp -d -t inkwell-corro-5.XXXXXX)"
build_repo "$REPO"

case5_chunks="### docs/concepts/philosophy.md#philosophy

# Philosophy

Documentation is a contract with the future reader. We aim for clear
prose, plain words, and honest scope.
"

case5_out="$(printf '%s' "$case5_chunks" \
  | INKWELL_CORROBORATE_SUBAGENT=/bin/false bash "$CORROBORATE" "$REPO" 2>/dev/null)"
expected_tier3="docs/concepts/philosophy.md#philosophy"$'\t'"could not corroborate"
assert_eq "tier3 conceptual — single could-not-corroborate line" \
  "$expected_tier3" "$case5_out"
rm -rf "$REPO"

# ---------------------------------------------------------------------
# Case 6 — Triple-run determinism on Tier 1 + Tier 3 paths.
# Tier 2 is non-deterministic by design (ADR-007 negative consequence).
# Run the dispatcher three times against a chunk that mixes Tier 1
# and Tier 3 inputs and assert byte-equivalence.
# ---------------------------------------------------------------------

REPO="$(mktemp -d -t inkwell-corro-6.XXXXXX)"
build_repo "$REPO"

case6_chunks="### docs/auth/sessions.md#sessions

# Sessions

\`src/auth/login.ts:validateSession\` is the JWT verifier.
\`path/to/missing.ts:foo\` is broken on purpose.

### docs/concepts/philosophy.md#philosophy

# Philosophy

Documentation is a contract with the future reader.
"

# Pin the subagent off so Tier 2 can't ever fire — only Tier 1 + Tier 3
# contribute to the verdict stream.
SUBAGENT_OFF=/bin/false
r1="$(printf '%s' "$case6_chunks" \
  | INKWELL_CORROBORATE_SUBAGENT="$SUBAGENT_OFF" bash "$CORROBORATE" "$REPO" 2>/dev/null)"
r2="$(printf '%s' "$case6_chunks" \
  | INKWELL_CORROBORATE_SUBAGENT="$SUBAGENT_OFF" bash "$CORROBORATE" "$REPO" 2>/dev/null)"
r3="$(printf '%s' "$case6_chunks" \
  | INKWELL_CORROBORATE_SUBAGENT="$SUBAGENT_OFF" bash "$CORROBORATE" "$REPO" 2>/dev/null)"
if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
  echo "FAIL [triple-run determinism]: stdout diverged across runs" >&2
  echo "  r1: $r1" >&2
  echo "  r2: $r2" >&2
  echo "  r3: $r3" >&2
  fail=1
fi

# Also pin the determinism check's expected verdict shape: tier 1
# verified line for the real symbol, tier 1 drift for the missing
# file, tier 3 fallback for the philosophy section.
assert_contains "triple-run — tier1 verified" \
  "docs/auth/sessions.md#sessions"$'\t'"verified" "$r1"
assert_contains "triple-run — tier1 drift" \
  "drift detected" "$r1"
assert_contains "triple-run — tier3 fallback" \
  "docs/concepts/philosophy.md#philosophy"$'\t'"could not corroborate" "$r1"

rm -rf "$REPO"

# ---------------------------------------------------------------------

if (( fail == 0 )); then
  echo "inkwell-corroborate.test.sh: PASS"
  exit 0
else
  echo "inkwell-corroborate.test.sh: FAIL" >&2
  exit 1
fi
