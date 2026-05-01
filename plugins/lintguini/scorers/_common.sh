#!/usr/bin/env bash
# Shared helpers for lintguini deterministic scorers.
#
# Scorers convert shell-measurable signals from a target repo
# (<REPO_ROOT>) into one-line v2 wire-contract observation entries.
# They never invoke language toolchains, never reach the network,
# and never mutate the consumer's filesystem — ADR-006 §2 / §3
# invariants apply at the scorer level.
#
# Pure shell + grep + awk + jq. Same filesystem state produces the
# same JSON bytes every run.

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
#   Print one of: python | typescript | javascript | rust | go | none
#   Precedence: pyproject.toml / setup.py > Cargo.toml > go.mod >
#   tsconfig.json > package.json. The first match wins; polyglot
#   repos report against the highest-precedence language only.
detect_primary_language() {
  local root="$1"
  if [[ -f "$root/pyproject.toml" || -f "$root/setup.py" ]]; then
    echo "python"
  elif [[ -f "$root/Cargo.toml" ]]; then
    echo "rust"
  elif [[ -f "$root/go.mod" ]]; then
    echo "go"
  elif [[ -f "$root/tsconfig.json" ]]; then
    echo "typescript"
  elif [[ -f "$root/package.json" ]]; then
    echo "javascript"
  else
    echo "none"
  fi
}
