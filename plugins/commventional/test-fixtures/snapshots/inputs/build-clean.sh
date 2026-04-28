#!/usr/bin/env bash
# Materialize the "clean" commventional fixture: a temp git repo with
# 10 conventional-commit subjects, no automated trailers, no Generated-
# with-Claude-Code markers. Used by snapshots.test.sh and by manual
# regression runs.
#
# Usage: build-clean.sh <output-dir>
set -euo pipefail

DIR="${1:?Usage: $0 <output-dir>}"
rm -rf "$DIR"
mkdir -p "$DIR"
cd "$DIR"
git init -q -b main
git config user.email "anthony@acostanzo.com"
git config user.name  "Anthony"

msgs=(
  "feat: add config loader"
  "fix: handle empty input"
  "docs: clarify install steps"
  "refactor: split module"
  "test: cover edge case"
  "chore: bump deps"
  "perf: cache lookups"
  "build: switch to bun"
  "ci: pin actions"
  "style: prettier sweep"
)

for i in "${!msgs[@]}"; do
  echo "line $i" > "f$i.txt"
  git add "f$i.txt"
  GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" \
  GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" \
    git commit -q -m "${msgs[$i]}"
done
