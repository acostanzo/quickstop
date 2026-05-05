#!/usr/bin/env bash
# inkwell-suggest-links.sh — suggest `## Related` candidates for a
# given doc by tag overlap.
#
# Algorithm (v1): Jaccard similarity over the `tags:` arrays in
# YAML frontmatter. For each other doc under `docs/`, compute
#   J(A, B) = |A ∩ B| / |A ∪ B|
# and emit the top N candidates with J > 0, sorted descending. Ties
# are broken by relative path (alphabetical) for determinism.
#
# Why Jaccard over body-keyword overlap: tags are an explicit author
# signal that two docs are about the same thing. Body overlap drifts
# toward syntactic similarity (boilerplate words shared across all
# how-tos). When a doc has no tags, the suggester emits "no
# automatic suggestion" rather than falling back to noisy
# body-keyword scoring — body-keyword is a v2 expansion if needed.
#
# Output (one line per candidate):
#   <relpath>  score=<0.NN>  rationale: shared tags <a, b>
#
# When no candidates: prints "no automatic suggestion" on stderr,
# empty stdout, exit 0.
#
# Usage:
#   inkwell-suggest-links.sh <doc-path> [REPO_ROOT] [LIMIT]
#
# <doc-path> may be absolute or relative to REPO_ROOT (or to pwd if
# REPO_ROOT is omitted). LIMIT defaults to 5.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <doc-path> [REPO_ROOT] [LIMIT]" >&2
  exit 2
fi

INPUT_PATH="$1"
REPO_ROOT="${2:-$(pwd)}"
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
LIMIT="${3:-5}"

DOCS_DIR="$REPO_ROOT/docs"

# Resolve target absolute path. Accept absolute, repo-relative,
# or docs-relative ("auth/session.md") inputs — writers reach for
# whichever form is at hand.
if [[ -f "$INPUT_PATH" ]]; then
  TARGET_ABS="$(cd "$(dirname "$INPUT_PATH")" && pwd)/$(basename "$INPUT_PATH")"
elif [[ -f "$REPO_ROOT/$INPUT_PATH" ]]; then
  TARGET_ABS="$REPO_ROOT/$INPUT_PATH"
elif [[ -f "$DOCS_DIR/$INPUT_PATH" ]]; then
  TARGET_ABS="$DOCS_DIR/$INPUT_PATH"
else
  echo "inkwell-suggest-links.sh: target file not found: $INPUT_PATH" >&2
  exit 2
fi

if [[ ! -d "$DOCS_DIR" ]]; then
  echo "no automatic suggestion" >&2
  exit 0
fi

# extract_tags <file> — print space-separated lower-case tags from
# the file's YAML frontmatter. Empty if no `tags:` field.
extract_tags() {
  awk '
    NR==1 && $0=="---" { in_fm=1; next }
    in_fm && $0=="---" { exit }
    in_fm && /^tags:[[:space:]]*\[/ {
      sub(/^tags:[[:space:]]*\[/, "")
      sub(/\][[:space:]]*$/, "")
      gsub(/,/, " ")
      gsub(/[[:space:]]+/, " ")
      sub(/^[[:space:]]+/, "")
      sub(/[[:space:]]+$/, "")
      print tolower($0)
      exit
    }
    in_fm && /^tags:[[:space:]]*$/ {
      block_mode = 1
      next
    }
    in_fm && block_mode && /^[[:space:]]+-[[:space:]]+/ {
      sub(/^[[:space:]]+-[[:space:]]+/, "")
      sub(/[[:space:]]+$/, "")
      printf "%s ", tolower($0)
      next
    }
    in_fm && block_mode { exit }
  ' "$1" | sed 's/ $//'
}

TARGET_TAGS_STR="$(extract_tags "$TARGET_ABS")"
if [[ -z "$TARGET_TAGS_STR" ]]; then
  echo "no automatic suggestion" >&2
  exit 0
fi

# Build target tag set (associative array).
declare -A TARGET_TAGS=()
for t in $TARGET_TAGS_STR; do
  TARGET_TAGS["$t"]=1
done

# Collect candidates. For each peer doc:
#   inter = |target ∩ peer|
#   union = |target ∪ peer|
#   J = inter / union
# Print one line per peer with J > 0.
TARGET_REL="${TARGET_ABS#$REPO_ROOT/}"
RAW="$(mktemp)"
trap 'rm -f "$RAW"' EXIT

while IFS= read -r peer; do
  peer_rel="${peer#$REPO_ROOT/}"
  [[ "$peer_rel" == "$TARGET_REL" ]] && continue

  peer_tags_str="$(extract_tags "$peer")"
  [[ -z "$peer_tags_str" ]] && continue

  inter=0
  declare -A peer_set=()
  declare -A union_set=()
  for t in $peer_tags_str; do
    peer_set["$t"]=1
    union_set["$t"]=1
  done
  for t in "${!TARGET_TAGS[@]}"; do
    union_set["$t"]=1
    if [[ -n "${peer_set[$t]:-}" ]]; then
      inter=$((inter + 1))
    fi
  done
  union=${#union_set[@]}
  unset peer_set union_set

  if (( inter == 0 )); then
    continue
  fi

  # Format Jaccard as 4dp via awk (deterministic across locales).
  jaccard="$(awk -v n="$inter" -v d="$union" 'BEGIN { printf "%.4f", n/d }')"

  # Shared-tag list (intersection) for the rationale.
  shared=""
  for t in $peer_tags_str; do
    if [[ -n "${TARGET_TAGS[$t]:-}" ]]; then
      shared+="$t, "
    fi
  done
  shared="${shared%, }"

  printf '%s\t%s\t%s\n' "$jaccard" "$peer_rel" "$shared" >>"$RAW"
done < <(find "$DOCS_DIR" -type f -name '*.md' \
  ! -path "$DOCS_DIR/templates/*" \
  ! -name '_*.md' 2>/dev/null)

if [[ ! -s "$RAW" ]]; then
  echo "no automatic suggestion" >&2
  exit 0
fi

# Sort by score desc, then path asc; emit top LIMIT.
LC_ALL=C sort -t$'\t' -k1,1nr -k2,2 "$RAW" | head -n "$LIMIT" \
  | awk -F'\t' '{ printf "%s  score=%s  rationale: shared tags %s\n", $2, $1, $3 }'
