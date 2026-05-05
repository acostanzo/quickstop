#!/usr/bin/env bash
# inkwell-search.sh — query the FTS5 index over `docs/` and emit
# ranked hits as `path:line  [tags]  snippet` lines on stdout.
#
# The index is built/refreshed on demand by inkwell-index.sh, which
# this script invokes before each query so the writer never has to
# run `/inkwell:index` between scaffolding and searching (the t2
# on-write contract).
#
# Empty-scope contract: if `docs/` does not exist, is empty, or
# contains no FTS5 rows after indexing, exit 0 with a "no documents
# indexed" message on stderr and empty stdout. Search must never
# crash a writer's flow on a fresh repo.
#
# Usage:
#   inkwell-search.sh <query> [REPO_ROOT]
#
# Exit 0 on success (zero or more hits on stdout, exactly as many
# lines as matches). Exit 2 on argument errors. Exit 3 if `sqlite3`
# is missing.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <query> [REPO_ROOT]" >&2
  exit 2
fi

QUERY="$1"
REPO_ROOT="${2:-$(pwd)}"
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "inkwell-search.sh: sqlite3 not found on PATH" >&2
  exit 3
fi

DOCS_DIR="$REPO_ROOT/docs"
DB="$DOCS_DIR/.inkwell.fts5.db"

# Ensure the index is current before reading. The indexer is cheap
# on the unchanged-tree path (mtime cache) so this is not a
# perf hazard for repeated queries.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$HERE/inkwell-index.sh" "$REPO_ROOT"

if [[ ! -f "$DB" ]]; then
  echo "inkwell-search.sh: no documents indexed (docs/ missing or empty)" >&2
  exit 0
fi

ROWCOUNT="$(sqlite3 "$DB" "SELECT count(*) FROM docs;" 2>/dev/null || echo 0)"
if [[ "$ROWCOUNT" == "0" ]]; then
  echo "inkwell-search.sh: no documents indexed (docs/ missing or empty)" >&2
  exit 0
fi

# Escape the query for an FTS5 MATCH single-quoted string. FTS5
# query syntax (operators, quoted phrases, prefix `*`) passes
# through; this only escapes the outer SQL quoting.
ESC_QUERY="${QUERY//\'/\'\'}"

# FTS5 snippet():
#   col=-1 (any column), open/close markers empty so the snippet is
#   plain text, ellipsis "...", up to 24 tokens of context.
# Pipe-separated columns with `.mode list` + `.separator |` keeps
# parsing straightforward downstream.
RESULTS="$(
  sqlite3 -separator '|' "$DB" <<SQL 2>/dev/null || true
SELECT
  path,
  COALESCE(NULLIF(tags,''), '-'),
  REPLACE(REPLACE(snippet(docs, -1, '', '', '...', 24), char(10), ' '), char(13), ' ')
FROM docs
WHERE docs MATCH '$ESC_QUERY'
ORDER BY rank
LIMIT 25;
SQL
)"

if [[ -z "$RESULTS" ]]; then
  exit 0
fi

# Format: path:line  [tags]  snippet
# Line number is the line of the first matching token in the source
# file when locatable; otherwise 1. We grep the body once per hit —
# bounded to LIMIT 25 above, so this is acceptable.
while IFS='|' read -r path tags snippet; do
  [[ -z "$path" ]] && continue
  abs="$REPO_ROOT/$path"
  line=1
  if [[ -f "$abs" ]]; then
    # Pick the first body line containing any non-trivial query word.
    # Token extraction is intentionally loose: split on non-word
    # characters, skip FTS5 operators / pure numbers.
    first_word="$(printf '%s' "$QUERY" | tr -c 'A-Za-z0-9_' '\n' \
      | awk 'length($0) >= 3 && $0 !~ /^(AND|OR|NOT|NEAR)$/' | head -n1)"
    if [[ -n "$first_word" ]]; then
      hit="$(grep -n -i -m1 -F -- "$first_word" "$abs" 2>/dev/null || true)"
      if [[ -n "$hit" ]]; then
        line="${hit%%:*}"
      fi
    fi
  fi
  if [[ "$tags" == "-" ]]; then
    tag_field="[]"
  else
    # Render space-separated tags as `[a, b, c]`.
    tag_field="[$(echo "$tags" | sed 's/ /, /g')]"
  fi
  printf '%s:%s  %s  %s\n' "$path" "$line" "$tag_field" "$snippet"
done <<<"$RESULTS"

exit 0
