#!/usr/bin/env bash
# inkwell-index.test.sh — exercise bin/inkwell-index.sh against
# the bin-docs fixture and the empty-docs/ short-circuit.
#
# Mirrors the assert_eq + triple_run style of the scorer tests under
# plugins/inkwell/scorers/tests/. Triple-run here means: after the
# initial index build, three additional runs over the same tree must
# produce zero row count change (the idempotency invariant).

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
INDEXER="$PLUGIN_ROOT/bin/inkwell-index.sh"
FIXTURE_BLUEPRINT="$HERE/fixtures/bin-docs/docs"
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL [$label]: expected '$expected', got '$actual'" >&2
    fail=1
  fi
}

# -------------------------------------------------------------------
# Case 1 — populated fixture: row count, content presence,
# idempotency over four total runs.
# -------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/docs"
cp -R "$FIXTURE_BLUEPRINT/." "$TMP/docs/"

# First-run build.
"$INDEXER" "$TMP"
DB="$TMP/docs/.inkwell.fts5.db"

if [[ ! -f "$DB" ]]; then
  echo "FAIL [populated]: no DB created at $DB" >&2
  fail=1
else
  count=$(sqlite3 "$DB" "SELECT count(*) FROM docs;")
  assert_eq "populated row count" "5" "$count"

  # Each fixture file should appear exactly once.
  for rel in \
    docs/concepts/auth.md \
    docs/concepts/tagless.md \
    docs/auth/session.md \
    docs/howtos/rate-limit.md \
    docs/howtos/orphan.md
  do
    n=$(sqlite3 "$DB" "SELECT count(*) FROM docs WHERE path = '$rel';")
    assert_eq "row presence: $rel" "1" "$n"
  done

  # Frontmatter parsing — title and template must round-trip.
  title=$(sqlite3 "$DB" "SELECT title FROM docs WHERE path = 'docs/concepts/auth.md';")
  assert_eq "title parsed" "Authentication" "$title"
  tmpl=$(sqlite3 "$DB" "SELECT template FROM docs WHERE path = 'docs/concepts/auth.md';")
  assert_eq "template parsed" "concept" "$tmpl"
  tags=$(sqlite3 "$DB" "SELECT tags FROM docs WHERE path = 'docs/auth/session.md';")
  assert_eq "tags parsed (3-tag inline list)" "auth security jwt" "$tags"

  # Body indexed: the fixture's sentinel must be findable.
  hit=$(sqlite3 "$DB" "SELECT path FROM docs WHERE docs MATCH 'SENTINEL_AUTH_FIXTURE_TOKEN';")
  assert_eq "sentinel matchable" "docs/concepts/auth.md" "$hit"
fi

# Triple-run idempotency: row count unchanged across three more runs.
"$INDEXER" "$TMP"
"$INDEXER" "$TMP"
"$INDEXER" "$TMP"
count_after=$(sqlite3 "$DB" "SELECT count(*) FROM docs;")
assert_eq "rowcount stable across triple-run" "5" "$count_after"

# -------------------------------------------------------------------
# Case 2 — incremental: edit one file, re-run, verify the row's body
# changed but row count did not.
# -------------------------------------------------------------------
EDIT_PATH="$TMP/docs/concepts/auth.md"
# Bump mtime by appending content so the indexer notices the change.
printf '\n\nINCREMENTAL_EDIT_TOKEN appended.\n' >>"$EDIT_PATH"
# Force mtime forward in case appends within the same second don't
# advance it on some filesystems.
touch -d "@$(( $(date +%s) + 2 ))" "$EDIT_PATH"

"$INDEXER" "$TMP"
count_inc=$(sqlite3 "$DB" "SELECT count(*) FROM docs;")
assert_eq "rowcount stable after edit" "5" "$count_inc"
edit_hit=$(sqlite3 "$DB" "SELECT path FROM docs WHERE docs MATCH 'INCREMENTAL_EDIT_TOKEN';")
assert_eq "edited body re-indexed" "docs/concepts/auth.md" "$edit_hit"

# -------------------------------------------------------------------
# Case 3 — vanish prune: delete a file, re-run, row drops out.
# -------------------------------------------------------------------
rm "$TMP/docs/howtos/orphan.md"
"$INDEXER" "$TMP"
count_vanish=$(sqlite3 "$DB" "SELECT count(*) FROM docs;")
assert_eq "rowcount drops after vanish" "4" "$count_vanish"
present=$(sqlite3 "$DB" "SELECT count(*) FROM docs WHERE path = 'docs/howtos/orphan.md';")
assert_eq "orphan row pruned" "0" "$present"

# -------------------------------------------------------------------
# Case 4 — empty docs/: exit 0 with no DB written.
# -------------------------------------------------------------------
EMPTY="$(mktemp -d)"
mkdir -p "$EMPTY/docs"
"$INDEXER" "$EMPTY"
empty_db="$EMPTY/docs/.inkwell.fts5.db"
if [[ -e "$empty_db" ]]; then
  echo "FAIL [empty-docs]: index file created against empty docs/" >&2
  fail=1
fi
rm -rf "$EMPTY"

# -------------------------------------------------------------------
# Case 5 — no docs/ at all: exit 0 silently.
# -------------------------------------------------------------------
NODOCS="$(mktemp -d)"
"$INDEXER" "$NODOCS"  # Must not error.
rm -rf "$NODOCS"

if (( fail == 0 )); then
  echo "inkwell-index.test.sh: PASS"
  exit 0
else
  echo "inkwell-index.test.sh: FAIL" >&2
  exit 1
fi
