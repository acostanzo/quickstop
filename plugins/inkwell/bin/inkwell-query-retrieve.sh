#!/usr/bin/env bash
# inkwell-query-retrieve.sh — retrieve top-N FTS5 hits, resolve each
# hit to its enclosing heading anchor, extract the section body, and
# render the locked /inkwell:query response contract (Sources block +
# Corroboration stub).
#
# This script is the deterministic half of `/inkwell:query`. The LLM
# half is the skill body: it reads the chunks block above the
# `---END-OF-CHUNKS---` sentinel, synthesises a one-paragraph Answer
# from those chunks, then concatenates the Sources block and the
# Corroboration stub below it verbatim.
#
# The contract surface — field names, ordering, citation format —
# is locked at M3 so M5's corroboration dispatcher can fill in the
# `Corroboration:` line without reshaping anything else. See
# project/adrs/007-inkwell-corroboration-architecture.md.
#
# Output shape (stdout) on success:
#
#   ## Retrieved chunks
#
#   ### docs/auth/session.md#sessions
#
#   <section body — heading line through the next heading of equal
#    or higher rank, capped at 60 lines>
#
#   ### docs/concepts/auth.md#authentication
#
#   <section body>
#
#   ---END-OF-CHUNKS---
#
#   **Sources:**
#   - [docs/auth/session.md#sessions](docs/auth/session.md#sessions) — <one-line snippet>
#   - [docs/concepts/auth.md#authentication](docs/concepts/auth.md#authentication) — <one-line snippet>
#
#   **Corroboration:** `not yet implemented` (see ADR-007; M5 wires this)
#
# Empty-scope contract: if the underlying search yields no hits
# (empty docs/, no matches, or every hit failed anchor resolution),
# emit a single `*No matching documentation found.*` line on stdout
# and exit 0. The skill body returns this as-is.
#
# Usage:
#   inkwell-query-retrieve.sh <question> [REPO_ROOT] [TOP_N]
#
# Exit 0 on success. Exit 2 on argument errors. Exit 3 propagated
# from inkwell-search.sh if `sqlite3` is missing.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <question> [REPO_ROOT] [TOP_N]" >&2
  exit 2
fi

QUESTION="$1"
REPO_ROOT="${2:-$(pwd)}"
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
TOP_N="${3:-5}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEARCHER="$HERE/inkwell-search.sh"

if [[ ! -x "$SEARCHER" ]]; then
  echo "inkwell-query-retrieve.sh: $SEARCHER not executable" >&2
  exit 2
fi

# emit_no_match — the empty-scope / no-resolvable-hit response. Single
# line on stdout so the skill body can return it verbatim.
emit_no_match() {
  printf '%s\n' '*No matching documentation found.*'
}

# slugify <text> — GitHub-style heading anchor. Lowercase; replace
# any non-alphanumeric run with '-'; collapse repeated '-'; strip
# leading/trailing '-'. Matches the slug rule the doc skill uses
# for filename derivation, so anchors and filenames stay consistent.
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}

# resolve_anchor <file> <line> — find the nearest heading at or before
# <line> (any rank). If nothing precedes the line (typical when the
# search hit falls in YAML frontmatter), fall back to the first
# heading anywhere in the file — usually the doc's H1, which is a
# sensible "whole-doc" anchor for a frontmatter match.
# Print "<heading_line>\t<rank>\t<text>" or empty stdout if the file
# has no headings at all.
resolve_anchor() {
  local file="$1" line="$2"
  awk -v target="$line" '
    function record(rank, text, line_no) {
      hits[++n] = line_no SUBSEP rank SUBSEP text
      if (line_no <= target) { last_at_or_before = n }
    }
    /^#+[[:space:]]/ {
      hashes = $0
      sub(/[[:space:]].*$/, "", hashes)
      r = length(hashes)
      t = $0
      sub(/^#+[[:space:]]+/, "", t)
      sub(/[[:space:]]+#+[[:space:]]*$/, "", t)
      record(r, t, NR)
    }
    END {
      pick = (last_at_or_before > 0) ? last_at_or_before : (n > 0 ? 1 : 0)
      if (pick > 0) {
        split(hits[pick], parts, SUBSEP)
        printf "%d\t%d\t%s\n", parts[1], parts[2], parts[3]
      }
    }
  ' "$file"
}

# extract_section <file> <heading_line> <heading_rank> — print the
# heading line through the line immediately before the next heading
# of equal or higher rank (i.e. fewer-or-equal '#' chars), or end of
# file. Output is bounded to 60 lines so the chunks block stays
# polite to the LLM's context window.
extract_section() {
  local file="$1" hline="$2" hrank="$3"
  awk -v hline="$hline" -v hrank="$hrank" '
    NR < hline { next }
    NR == hline { in_section = 1; print; next }
    in_section {
      if (/^#+[[:space:]]/) {
        hashes = $0
        sub(/[[:space:]].*$/, "", hashes)
        if (length(hashes) <= hrank) { exit }
      }
      print
    }
  ' "$file" | head -n 60
}

# Run the FTS5 search. inkwell-search.sh handles its own empty-docs
# branch (exits 0, empty stdout, message on stderr). Empty stdout
# here means "no hits" regardless of cause.
RAW="$("$SEARCHER" "$QUESTION" "$REPO_ROOT" 2>/dev/null || true)"
if [[ -z "$RAW" ]]; then
  emit_no_match
  exit 0
fi

TOP="$(printf '%s\n' "$RAW" | head -n "$TOP_N")"

chunks_block=""
sources_block=""

while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  # Search line shape: `path:line  [tags]  snippet`. Double-space
  # delimits the three columns.
  if [[ "$hit" =~ ^([^:]+):([0-9]+)[[:space:]][[:space:]](\[[^]]*\])[[:space:]][[:space:]](.*)$ ]]; then
    path="${BASH_REMATCH[1]}"
    line="${BASH_REMATCH[2]}"
    snippet="${BASH_REMATCH[4]}"
  else
    continue
  fi

  abs="$REPO_ROOT/$path"
  [[ ! -f "$abs" ]] && continue

  anchor_record="$(resolve_anchor "$abs" "$line")"
  [[ -z "$anchor_record" ]] && continue

  hline="${anchor_record%%$'\t'*}"
  rest="${anchor_record#*$'\t'}"
  hrank="${rest%%$'\t'*}"
  htext="${rest#*$'\t'}"
  slug="$(slugify "$htext")"
  [[ -z "$slug" ]] && continue

  citation="$path#$slug"
  section_body="$(extract_section "$abs" "$hline" "$hrank")"

  chunks_block+="### $citation"$'\n\n'
  chunks_block+="$section_body"$'\n\n'

  # One-line snippet for the Sources block: collapse whitespace,
  # truncate to ~120 chars so the line stays readable.
  one_line="$(printf '%s' "$snippet" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')"
  one_line="${one_line# }"
  one_line="${one_line% }"
  if (( ${#one_line} > 120 )); then
    one_line="${one_line:0:120}…"
  fi
  sources_block+="- [$citation]($citation) — $one_line"$'\n'
done <<<"$TOP"

if [[ -z "$sources_block" ]]; then
  # All hits filtered (missing files, no resolvable headings, etc.).
  emit_no_match
  exit 0
fi

printf '## Retrieved chunks\n\n'
printf '%s' "$chunks_block"
printf -- '---END-OF-CHUNKS---\n\n'
printf '**Sources:**\n'
printf '%s' "$sources_block"
printf '\n**Corroboration:** `not yet implemented` (see ADR-007; M5 wires this)\n'
