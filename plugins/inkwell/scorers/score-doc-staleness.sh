#!/usr/bin/env bash
# score-doc-staleness.sh — emit a `docs-staleness-count` observation
# for the code-documentation dimension.
#
# Compares per-source-file last-touch timestamps against the most
# recent docs-touch timestamp; counts source files modified more
# than `threshold_days` after the last docs touch.
#
# Both timestamps come from `git log -1 --format=%ct -- <file>`
# (last commit time touching the file). Using filesystem `stat`
# would introduce variance from clone timestamps; git log is the
# determinism pin.
#
# Source-file scope (per the 2a2 ticket): files under `src/` and
# `lib/` plus top-level files with language extensions
# (.py / .js / .jsx / .ts / .tsx / .go / .rs). Vendored code, test
# fixtures, and generated files outside src/ + lib/ are excluded by
# construction.
#
# Docs-touch scope: `README.md` at repo root + everything under `docs/`.
#
# Empty-scope short-circuit:
#   not a git repo OR no source files tracked OR no docs touched
#   -> omit observation (no stdout) and exit 0.
#
# Threshold: 90 days. The 2a2 ticket flags this as a starting point —
# 2a3 fixture calibration may refine. Threshold value lives in
# evidence so the rubric stanza in 2a3 can read it without re-deriving.
#
# Usage:
#   score-doc-staleness.sh <REPO_ROOT>
#
# Exit 0 on success or any documented short-circuit. Exit 2 on
# argument or environment errors.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "$HERE/_common.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <REPO_ROOT>" >&2
  exit 2
fi
REPO_ROOT="$1"
if [[ ! -d "$REPO_ROOT" ]]; then
  echo "Error: REPO_ROOT '$REPO_ROOT' is not a directory" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq required" >&2
  exit 2
fi
if ! command -v git >/dev/null 2>&1; then
  echo "Error: git required" >&2
  exit 2
fi

# Empty-scope: not a git repo (no history -> can't compute mtimes).
if ! git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

THRESHOLD_DAYS=90
THRESHOLD_SECONDS=$((THRESHOLD_DAYS * 86400))

# ---- docs_mtime: newest commit time across README.md + docs/ ---------
DOCS_MTIME=0

# README.md at repo root.
if [[ -f "$REPO_ROOT/README.md" ]]; then
  ct=$(git -C "$REPO_ROOT" log -1 --format=%ct -- README.md 2>/dev/null || true)
  ct=${ct:-0}
  if [[ -n "$ct" && "$ct" =~ ^[0-9]+$ ]] && (( ct > DOCS_MTIME )); then
    DOCS_MTIME=$ct
  fi
fi

# Files tracked under docs/.
if [[ -d "$REPO_ROOT/docs" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    ct=$(git -C "$REPO_ROOT" log -1 --format=%ct -- "$f" 2>/dev/null || true)
    ct=${ct:-0}
    if [[ -n "$ct" && "$ct" =~ ^[0-9]+$ ]] && (( ct > DOCS_MTIME )); then
      DOCS_MTIME=$ct
    fi
  done < <(git -C "$REPO_ROOT" ls-files docs/ 2>/dev/null | sort)
fi

if (( DOCS_MTIME == 0 )); then
  exit 0  # empty-scope: nothing in docs/ scope has commit history
fi

# ---- source files: src/ + lib/ + top-level language files ------------
SRC_LIST="$(mktemp -t inkwell-doc-staleness.XXXXXX)"
trap 'rm -f "$SRC_LIST"' EXIT

{
  git -C "$REPO_ROOT" ls-files src/ lib/ 2>/dev/null
  git -C "$REPO_ROOT" ls-files 2>/dev/null | grep -vE '/'
} | grep -E '\.(py|js|jsx|ts|tsx|mjs|cjs|go|rs)$' \
  | sort -u > "$SRC_LIST"

TOTAL=$(wc -l < "$SRC_LIST" | tr -d ' ')
TOTAL=${TOTAL:-0}
if (( TOTAL == 0 )); then
  exit 0  # empty-scope: no source files in scope
fi

# ---- compare per-file mtimes against docs_mtime + threshold ----------
STALE=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  ct=$(git -C "$REPO_ROOT" log -1 --format=%ct -- "$f" 2>/dev/null || true)
  ct=${ct:-0}
  if [[ -z "$ct" || ! "$ct" =~ ^[0-9]+$ ]]; then
    continue
  fi
  if (( ct > DOCS_MTIME + THRESHOLD_SECONDS )); then
    STALE=$((STALE + 1))
  fi
done < "$SRC_LIST"

jq -nc \
  --argjson stale_files "$STALE" \
  --argjson threshold_days "$THRESHOLD_DAYS" \
  --argjson total_source_files "$TOTAL" \
  '{
    id: "docs-staleness-count",
    kind: "count",
    evidence: {
      stale_files: $stale_files,
      threshold_days: $threshold_days,
      total_source_files: $total_source_files
    },
    summary: "\($stale_files)/\($total_source_files) source files modified more than \($threshold_days) days after last docs touch"
  }'
