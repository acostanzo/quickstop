#!/usr/bin/env bash
# inkwell-doc-resolve.sh — resolve an `/inkwell:doc` topic to an
# existing doc under `docs/`, or report no match. Used by the doc
# skill's update-vs-scaffold branch so a topic like "Authentication"
# can find an existing `docs/concepts/auth.md` whose `title:` is
# "Authentication" rather than scaffolding a duplicate at
# `docs/authentication.md`.
#
# Resolution order:
#   1. Slug match. Compute slug(topic) = lower-case, non-alphanum→`-`,
#      collapse, trim. Glob `docs/<slug>.md` and `docs/**/<slug>.md`.
#      If exactly one match, output `match <relpath>`.
#   2. Title match. Scan every `docs/**/*.md` frontmatter for `title:`
#      (case-insensitive equality against the raw topic). If exactly
#      one hit, output `match <relpath>`.
#   3. Multiple title hits → output `ambiguous <relpath1> <relpath2> ...`.
#      The skill surfaces this to the user rather than scaffolding.
#   4. No slug or title match → output `none`.
#
# Why this ordering: a slug match is the strongest signal (it's the
# write-target the skill would otherwise scaffold to), so an existing
# doc at the slug always wins. Title match is the secondary signal
# that picks up the layer-2 smoke case where the topic-as-typed
# differs from the slug a previous author chose.
#
# Output is a single line on stdout, exit 0 always (modulo argument
# errors). The caller branches on the leading word.
#
# Usage:
#   inkwell-doc-resolve.sh <topic> [REPO_ROOT]
#
# Exit 2 on argument errors. Exit 0 otherwise.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <topic> [REPO_ROOT]" >&2
  exit 2
fi

TOPIC="$1"
REPO_ROOT="${2:-$(pwd)}"
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"

DOCS_DIR="$REPO_ROOT/docs"

# slugify <text> — same rule as the doc skill's filename derivation.
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}

if [[ ! -d "$DOCS_DIR" ]]; then
  printf 'none\n'
  exit 0
fi

SLUG="$(slugify "$TOPIC")"

# -------------------------------------------------------------------
# Step 1 — slug match. find under docs/ for any file basename
# matching `<slug>.md`. Sort by depth (shallowest first), then path.
# -------------------------------------------------------------------
slug_matches=()
if [[ -n "$SLUG" ]]; then
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    slug_matches+=("$path")
  done < <(find "$DOCS_DIR" -type f -name "${SLUG}.md" 2>/dev/null \
    | awk -F/ '{ print NF "\t" $0 }' \
    | LC_ALL=C sort -t$'\t' -k1,1n -k2,2 \
    | cut -f2-)
fi

if (( ${#slug_matches[@]} >= 1 )); then
  rel="${slug_matches[0]#$REPO_ROOT/}"
  printf 'match %s\n' "$rel"
  exit 0
fi

# -------------------------------------------------------------------
# Step 2 — title match. Walk every `docs/**/*.md`, read the YAML
# `title:` line, compare case-insensitive against the raw topic.
# -------------------------------------------------------------------
title_matches=()
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  # Extract the title from the frontmatter. awk reads the file's
  # first YAML block and prints the value of `title:` (single line,
  # unquoted or single/double-quoted).
  title="$(awk '
    NR==1 && $0=="---" { in_fm=1; next }
    in_fm && $0=="---" { exit }
    in_fm && /^title:[[:space:]]*/ {
      sub(/^title:[[:space:]]*/, "")
      sub(/^"/, ""); sub(/"$/, "")
      sub(/^'\''/, ""); sub(/'\''$/, "")
      sub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "$path")"
  [[ -z "$title" ]] && continue
  # Case-insensitive equality.
  if [[ "${title,,}" == "${TOPIC,,}" ]]; then
    title_matches+=("$path")
  fi
done < <(find "$DOCS_DIR" -type f -name '*.md' \
  ! -path "$DOCS_DIR/templates/*" \
  ! -name '_*.md' 2>/dev/null \
  | LC_ALL=C sort)

if (( ${#title_matches[@]} == 1 )); then
  rel="${title_matches[0]#$REPO_ROOT/}"
  printf 'match %s\n' "$rel"
  exit 0
fi

if (( ${#title_matches[@]} >= 2 )); then
  printf 'ambiguous'
  for p in "${title_matches[@]}"; do
    rel="${p#$REPO_ROOT/}"
    printf ' %s' "$rel"
  done
  printf '\n'
  exit 0
fi

printf 'none\n'
exit 0
