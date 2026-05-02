#!/usr/bin/env bash
# build-fixture.sh — materialise an inkwell calibration fixture as a
# real git repository at <output-dir>.
#
# The static blueprint files under tests/fixtures/<slug>/ are
# committed to the parent repo; this script copies them into
# <output-dir> and synthesises git history with controlled commit
# timestamps. The timestamp plan is hard-coded per slug (low/mid/high)
# below — score-doc-staleness.sh reads `git log --format=%ct` for
# every source and docs file, so the fixture's stale_files count is
# fully determined by these timestamps.
#
# Why this script exists rather than committing fixture .git/ trees:
# nesting a git repo inside the parent quickstop repo would either
# tangle the parent's index (forcing submodule semantics) or pollute
# `git status` output. A blueprint + at-test-time-build keeps the
# blueprint files visible in normal diff/grep workflows while the
# git-history fixture lives only in $TMPDIR for the duration of the
# snapshots test.
#
# Usage:
#   build-fixture.sh <slug> <output-dir>
#
# <slug>       one of: low | mid | high
# <output-dir> path to materialise the fixture at; created if absent
#
# Exit 0 on success. Exit 2 on argument or environment errors.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") <slug> <output-dir>" >&2
  exit 2
fi
SLUG="$1"
OUT="$2"

case "$SLUG" in
  low|mid|high) ;;
  *)
    echo "Error: unknown slug '$SLUG' (expected: low | mid | high)" >&2
    exit 2
    ;;
esac

BLUEPRINT="$HERE/$SLUG"
if [[ ! -d "$BLUEPRINT" ]]; then
  echo "Error: blueprint dir '$BLUEPRINT' missing" >&2
  exit 2
fi
if ! command -v git >/dev/null 2>&1; then
  echo "Error: git required" >&2
  exit 2
fi

mkdir -p "$OUT"

# Copy the blueprint into <output-dir>. Skip envelope.json (the
# locked output, not part of the consumer-side fixture) and any
# infrastructure files. -a preserves directory shape; the rsync-style
# trailing slash on $BLUEPRINT/ copies contents not the dir itself.
shopt -s dotglob
for entry in "$BLUEPRINT"/*; do
  base="$(basename "$entry")"
  case "$base" in
    envelope.json) continue ;;
    *) cp -a "$entry" "$OUT/" ;;
  esac
done
shopt -u dotglob

# Initialise the temp repo with a deterministic identity. The committer
# email/name affect commit hashes; pinning them keeps `git log` output
# byte-equivalent across machines.
git -C "$OUT" init -q
git -C "$OUT" config user.email "fixture@inkwell.test"
git -C "$OUT" config user.name "Fixture Author"
git -C "$OUT" config commit.gpgsign false

# Stage and commit a batch at a controlled timestamp.
#   commit_batch <iso-date> <message> <file1> [<file2> ...]
commit_batch() {
  local iso="$1" msg="$2"
  shift 2
  git -C "$OUT" add -- "$@"
  GIT_AUTHOR_DATE="$iso" GIT_COMMITTER_DATE="$iso" \
    git -C "$OUT" commit -q -m "$msg"
}

# Per-slug commit plan. The plan determines the stale_files count
# directly: docs commit at T0; src files committed > 90 days after T0
# are stale. score-doc-staleness.sh picks the LATEST docs commit time
# as the docs-mtime baseline.
case "$SLUG" in
  low)
    # Docs at 2024-01-01. Then 12 fresh src (within 90d of docs) and
    # 18 stale src (well past 90d). Targets stale_files=18.
    commit_batch "2024-01-01T00:00:00Z" "docs: initial readme + notes" \
      README.md docs/notes.md
    fresh=()
    for i in $(seq -f "%02g" 1 12); do fresh+=("src/mod_$i.py"); done
    commit_batch "2024-02-01T00:00:00Z" "src: fresh batch (12 files)" \
      "${fresh[@]}"
    stale=()
    for i in $(seq -f "%02g" 13 30); do stale+=("src/mod_$i.py"); done
    commit_batch "2024-08-01T00:00:00Z" "src: stale batch (18 files, +200d after docs)" \
      "${stale[@]}"
    ;;
  mid)
    # Docs at 2024-12-01. 19 fresh src (within 90d) + 6 stale src
    # (>90d). Targets stale_files=6.
    commit_batch "2024-12-01T00:00:00Z" "docs: initial docs tree + readme" \
      README.md docs/overview.md docs/tutorial.md docs/api.md \
      docs/migration.md docs/contributing.md
    fresh=()
    for i in $(seq -f "%02g" 1 19); do fresh+=("src/mod_$i.py"); done
    commit_batch "2024-12-31T00:00:00Z" "src: fresh batch (19 files)" \
      "${fresh[@]}"
    stale=()
    for i in $(seq -f "%02g" 20 25); do stale+=("src/mod_$i.py"); done
    commit_batch "2025-06-19T00:00:00Z" "src: stale batch (6 files, +200d after docs)" \
      "${stale[@]}"
    ;;
  high)
    # Docs at 2026-01-01. All 20 src committed +30d (within 90d).
    # Targets stale_files=0.
    commit_batch "2026-01-01T00:00:00Z" "docs: initial readme + full docs tree" \
      README.md docs/overview.md docs/tutorial.md docs/api.md \
      docs/usage.md docs/changelog.md docs/contributing.md \
      docs/architecture.md docs/faq.md
    src_files=()
    for i in $(seq -f "%02g" 1 20); do src_files+=("src/mod_$i.py"); done
    commit_batch "2026-01-31T00:00:00Z" "src: all source committed (20 files, +30d after docs)" \
      "${src_files[@]}"
    ;;
esac
