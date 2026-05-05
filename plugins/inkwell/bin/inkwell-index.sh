#!/usr/bin/env bash
# inkwell-index.sh — build or incrementally refresh the FTS5 index
# over `docs/` at <REPO_ROOT>.
#
# The index file lives at `docs/.inkwell.fts5.db`. It is gitignored
# (the repo's `.gitignore` excludes `*.db`) and rebuilt on demand —
# the index is a derived artefact, never a source of truth.
#
# Per-file rows. Chunk-level retrieval is a v2 concern (per t2 brief).
# Frontmatter is parsed for title/template/tags; the markdown body
# (frontmatter stripped) is the indexed text.
#
# Idempotency: file mtimes are cached in a `docs_meta` table. A second
# run over an unchanged tree touches no FTS5 rows. Files that have
# disappeared since the last run are pruned.
#
# Empty-scope contract: if `<REPO_ROOT>/docs/` does not exist or
# contains no `*.md` files, exit 0 cleanly with no index file written
# (nothing to crash the search wrapper later — see inkwell-search.sh).
#
# Usage:
#   inkwell-index.sh [REPO_ROOT]
#
# REPO_ROOT defaults to `pwd` if omitted. Exit 0 on success; exit 2
# on argument errors; exit 3 if `sqlite3` is missing from PATH.

set -euo pipefail

REPO_ROOT="${1:-$(pwd)}"
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "inkwell-index.sh: sqlite3 not found on PATH" >&2
  exit 3
fi

DOCS_DIR="$REPO_ROOT/docs"
DB="$DOCS_DIR/.inkwell.fts5.db"

if [[ ! -d "$DOCS_DIR" ]]; then
  exit 0
fi

# Collect markdown files. Excludes the `templates/` subdirectory of
# inkwell itself (we never want to index template scaffolding) and
# any file starting with `_` (convention: drafts).
mapfile -t MD_FILES < <(find "$DOCS_DIR" -type f -name '*.md' \
  ! -path "$DOCS_DIR/templates/*" \
  ! -name '_*.md' 2>/dev/null | LC_ALL=C sort)

