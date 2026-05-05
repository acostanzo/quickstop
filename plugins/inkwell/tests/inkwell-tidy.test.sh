#!/usr/bin/env bash
# inkwell-tidy.test.sh — exercise bin/inkwell-tidy.sh across the three
# documented modes (read-only / --apply / --apply-semantic) and the
# determinism contract.
#
# Cases:
#   1. Read-only against the bin-docs fixture: tagless.md must fire
#      missing-related (no `## Related` heading at all).
#   2. Read-only against a clean fixture: exit 0 with empty stdout.
#   3. --apply bumps a stale frontmatter `updated:` to today's date when
#      the git mtime is more recent than the recorded value.
#   4. --apply archives a stale doc under docs/archive/<original> and
#      preserves the under-docs subpath.
#   5. --apply-semantic writes a unified diff to stdout and does NOT
#      touch the working tree (asserted via `git status --porcelain`).
#   6. Triple-run determinism on the read-only path.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
TIDY="$PLUGIN_ROOT/bin/inkwell-tidy.sh"
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

triple_run_tidy() {
  local repo="$1"
  local r1 r2 r3
  r1=$("$TIDY" "$repo" 2>/dev/null)
  r2=$("$TIDY" "$repo" 2>/dev/null)
  r3=$("$TIDY" "$repo" 2>/dev/null)
  if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
    echo "FAIL [triple-run: $(basename "$repo")]: stdout diverged" >&2
    fail=1
  fi
  printf '%s' "$r1"
}

# ---- shared helpers (mirrored from doc-staleness.test.sh) ----

init_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email "fixture@inkwell.test"
  git -C "$repo" config user.name "Fixture Author"
}

# commit_at <repo> <iso_date> <message>  — commit whatever's staged at
# the given timestamp.
commit_at() {
  local repo="$1" iso="$2" msg="$3"
  GIT_AUTHOR_DATE="$iso" GIT_COMMITTER_DATE="$iso" \
    git -C "$repo" commit -q -m "$msg"
}

WORKDIR="$(mktemp -d -t inkwell-tidy-test.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

NOW_TS=$(date +%s)
TODAY_ISO=$(date -u -d "@$NOW_TS" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -r "$NOW_TS" +%Y-%m-%dT%H:%M:%SZ)
STALE_TS=$((NOW_TS - 125*86400))
STALE_ISO=$(date -u -d "@$STALE_TS" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
            || date -u -r "$STALE_TS" +%Y-%m-%dT%H:%M:%SZ)

# -------------------------------------------------------------------
# Case 1 — read-only against bin-docs blueprint. tagless.md has no
# `## Related` heading at all, so missing-related must fire on it.
# -------------------------------------------------------------------
BIN_DOCS_REPO="$WORKDIR/bin-docs"
mkdir -p "$BIN_DOCS_REPO/docs"
cp -R "$FIXTURE_BLUEPRINT/." "$BIN_DOCS_REPO/docs/"
out_bd=$(triple_run_tidy "$BIN_DOCS_REPO")
assert_contains "bin-docs tagless missing-related" \
  "docs/concepts/tagless.md  rule=missing-related" "$out_bd"

# -------------------------------------------------------------------
# Case 2 — clean fixture: well-formed docs with `## Related` content
# and current frontmatter -> exit 0, empty stdout.
# -------------------------------------------------------------------
CLEAN_REPO="$WORKDIR/clean"
mkdir -p "$CLEAN_REPO/docs"
cat >"$CLEAN_REPO/docs/alpha.md" <<EOF
---
title: Alpha
updated: ${TODAY_ISO%T*}
template: concept
tags: [demo]
---

# Alpha

A clean concept doc.

## Related

- [Beta](beta.md)
EOF
cat >"$CLEAN_REPO/docs/beta.md" <<EOF
---
title: Beta
updated: ${TODAY_ISO%T*}
template: how-to
tags: [demo]
---

# Beta

A clean how-to doc.

## Related

- [Alpha](alpha.md)
EOF
out_clean=$(triple_run_tidy "$CLEAN_REPO")
assert_eq "clean fixture empty stdout" "" "$out_clean"
"$TIDY" "$CLEAN_REPO" >/dev/null 2>&1
assert_eq "clean fixture exit 0" "0" "$?"

# -------------------------------------------------------------------
# Case 3 — --apply bumps stale `updated:` when git mtime is fresher.
# Frontmatter says 2026-01-01; git commit lands at TODAY_ISO. After
# --apply, the line must read today's date.
# -------------------------------------------------------------------
BUMP_REPO="$WORKDIR/bump"
init_repo "$BUMP_REPO"
mkdir -p "$BUMP_REPO/docs"
cat >"$BUMP_REPO/docs/lagged.md" <<'EOF'
---
title: Lagged
updated: 2026-01-01
template: concept
tags: [bump]
---

# Lagged

This doc's frontmatter `updated:` is older than its git mtime; the
--apply path should bump the line to today's date.

## Related

