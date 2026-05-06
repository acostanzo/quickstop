#!/usr/bin/env bash
# Shared helpers for lintguini deterministic scorers and the
# toolkit's bin/ surface (configure, lint, format, fix — added by
# the lintguini-expansion plan).
#
# Scorers convert shell-measurable signals from a target repo
# (<REPO_ROOT>) into one-line v2 wire-contract observation entries.
# They never invoke language toolchains, never reach the network,
# and never mutate the consumer's filesystem — ADR-006 §2 / §3
# invariants apply at the scorer level.
#
# Pure shell + grep + awk + jq. Same filesystem state produces the
# same JSON bytes every run.
#
# Sourcing convention: this file enables `set -euo pipefail` because
# the scorers that use it are strict-by-design — any unhandled error
# should abort the audit rather than silently degrade. Sourcing
# inherits the option set of the file being sourced, so bin scripts
# that source this file with different error semantics (e.g. a
# future `lintguini-fix.sh`, which is intentionally fail-soft across
# many auto-fix branches) must `set +e` (or whatever option set fits)
# immediately after sourcing to restore their own posture. The
# consumer is responsible for re-establishing its own error handling.

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
#   Print one of: python | rust | go | ruby | typescript | javascript | none
#   Precedence: pyproject.toml / setup.py > Cargo.toml > go.mod >
#   Gemfile / *.gemspec / .rubocop.yml > tsconfig.json > package.json.
#   Ruby is placed before tsconfig.json so a Ruby app with a small
#   JS asset pipeline (Rails + Vite, etc.) doesn't misclassify as
#   typescript or javascript. The first match wins; polyglot repos
#   report against the highest-precedence language only.
detect_primary_language() {
  local root="$1"
  if [[ -f "$root/pyproject.toml" || -f "$root/setup.py" ]]; then
    echo "python"
  elif [[ -f "$root/Cargo.toml" ]]; then
    echo "rust"
  elif [[ -f "$root/go.mod" ]]; then
    echo "go"
  elif [[ -f "$root/Gemfile" ]] || compgen -G "$root/*.gemspec" >/dev/null 2>&1 || [[ -f "$root/.rubocop.yml" ]]; then
    echo "ruby"
  elif [[ -f "$root/tsconfig.json" ]]; then
    echo "typescript"
  elif [[ -f "$root/package.json" ]]; then
    echo "javascript"
  else
    echo "none"
  fi
}

# detect_languages <REPO_ROOT>
#   Print every language with a config-file marker present in the
#   repo, one per line, in stable rubric order:
#     python rust go ruby typescript javascript
#   Empty stdout if none are detected.
#
#   Polyglot-friendly counterpart to detect_primary_language. The
#   M2 /lintguini:configure skill consumes this to scope per-language
#   template application; the existing scorers stay on the
#   primary-language path so their byte-equivalent output is preserved.
#
#   typescript and javascript are both reported when both markers
#   exist (tsconfig.json plus package.json) — a TS repo that also has
#   a package.json is genuinely polyglot from a tooling perspective.
detect_languages() {
  local root="$1"
  [[ -f "$root/pyproject.toml" || -f "$root/setup.py" ]] && echo "python"
  [[ -f "$root/Cargo.toml" ]] && echo "rust"
  [[ -f "$root/go.mod" ]] && echo "go"
  if [[ -f "$root/Gemfile" ]] || compgen -G "$root/*.gemspec" >/dev/null 2>&1 || [[ -f "$root/.rubocop.yml" ]] || [[ -f "$root/standard.yml" ]]; then
    echo "ruby"
  fi
  [[ -f "$root/tsconfig.json" ]] && echo "typescript"
  [[ -f "$root/package.json" && ! -f "$root/tsconfig.json" ]] && echo "javascript"
  return 0
}
