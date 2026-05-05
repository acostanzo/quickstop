#!/usr/bin/env bash
# Shared helpers for inkwell deterministic scorers.
#
# Scorers convert shell-measurable signals from a target repo
# (<REPO_ROOT>) into one-line v2 wire-contract observation entries.
# They never mutate the consumer's filesystem and stay network-free
# — ADR-006 §2 / §3 invariants apply at the scorer level.
#
# External tool dispatch (interrogate, lychee, etc.) is allowed for
# the docs-coverage and link-health scorers per the 2a2 spec; tool
# absence routes a notice to stderr and omits the observation rather
# than failing the audit (invariant B in the 2a2 ticket).
#
# Pure shell + grep + awk + jq plus the per-scorer tools. Same
# filesystem state and same git history → same JSON bytes every run.

set -euo pipefail

# format_ratio <numerator> <denominator>
#   Print a 4-decimal-place ratio. Returns the literal "null" when
#   denominator is 0 (per the 2a2 ticket spec; scorers using this
#   helper should empty-scope-omit rather than emit a null ratio,
#   but the literal is here for completeness).
#   awk's printf is the determinism pin — bash arithmetic loses
#   precision and jq float ingest is locale-sensitive.
format_ratio() {
  awk -v n="$1" -v d="$2" 'BEGIN {
    if (d > 0) printf "%.4f", n/d
    else printf "null"
  }'
}

# detect_language <REPO_ROOT>
#   Print one of: python | js | ts | go | rust | other
#   Precedence (config-file first, then source-file fallback):
#     pyproject.toml / setup.py            -> python
#     tsconfig.json                        -> ts
#     package.json                         -> js
#     go.mod                               -> go
#     Cargo.toml                           -> rust
#     >5 *.py files at top-level or src/   -> python (fallback)
#     -> other
#
#   Mirrors the per-language dispatch table in the 2a2 ticket's
#   `score-docs-coverage.sh` section. The first matching config
#   wins; polyglot repos report against the highest-precedence
#   language only.
detect_language() {
  local root="$1"
  if [[ -f "$root/pyproject.toml" || -f "$root/setup.py" ]]; then
    echo "python"; return
  fi
  if [[ -f "$root/tsconfig.json" ]]; then
    echo "ts"; return
  fi
  if [[ -f "$root/package.json" ]]; then
    echo "js"; return
  fi
  if [[ -f "$root/go.mod" ]]; then
    echo "go"; return
  fi
  if [[ -f "$root/Cargo.toml" ]]; then
    echo "rust"; return
  fi
  # Source-file fallback: count *.py at repo root + src/ (depth 2).
  local py_count
  py_count=$(
    {
      find "$root" -maxdepth 1 -name '*.py' -type f -print 2>/dev/null
      [[ -d "$root/src" ]] && find "$root/src" -maxdepth 2 -name '*.py' -type f -print 2>/dev/null
    } | wc -l | tr -d ' '
  )
  py_count=${py_count:-0}
  if (( py_count > 5 )); then
    echo "python"; return
  fi
  echo "other"
}

# tool_available <command>
#   Return 0 if <command> is on PATH; return 1 with a stderr notice
#   otherwise. Callers that depend on an external tool branch on
#   the return code: present -> dispatch; absent -> omit observation,
#   exit 0 (tool-absent isn't a fatal audit error per 2a2 invariant B).
tool_available() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  echo "Notice: '$cmd' not on PATH; observation omitted" >&2
  return 1
}

# ---------------------------------------------------------------------
# Inkwell-marked-doc helpers.
#
# The three conditional scorers added in T5
# (score-template-compliance.sh, score-backlink-coverage.sh,
# score-duplicate-density.sh) gate on "did inkwell's doc model show
# up in this repo?" — detected by frontmatter on any `docs/**/*.md`
# carrying a `template:` field with a Diátaxis value
# (concept | how-to | reference | tutorial). If markers absent,
# scorers empty-scope (no stdout, exit 0) so the audit behaves
# identically on non-inkwell consumers — A4 in the inkwell-expansion
# plan is the load-bearing assertion this enables.
# ---------------------------------------------------------------------

VALID_INKWELL_TEMPLATES_RE='^(concept|how-to|reference|tutorial)$'

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

# inkwell_list_marked_docs <REPO_ROOT>
#   Print the absolute path of every `docs/**/*.md` whose frontmatter
#   carries a `template:` field with a value matching
#   $VALID_INKWELL_TEMPLATES_RE. Sorted under LC_ALL=C for
#   determinism. Excludes `docs/templates/` and `docs/archive/`
#   (template scaffolding and archived docs are out of scope).
inkwell_list_marked_docs() {
  local root="$1"
  local docs_dir="$root/docs"
  [[ -d "$docs_dir" ]] || return 0
  local f fm tmpl
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    fm="$(inkwell_extract_frontmatter "$f")"
    [[ -z "$fm" ]] && continue
    tmpl="$(inkwell_fm_field template "$fm")"
    [[ -z "$tmpl" ]] && continue
    if [[ "$tmpl" =~ $VALID_INKWELL_TEMPLATES_RE ]]; then
      printf '%s\n' "$f"
    fi
  done < <(find "$docs_dir" -type f -name '*.md' \
             ! -path "$docs_dir/templates/*" \
             ! -path "$docs_dir/archive/*" \
             ! -name '_*.md' 2>/dev/null | LC_ALL=C sort)
}

# inkwell_inkwell_marked <REPO_ROOT>
#   Exit 0 if any `docs/**/*.md` is inkwell-marked, else exit 1.
inkwell_marked_consumer() {
  local root="$1"
  local first
  first="$(inkwell_list_marked_docs "$root" | head -n 1)"
  [[ -n "$first" ]]
}

# ---------------------------------------------------------------------
# Shingle-Jaccard helpers (also used by inkwell-tidy.sh).
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