- [Alpha](alpha.md)
EOF
git -C "$BUMP_REPO" add docs/lagged.md
commit_at "$BUMP_REPO" "$TODAY_ISO" "init lagged doc"

"$TIDY" --apply "$BUMP_REPO" >/dev/null 2>&1 || true
new_updated=$(awk '
  NR==1 && $0=="---" { in_fm=1; next }
  in_fm && $0=="---" { exit }
  in_fm && /^updated:/ { sub(/^updated:[[:space:]]*/, ""); print; exit }
' "$BUMP_REPO/docs/lagged.md")
assert_eq "updated: bumped to today" "${TODAY_ISO%T*}" "$new_updated"

# Body is preserved (no prose rewrite).
body_preserved=$(grep -c "frontmatter \`updated:\` is older" "$BUMP_REPO/docs/lagged.md")
assert_eq "body untouched by --apply" "1" "$body_preserved"

# -------------------------------------------------------------------
# Case 4 — --apply archives a stale doc under docs/archive/.
# Doc committed 125 days ago triggers rule=stale; --apply should
# `git mv` it to docs/archive/legacy/old.md.
# -------------------------------------------------------------------
ARCHIVE_REPO="$WORKDIR/archive"
init_repo "$ARCHIVE_REPO"
mkdir -p "$ARCHIVE_REPO/docs/legacy"
cat >"$ARCHIVE_REPO/docs/legacy/old.md" <<EOF
---
title: Old
updated: ${STALE_ISO%T*}
template: concept
tags: [legacy]
---

# Old

This doc has not been touched in 125 days. It should be flagged stale
and archived under docs/archive/legacy/old.md.

## Related

- [Index](../index.md)
EOF
cat >"$ARCHIVE_REPO/docs/index.md" <<EOF
---
title: Index
updated: ${TODAY_ISO%T*}
template: concept
tags: [index]
---

# Index

Pointer doc that links at the legacy doc:
[Legacy old](legacy/old.md).

## Related

- [Old](legacy/old.md)
EOF
git -C "$ARCHIVE_REPO" add docs/legacy/old.md docs/index.md
commit_at "$ARCHIVE_REPO" "$STALE_ISO" "init legacy old"
# Touch the index doc with a fresh commit so its git mtime is current.
sed -i 's/Pointer doc/Pointer doc/' "$ARCHIVE_REPO/docs/index.md" 2>/dev/null || true
git -C "$ARCHIVE_REPO" commit --allow-empty -q -m "noop refresh" \
  --date="$TODAY_ISO" >/dev/null 2>&1 || \
  GIT_AUTHOR_DATE="$TODAY_ISO" GIT_COMMITTER_DATE="$TODAY_ISO" \
    git -C "$ARCHIVE_REPO" commit --allow-empty -q -m "noop refresh"

apply_out=$("$TIDY" --apply "$ARCHIVE_REPO" 2>/dev/null)
assert_contains "archive applied line" \
  "applied  rule=archive-stale  docs/legacy/old.md → docs/archive/legacy/old.md" "$apply_out"
[[ -f "$ARCHIVE_REPO/docs/archive/legacy/old.md" ]] && moved=yes || moved=no
assert_eq "stale doc moved to archive" "yes" "$moved"
[[ -e "$ARCHIVE_REPO/docs/legacy/old.md" ]] && still_there=yes || still_there=no
assert_eq "stale doc no longer at original path" "no" "$still_there"

# -------------------------------------------------------------------
# Case 5 — --apply-semantic emits a unified diff for a near-duplicate
# pair (overlap in 0.85..0.95 band) and does NOT modify the working
# tree. Asserted via `git status --porcelain` being empty after.
# -------------------------------------------------------------------
SEMANTIC_REPO="$WORKDIR/semantic"
init_repo "$SEMANTIC_REPO"
mkdir -p "$SEMANTIC_REPO/docs"

# Build two near-identical bodies. The bigram extractor takes title +
# body, lowercases, splits on non-alphanumerics, and emits adjacent
# pairs. By sharing 28 of 30 tokens we land in the 0.85..0.95 band.
SHARED="alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar papa quebec romeo sierra tango uniform victor whiskey xray yankee zulu apple banana cherry"
cat >"$SEMANTIC_REPO/docs/twin-a.md" <<EOF
---
title: Shared title
updated: ${TODAY_ISO%T*}
template: concept
tags: [twin]
---

# Twin A

$SHARED date

## Related

- [Twin B](twin-b.md)
EOF
cat >"$SEMANTIC_REPO/docs/twin-b.md" <<EOF
---
title: Shared title
updated: ${TODAY_ISO%T*}
template: concept
tags: [twin]
---

# Twin B

$SHARED elderberry

## Related

- [Twin A](twin-a.md)
EOF
git -C "$SEMANTIC_REPO" add -A
commit_at "$SEMANTIC_REPO" "$TODAY_ISO" "init twins"

# Snapshot the working tree before --apply-semantic.
status_before=$(git -C "$SEMANTIC_REPO" status --porcelain)

semantic_out=$("$TIDY" --apply-semantic "$SEMANTIC_REPO" 2>/dev/null)
assert_contains "semantic emits diff header" "--- a/docs/twin-" "$semantic_out"
assert_contains "semantic targets /dev/null" "+++ /dev/null" "$semantic_out"

status_after=$(git -C "$SEMANTIC_REPO" status --porcelain)
assert_eq "semantic leaves working tree clean" "$status_before" "$status_after"

# Belt-and-braces: neither twin file was deleted.
[[ -f "$SEMANTIC_REPO/docs/twin-a.md" && -f "$SEMANTIC_REPO/docs/twin-b.md" ]] && both=yes || both=no
assert_eq "semantic preserves both twins on disk" "yes" "$both"

# -------------------------------------------------------------------
# Case 6 — --apply rewrites inbound links across a git rename. The
# sibling doc's `(../concepts/auth.md)` link is rewritten to
# `(../concepts/authentication.md)` after `git mv` of the rename
# target. Exercises the portable realpath shim
# (_path_canonical / _path_relative_to) on the rewrite path; without
# the shim, BSD/macOS realpath would fail silently and the test
# would catch the regression.
# -------------------------------------------------------------------
RENAME_REPO="$WORKDIR/rename"
init_repo "$RENAME_REPO"
mkdir -p "$RENAME_REPO/docs/concepts" "$RENAME_REPO/docs/howtos"
cat >"$RENAME_REPO/docs/concepts/auth.md" <<EOF
---
title: Authentication
updated: ${TODAY_ISO%T*}
template: concept
tags: [auth]
---

# Authentication

What auth is and how it fits.

## Related

- [Sign-in how-to](../howtos/sign-in.md)
EOF
cat >"$RENAME_REPO/docs/howtos/sign-in.md" <<EOF
---
title: Sign in
updated: ${TODAY_ISO%T*}
template: how-to
tags: [auth]
---

# Sign in

See [Authentication](../concepts/auth.md) for the concept doc.

## Related

- [Authentication](../concepts/auth.md)
EOF
git -C "$RENAME_REPO" add -A
commit_at "$RENAME_REPO" "$TODAY_ISO" "init auth + sign-in"
git -C "$RENAME_REPO" mv docs/concepts/auth.md docs/concepts/authentication.md
commit_at "$RENAME_REPO" "$TODAY_ISO" "rename auth.md to authentication.md"

"$TIDY" --apply "$RENAME_REPO" >/dev/null 2>&1 || true
sign_in_body=$(cat "$RENAME_REPO/docs/howtos/sign-in.md")
assert_contains "rename rewrites inbound link to new path" \
  "(../concepts/authentication.md)" "$sign_in_body"
assert_not_contains "rename clears the old link target" \
  "(../concepts/auth.md)" "$sign_in_body"

# -------------------------------------------------------------------
# Case 7 — `<!-- inkwell:related -->` comment counts as
# writer-acknowledged-empty. A fresh scaffold with the comment
# placeholder must NOT fire missing-related; a doc with the legacy
# bare `-` placeholder still fires (so authors get nudged to migrate).
# -------------------------------------------------------------------
PLACEHOLDER_REPO="$WORKDIR/placeholder"
mkdir -p "$PLACEHOLDER_REPO/docs"
cat >"$PLACEHOLDER_REPO/docs/fresh.md" <<EOF
---
title: Fresh
updated: ${TODAY_ISO%T*}
template: concept
tags: [fresh]
---

# Fresh

Just-scaffolded doc, no siblings yet.

## Related

<!-- inkwell:related — populate when the doc earns siblings -->
EOF
cat >"$PLACEHOLDER_REPO/docs/legacy.md" <<EOF
---
title: Legacy
updated: ${TODAY_ISO%T*}
template: concept
tags: [legacy]
---

# Legacy

Doc that still carries the bare-dash placeholder from before 0.4.1.

## Related

-
EOF
out_placeholder=$("$TIDY" "$PLACEHOLDER_REPO" 2>/dev/null)
assert_not_contains "comment placeholder doesn't fire missing-related" \
  "docs/fresh.md  rule=missing-related" "$out_placeholder"
assert_contains "bare-dash placeholder still fires missing-related" \
  "docs/legacy.md  rule=missing-related" "$out_placeholder"

# -------------------------------------------------------------------
# Case 8 — triple-run determinism on the read-only path is exercised
# by every triple_run_tidy call above; this final guard re-asserts on
# the bin-docs fixture explicitly.
# -------------------------------------------------------------------
out_a=$("$TIDY" "$BIN_DOCS_REPO" 2>/dev/null)
out_b=$("$TIDY" "$BIN_DOCS_REPO" 2>/dev/null)
out_c=$("$TIDY" "$BIN_DOCS_REPO" 2>/dev/null)
assert_eq "triple-run a==b" "$out_a" "$out_b"
assert_eq "triple-run b==c" "$out_b" "$out_c"

if (( fail == 0 )); then
  echo "inkwell-tidy.test.sh: PASS"
  exit 0
else
  echo "inkwell-tidy.test.sh: FAIL" >&2
  exit 1
fi
