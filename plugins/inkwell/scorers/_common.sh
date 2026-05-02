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
