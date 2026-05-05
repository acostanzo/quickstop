#!/usr/bin/env bash
# inkwell-doc-resolve.test.sh — exercise bin/inkwell-doc-resolve.sh
# against ad-hoc fixtures. The resolver is the single source of truth
# for the doc skill's update-vs-scaffold branch; this test pins:
#
#   1. Slug match: topic whose slug equals an existing file basename
#      resolves to that file.
#   2. Title match: topic whose slug doesn't match any filename but
#      whose case-insensitive equality matches the `title:` of
#      exactly one frontmatter resolves to that file.
#   3. Ambiguous: two docs share a `title:` matching the topic →
#      `ambiguous` line with both paths.
#   4. None: no slug or title match → `none`.
#   5. Triple-run determinism on each.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
RESOLVER="$PLUGIN_ROOT/bin/inkwell-doc-resolve.sh"
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL [$label]: expected '$expected', got '$actual'" >&2
    fail=1
  fi
}

triple_run_resolve() {
  local topic="$1" repo="$2"
  local r1 r2 r3
  r1=$("$RESOLVER" "$topic" "$repo" 2>/dev/null)
  r2=$("$RESOLVER" "$topic" "$repo" 2>/dev/null)
  r3=$("$RESOLVER" "$topic" "$repo" 2>/dev/null)
  if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
    echo "FAIL [triple-run: $topic]: stdout diverged across runs" >&2
    fail=1
  fi
  printf '%s' "$r1"
}

write_doc() {
  local path="$1" title="$2"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<EOF
---
title: $title
updated: 2026-05-05
template: concept
tags: [test]
---

# $title

Body.
EOF
}

# -------------------------------------------------------------------
# Case 1 — slug match. Topic `auth` should find `docs/auth.md`.
# -------------------------------------------------------------------
TMP_SLUG="$(mktemp -d)"
write_doc "$TMP_SLUG/docs/auth.md" "Auth"
out_slug=$(triple_run_resolve "auth" "$TMP_SLUG")
assert_eq "slug match" "match docs/auth.md" "$out_slug"
rm -rf "$TMP_SLUG"

# -------------------------------------------------------------------
# Case 2 — title match. Topic `Authentication` should find
# `docs/concepts/auth.md` whose `title:` is `Authentication`. The
# slug `authentication` doesn't appear as a filename, so resolution
# falls through to the title scan.
# -------------------------------------------------------------------
TMP_TITLE="$(mktemp -d)"
write_doc "$TMP_TITLE/docs/concepts/auth.md" "Authentication"
out_title=$(triple_run_resolve "Authentication" "$TMP_TITLE")
assert_eq "title match" "match docs/concepts/auth.md" "$out_title"
rm -rf "$TMP_TITLE"

# -------------------------------------------------------------------
# Case 3 — ambiguous. Two docs both titled `Auth` (and at distinct
# slugs so neither is hit by the slug branch) should emit an
# `ambiguous` line listing both paths.
# -------------------------------------------------------------------
TMP_AMBIG="$(mktemp -d)"
write_doc "$TMP_AMBIG/docs/concepts/auth-a.md" "Auth"
write_doc "$TMP_AMBIG/docs/concepts/auth-b.md" "Auth"
out_ambig=$(triple_run_resolve "Auth" "$TMP_AMBIG")
# Output is `ambiguous <path1> <path2>`. The find walk is alphabetised,
# so order is deterministic: auth-a before auth-b.
assert_eq "ambiguous" \
  "ambiguous docs/concepts/auth-a.md docs/concepts/auth-b.md" \
  "$out_ambig"
rm -rf "$TMP_AMBIG"

# -------------------------------------------------------------------
# Case 4 — none. Topic `Brand New` has no slug or title match.
# -------------------------------------------------------------------
TMP_NONE="$(mktemp -d)"
write_doc "$TMP_NONE/docs/concepts/auth.md" "Authentication"
out_none=$(triple_run_resolve "Brand New" "$TMP_NONE")
assert_eq "none" "none" "$out_none"
rm -rf "$TMP_NONE"

# -------------------------------------------------------------------
# Case 5 — empty docs/ (or absent). The skill should scaffold; the
# resolver returns `none`.
# -------------------------------------------------------------------
TMP_EMPTY="$(mktemp -d)"
out_empty=$(triple_run_resolve "Anything" "$TMP_EMPTY")
assert_eq "absent docs/" "none" "$out_empty"
mkdir -p "$TMP_EMPTY/docs"
out_empty_dir=$(triple_run_resolve "Anything" "$TMP_EMPTY")
assert_eq "empty docs/" "none" "$out_empty_dir"
rm -rf "$TMP_EMPTY"

if (( fail == 0 )); then
  echo "inkwell-doc-resolve.test.sh: PASS"
  exit 0
else
  echo "inkwell-doc-resolve.test.sh: FAIL" >&2
  exit 1
fi
