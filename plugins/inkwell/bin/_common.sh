#!/usr/bin/env bash
# Shared helpers for inkwell bin scripts.
#
# Currently used by inkwell-tidy.sh for the duplicate-density check.
# Frontmatter parsing and shingle-Jaccard math live here; tidy
# sources this file and runs with its own error-handling posture.
#
# These helpers were previously co-located with the now-retired
# pronto-sibling audit scorers. They moved to bin/ when the audit
# surface retired (ADR-009); the math is unchanged.
#
# `set -euo pipefail` is enabled here because every helper below is
# strict-by-design — any unhandled error should abort rather than
# silently degrade. Sourcing inherits the option set of the file
# being sourced, so callers that want softer error semantics (e.g.
# `inkwell-tidy.sh`, which is intentionally fail-soft across many
# branches) must `set +e` (or whatever option set fits) immediately
# after sourcing to restore their own posture.

set -euo pipefail

# ---------------------------------------------------------------------
# Frontmatter helpers.
# ---------------------------------------------------------------------

# inkwell_extract_frontmatter <file>
#   Print the YAML frontmatter body (between the leading `---` and
#   the closing `---`). Empty stdout if no frontmatter block.
inkwell_extract_frontmatter() {
  awk '
    NR==1 && $0=="---" { in_fm=1; next }
    in_fm && $0=="---" { exit }
    in_fm { print }
  ' "$1"
}

# inkwell_extract_body <file>
#   Print the markdown body with frontmatter stripped.
inkwell_extract_body() {
  awk '
    NR==1 && $0=="---" { in_fm=1; next }
    in_fm && $0=="---" { in_fm=0; next }
    in_fm { next }
    { print }
  ' "$1"
}

# inkwell_fm_field <key> <frontmatter-text>
#   Print the value of <key> from a frontmatter block. Strips
#   surrounding single/double quotes. Empty stdout if absent.
inkwell_fm_field() {
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

# ---------------------------------------------------------------------
# Shingle-Jaccard helpers.
#
# bigrams_for_doc <file> <out-file>
#   Emit a sorted-unique list of word bigrams for <file>. Title is
#   pulled from frontmatter; body is everything after the closing
#   `---`. Words are lower-cased, punctuation-split, length-filtered.
#
# jaccard_files <a> <b>
#   Print a 4-decimal-place ratio of the Jaccard overlap between two
#   pre-computed bigram files (sorted-unique input on both sides).
# ---------------------------------------------------------------------

bigrams_for_doc() {
  local file="$1" out="$2" fm title
  fm="$(inkwell_extract_frontmatter "$file")"
  title="$(inkwell_fm_field title "$fm")"
  {
    printf '%s\n' "$title"
    inkwell_extract_body "$file"
  } \
    | tr '[:upper:]' '[:lower:]' \
    | tr -c 'a-z0-9' '\n' \
    | awk 'NF && length($0) >= 2' \
    | awk 'BEGIN { prev = "" } { if (prev != "") print prev " " $0; prev = $0 }' \
    | LC_ALL=C sort -u >"$out"
}

jaccard_files() {
  local a="$1" b="$2" inter union
  inter="$(LC_ALL=C comm -12 "$a" "$b" | wc -l | tr -d ' ')"
  union="$(LC_ALL=C sort -u "$a" "$b" | wc -l | tr -d ' ')"
  if (( union == 0 )); then echo "0.0000"; return; fi
  awk -v n="$inter" -v d="$union" 'BEGIN { printf "%.4f", n/d }'
}
