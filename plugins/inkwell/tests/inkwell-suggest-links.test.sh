#!/usr/bin/env bash
# inkwell-suggest-links.test.sh — exercise bin/inkwell-suggest-links.sh
# against the bin-docs fixture.
#
# Verifies:
#   1. Tag-overlap target (concepts/auth.md, tags=auth,security) →
#      auth/session.md (tags=auth,security,jwt) is the top hit.
#   2. Suggestions exclude the target itself.
#   3. Orphan doc (tags=random,unrelated) never appears in
#      suggestions for either auth doc.
#   4. Tagless target → "no automatic suggestion" on stderr,
#      empty stdout, exit 0.
#   5. Triple-run determinism: byte-equivalent stdout across runs.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
SUGGESTER="$PLUGIN_ROOT/bin/inkwell-suggest-links.sh"
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

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "FAIL [$label]: expected NOT to contain '$needle'" >&2
    echo "  actual: $haystack" >&2
    fail=1
  fi
}

triple_run_suggest() {
  local target="$1" repo="$2"
  local r1 r2 r3
  r1=$("$SUGGESTER" "$target" "$repo" 2>/dev/null)
  r2=$("$SUGGESTER" "$target" "$repo" 2>/dev/null)
  r3=$("$SUGGESTER" "$target" "$repo" 2>/dev/null)
  if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
    echo "FAIL [triple-run: $target]: stdout diverged across runs" >&2
    fail=1
  fi
  printf '%s' "$r1"
}

# Setup
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/docs"
cp -R "$FIXTURE_BLUEPRINT/." "$TMP/docs/"

# -------------------------------------------------------------------
# Case 1 — tag-overlap target. concepts/auth.md (auth,security) →
# top hit must be auth/session.md (auth,security,jwt).
# -------------------------------------------------------------------
out=$(triple_run_suggest "$TMP/docs/concepts/auth.md" "$TMP")
assert_contains "auth target → session partner" "docs/auth/session.md" "$out"

# Top hit (first line) is the partner.
top=$(printf '%s\n' "$out" | head -n1)
assert_contains "session is top-1" "docs/auth/session.md" "$top"
# Score column appears in the expected shape.
assert_contains "score column" "score=" "$top"
assert_contains "rationale column" "shared tags" "$top"

# Self-exclusion: the target's own path must not appear.
assert_not_contains "self excluded" "docs/concepts/auth.md" "$out"

# Orphan doc (random,unrelated) must not appear.
assert_not_contains "orphan excluded" "docs/howtos/orphan.md" "$out"

# rate-limit.md (api,security) shares one tag with auth → should
# appear, but ranked below session.md.
assert_contains "single-overlap rate-limit appears" "docs/howtos/rate-limit.md" "$out"

# -------------------------------------------------------------------
# Case 2 — symmetric: target=session, partner=auth.
# -------------------------------------------------------------------
out2=$(triple_run_suggest "$TMP/docs/auth/session.md" "$TMP")
top2=$(printf '%s\n' "$out2" | head -n1)
assert_contains "session target → auth partner top-1" "docs/concepts/auth.md" "$top2"
assert_not_contains "session self excluded" "docs/auth/session.md" "$out2"

# -------------------------------------------------------------------
# Case 3 — tagless target → "no automatic suggestion".
# -------------------------------------------------------------------
out_tagless_stdout=$("$SUGGESTER" "$TMP/docs/concepts/tagless.md" "$TMP" 2>/dev/null)
out_tagless_stderr=$("$SUGGESTER" "$TMP/docs/concepts/tagless.md" "$TMP" 2>&1 >/dev/null)
assert_eq "tagless → empty stdout" "" "$out_tagless_stdout"
assert_contains "tagless → stderr message" "no automatic suggestion" "$out_tagless_stderr"
"$SUGGESTER" "$TMP/docs/concepts/tagless.md" "$TMP" >/dev/null 2>&1
assert_eq "tagless exit code" "0" "$?"

# -------------------------------------------------------------------
# Case 4 — relative-path acceptance (writers reach for whichever
# form is at hand: absolute, repo-relative, or docs-relative).
# -------------------------------------------------------------------
out_rel=$("$SUGGESTER" "docs/concepts/auth.md" "$TMP" 2>/dev/null)
assert_contains "repo-relative input" "docs/auth/session.md" "$out_rel"

out_drel=$("$SUGGESTER" "concepts/auth.md" "$TMP" 2>/dev/null)
assert_contains "docs-relative input" "docs/auth/session.md" "$out_drel"

if (( fail == 0 )); then
  echo "inkwell-suggest-links.test.sh: PASS"
  exit 0
else
  echo "inkwell-suggest-links.test.sh: FAIL" >&2
  exit 1
fi
