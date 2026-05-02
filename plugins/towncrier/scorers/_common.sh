#!/usr/bin/env bash
# Shared helpers for towncrier deterministic scorers.
#
# Scorers convert shell-measurable signals from a target repo
# (<REPO_ROOT>) into one-line v2 wire-contract observation entries
# for the event-emission audit dimension. They never invoke language
# toolchains, never reach the network, and never mutate the consumer's
# filesystem — ADR-006 §2 / §3 invariants apply at the scorer level.
#
# Pure shell + grep + awk + jq. Same filesystem state produces the
# same JSON bytes every run.
#
# Per the 2c2 ticket, the first-class language set is python > go >
# rust > typescript > javascript (no ruby — towncrier's depth signals
# for ruby are less convention-dense than lintguini's; the slot is
# freed for follow-up if a fixture-led need surfaces).

set -euo pipefail

# format_ratio <numerator> <denominator>
#   Print a 4-decimal-place ratio. Returns "0.0000" if denominator is 0.
#   awk's printf is the determinism pin — bash arithmetic loses precision
#   and jq float ingest is locale-sensitive.
format_ratio() {
  awk -v n="$1" -v d="$2" 'BEGIN { if (d > 0) printf "%.4f", n/d; else printf "0.0000" }'
}

# clamp_ratio <ratio>
#   Clamp a 4dp ratio to [0.0, 1.0]. Used when configured-rule counts
#   exceed baseline (over-strictness gets pinned to 1.0; under doesn't
#   undershoot 0).
clamp_ratio() {
  awk -v r="$1" 'BEGIN {
    if (r > 1) r = 1
    else if (r < 0) r = 0
    printf "%.4f", r
  }'
}

# detect_primary_language <REPO_ROOT>
#   Print one of: python | go | rust | typescript | javascript | none
#   Precedence (config-file first, then python source-file fallback):
#     pyproject.toml / setup.py            -> python
#     go.mod                               -> go
#     Cargo.toml                           -> rust
#     tsconfig.json                        -> typescript
#     package.json                         -> javascript
#     >5 *.py files at top-level or src/   -> python (fallback)
#     -> none
#
#   Mirrors the per-language dispatch table in the 2c2 ticket. The
#   first matching config wins; polyglot repos report against the
#   highest-precedence language only.
detect_primary_language() {
  local root="$1"
  if [[ -f "$root/pyproject.toml" || -f "$root/setup.py" ]]; then
    echo "python"; return
  fi
  if [[ -f "$root/go.mod" ]]; then
    echo "go"; return
  fi
  if [[ -f "$root/Cargo.toml" ]]; then
    echo "rust"; return
  fi
  if [[ -f "$root/tsconfig.json" ]]; then
    echo "typescript"; return
  fi
  if [[ -f "$root/package.json" ]]; then
    echo "javascript"; return
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
  echo "none"
}

# language_source_files <REPO_ROOT> <language>
#   Print one source-file path per line, sorted, scoped to the
#   given language and filtered against the standard exclude set
#   (node_modules, dist, build, .venv, venv, __pycache__, target,
#   vendor). Mirrors the lintguini score-suppression-count.sh exclude
#   set so the two plugins agree on what counts as "source" vs
#   "vendored / generated".
#
#   Empty output (no files) is a valid empty-scope signal — callers
#   short-circuit on the resulting count.
language_source_files() {
  local root="$1" lang="$2"
  local -a find_args
  case "$lang" in
    python)
      find_args=(-type f -name '*.py'
                 -not -path '*/.venv/*' -not -path '*/venv/*' -not -path '*/__pycache__/*')
      ;;
    typescript)
      find_args=(-type f \(
                 -name '*.ts' -o -name '*.tsx'
                 \)
                 -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/build/*')
      ;;
    javascript)
      find_args=(-type f \(
                 -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs'
                 \)
                 -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/build/*')
      ;;
    go)
      find_args=(-type f -name '*.go' -not -path '*/vendor/*')
      ;;
    rust)
      find_args=(-type f -name '*.rs' -not -path '*/target/*')
      ;;
    *)
      return 0
      ;;
  esac
  find "$root" "${find_args[@]}" -print 2>/dev/null | sort
}

# count_pattern_hits <regex> <files-list-path>
#   Sum grep -E -c matches across all files listed in <files-list-path>
#   (one path per line). `grep -c` exits 1 on zero matches per file;
#   `|| true` keeps the pipeline alive. Prints the integer total.
count_pattern_hits() {
  local re="$1" files="$2"
  local total=0 c
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    c=$(grep -cE "$re" "$f" 2>/dev/null || true)
    c=${c:-0}
    total=$((total + c))
  done < "$files"
  printf '%d' "$total"
}
