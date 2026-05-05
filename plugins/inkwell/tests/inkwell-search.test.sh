#!/usr/bin/env bash
# inkwell-search.test.sh — exercise bin/inkwell-search.sh against
# the bin-docs fixture.
#
# Verifies:
#   1. A unique sentinel inserted in a fixture doc is findable, and
#      the matching path is the doc that carries it.
#   2. Output line shape: `path:line  [tags]  snippet`.
#   3. Triple-run determinism: three searches over the same fixture
#      produce byte-equivalent stdout.
#   4. Empty docs/ → clean exit + stderr message + empty stdout.
#   5. No-match query → empty stdout + exit 0.
#   6. On-write contract: writing a new file then searching for its
#      content reflects without an explicit reindex call (the search
#      wrapper invokes the indexer).

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
SEARCHER="$PLUGIN_ROOT/bin/inkwell-search.sh"
FIXTURE_BLUEPRINT="$HERE/fixtures/bin-docs/docs"
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

triple_run_search() {
  local query="$1" repo="$2"
  local r1 r2 r3
  r1=$("$SEARCHER" "$query" "$repo" 2>/dev/null)
  r2=$("$SEARCHER" "$query" "$repo" 2>/dev/null)
  r3=$("$SEARCHER" "$query" "$repo" 2>/dev/null)
  if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
    echo "FAIL [triple-run: $query]: stdout diverged across runs" >&2
    fail=1
  fi
  printf '%s' "$r1"
}

# -------------------------------------------------------------------
# Setup — populate fixture and prebuild the index.
# -------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/docs"
cp -R "$FIXTURE_BLUEPRINT/." "$TMP/docs/"

# -------------------------------------------------------------------
# Case 1 — sentinel match.
# -------------------------------------------------------------------
out=$(triple_run_search "SENTINEL_AUTH_FIXTURE_TOKEN" "$TMP")
assert_contains "sentinel hit path" "docs/concepts/auth.md" "$out"
# Output line shape: <path>:<line>  [<tags>]  <snippet>
assert_contains "tags rendered" "[auth, security]" "$out"
# A single match → exactly one stdout line.
line_count=$(printf '%s\n' "$out" | grep -c . || true)
assert_eq "single hit line count" "1" "$line_count"

# -------------------------------------------------------------------
# Case 2 — phrase / multi-doc query: prefix wildcard returns multiple
# hits, ranked.
# -------------------------------------------------------------------
out_multi=$(triple_run_search "auth*" "$TMP")
multi_count=$(printf '%s\n' "$out_multi" | grep -c . || true)
# Three docs carry auth-prefixed tokens (concepts/auth, auth/session,
# concepts/tagless body has none — but title field "Authentication"
# matches auth.md once, "Sessions" body matches once via inline
# `validateSession`, and rate-limit body has no auth- token, so
# realistic floor is 2).
if (( multi_count < 2 )); then
  echo "FAIL [multi-hit]: expected ≥2 hits for 'auth*', got $multi_count" >&2
  echo "  actual: $out_multi" >&2
  fail=1
fi

# -------------------------------------------------------------------
# Case 3 — no-match query → empty stdout, exit 0.
# -------------------------------------------------------------------
out_none=$("$SEARCHER" "zzz_no_such_token_xyzzy" "$TMP" 2>/dev/null)
assert_eq "no-match → empty stdout" "" "$out_none"
"$SEARCHER" "zzz_no_such_token_xyzzy" "$TMP" >/dev/null 2>&1
assert_eq "no-match exit code" "0" "$?"

# -------------------------------------------------------------------
# Case 4 — empty docs/: clean exit + stderr message + empty stdout.
# -------------------------------------------------------------------
EMPTY="$(mktemp -d)"
mkdir -p "$EMPTY/docs"
out_empty=$("$SEARCHER" "anything" "$EMPTY" 2>/dev/null)
err_empty=$("$SEARCHER" "anything" "$EMPTY" 2>&1 >/dev/null)
assert_eq "empty docs → empty stdout" "" "$out_empty"
assert_contains "empty docs → stderr message" "no documents indexed" "$err_empty"
"$SEARCHER" "anything" "$EMPTY" >/dev/null 2>&1
assert_eq "empty docs exit code" "0" "$?"
rm -rf "$EMPTY"

# -------------------------------------------------------------------
# Case 5 — on-write contract: write a new file then search for its
# content. The wrapper must invoke the indexer transparently; the
# new doc is searchable without an explicit reindex.
# -------------------------------------------------------------------
NEW_FILE="$TMP/docs/concepts/just-written.md"
cat >"$NEW_FILE" <<'EOF'
---
title: Just Written
updated: 2026-05-05
template: concept
tags: [fresh]
---

# Just Written

This file carries ON_WRITE_CONTRACT_TOKEN to verify the search
wrapper's transparent reindex.
EOF
# Push mtime forward to defeat same-second mtime granularity.
touch -d "@$(( $(date +%s) + 2 ))" "$NEW_FILE"
out_onwrite=$("$SEARCHER" "ON_WRITE_CONTRACT_TOKEN" "$TMP" 2>/dev/null)
assert_contains "on-write reindex hit" "docs/concepts/just-written.md" "$out_onwrite"

if (( fail == 0 )); then
  echo "inkwell-search.test.sh: PASS"
  exit 0
else
  echo "inkwell-search.test.sh: FAIL" >&2
  exit 1
fi