if (( ${#MD_FILES[@]} == 0 )); then
  # No docs to index. Don't touch existing DB (writer may have just
  # cleared docs/ temporarily) but don't create one either.
  exit 0
fi

# ---- portable mtime helper -----------------------------------------------
# GNU stat: -c %Y; BSD/macOS stat: -f %m. Detect once.
if stat -c %Y "$DOCS_DIR" >/dev/null 2>&1; then
  _stat_mtime() { stat -c %Y "$1"; }
else
  _stat_mtime() { stat -f %m "$1"; }
fi

# ---- escape for sqlite3 single-quoted string literals --------------------
# SQLite's only escape inside single-quoted strings is doubling the
# single quote. Newlines and other characters pass through unchanged.
sql_escape() {
  local s="${1-}"
  printf '%s' "${s//\'/\'\'}"
}

# ---- frontmatter helpers -------------------------------------------------
# extract_frontmatter <file>  — print everything between the first
# leading `---` line and the next `---` line (exclusive). If no
# frontmatter block is present, prints nothing.
extract_frontmatter() {
  awk '
    NR==1 && $0=="---" { in_fm=1; next }
    in_fm && $0=="---" { exit }
    in_fm { print }
  ' "$1"
}

# extract_body <file> — print the markdown body with the frontmatter
# block removed. If no frontmatter, prints the file verbatim.
extract_body() {
  awk '
    NR==1 && $0=="---" { in_fm=1; next }
    in_fm && $0=="---" { in_fm=0; past_fm=1; next }
    in_fm { next }
    { print }
  ' "$1"
}

# fm_field <key> <frontmatter-text>
# Returns the value of a single-line `key: value` field. Strips
# leading/trailing whitespace and surrounding quotes.
fm_field() {
  local key="$1" fm="$2"
  awk -v k="$key" '
    BEGIN { needle = "^" k ":[[:space:]]*" }
    $0 ~ needle {
      sub(needle, "")
      sub(/[[:space:]]+$/, "")
      gsub(/^"|"$/, "")
      gsub(/^'\''|'\''$/, "")
      print
      exit
    }
  ' <<<"$fm"
}

# fm_tags <frontmatter-text> — flatten `tags: [a, b, c]` (or block
# list form) into a space-separated string. Tags appear on the
# observation row UNINDEXED but are surfaced by the search formatter.
fm_tags() {
  local fm="$1"
  # Inline-array form: tags: [a, b, c]
  local inline
  inline=$(awk '/^tags:[[:space:]]*\[/ {
    sub(/^tags:[[:space:]]*\[/, "")
    sub(/\][[:space:]]*$/, "")
    gsub(/,/, " ")
    gsub(/[[:space:]]+/, " ")
    sub(/^[[:space:]]+/, "")
    sub(/[[:space:]]+$/, "")
    print
    exit
  }' <<<"$fm")
  if [[ -n "$inline" ]]; then
    printf '%s' "$inline"
    return
  fi
  # Block-list form:
  #   tags:
  #     - a
  #     - b
  awk '
    /^tags:[[:space:]]*$/ { in_tags=1; next }
    in_tags && /^[[:space:]]+-[[:space:]]+/ {
      sub(/^[[:space:]]+-[[:space:]]+/, "")
      sub(/[[:space:]]+$/, "")
      printf "%s ", $0
      next
    }
    in_tags { exit }
  ' <<<"$fm" | sed 's/ $//'
}

# ---- DB schema -----------------------------------------------------------
# `docs` is the FTS5 virtual table. `docs_meta` is a regular sqlite
# table that pins the last-indexed mtime per path so re-runs over
# unchanged trees do no work.
sqlite3 "$DB" <<'SQL'
CREATE VIRTUAL TABLE IF NOT EXISTS docs USING fts5(
  path UNINDEXED,
  title,
  template UNINDEXED,
  tags UNINDEXED,
  body,
  tokenize='porter unicode61'
);
CREATE TABLE IF NOT EXISTS docs_meta (
  path TEXT PRIMARY KEY,
  mtime INTEGER NOT NULL
);
SQL

# ---- prune rows for vanished files ---------------------------------------
# Build a relative-path manifest, dump existing meta paths, diff, delete.
MANIFEST="$(mktemp)"
KNOWN="$(mktemp)"
trap 'rm -f "$MANIFEST" "$KNOWN"' EXIT

for f in "${MD_FILES[@]}"; do
  printf '%s\n' "${f#$REPO_ROOT/}" >>"$MANIFEST"
done
LC_ALL=C sort -o "$MANIFEST" "$MANIFEST"

sqlite3 "$DB" "SELECT path FROM docs_meta;" | LC_ALL=C sort >"$KNOWN"

# Paths in $KNOWN but not $MANIFEST → vanished, prune.
while IFS= read -r vanished; do
  [[ -z "$vanished" ]] && continue
  esc="$(sql_escape "$vanished")"
  sqlite3 "$DB" "DELETE FROM docs WHERE path = '$esc'; DELETE FROM docs_meta WHERE path = '$esc';"
done < <(LC_ALL=C comm -23 "$KNOWN" "$MANIFEST")

# ---- upsert per file -----------------------------------------------------
for f in "${MD_FILES[@]}"; do
  rel="${f#$REPO_ROOT/}"
  mtime="$(_stat_mtime "$f")"

  cached="$(sqlite3 "$DB" "SELECT mtime FROM docs_meta WHERE path = '$(sql_escape "$rel")';")"
  if [[ "$cached" == "$mtime" ]]; then
    continue
  fi

  fm="$(extract_frontmatter "$f")"
  body="$(extract_body "$f")"
  title="$(fm_field title "$fm")"
  template="$(fm_field template "$fm")"
  tags="$(fm_tags "$fm")"

  # Title fallback: first H1 in the body, else the filename without
  # extension. Title-less docs are still searchable via body match.
  if [[ -z "$title" ]]; then
    title="$(awk '/^# / { sub(/^# /, ""); print; exit }' <<<"$body")"
  fi
  if [[ -z "$title" ]]; then
    title="$(basename "$rel" .md)"
  fi

  esc_path="$(sql_escape "$rel")"
  esc_title="$(sql_escape "$title")"
  esc_template="$(sql_escape "$template")"
  esc_tags="$(sql_escape "$tags")"
  esc_body="$(sql_escape "$body")"

  sqlite3 "$DB" <<SQL
BEGIN;
DELETE FROM docs WHERE path = '$esc_path';
INSERT INTO docs(path, title, template, tags, body)
  VALUES ('$esc_path', '$esc_title', '$esc_template', '$esc_tags', '$esc_body');
INSERT INTO docs_meta(path, mtime) VALUES ('$esc_path', $mtime)
  ON CONFLICT(path) DO UPDATE SET mtime = excluded.mtime;
COMMIT;
SQL
done

exit 0
