#!/usr/bin/env bash
# Materialize the "noisy" commventional fixture: a temp git repo with
#   - 4/14 conventional commits (ratio ~0.286 → conventional-commit-ratio
#     band else→<harshest>)
#   - 7 commits carrying automated Co-Authored-By trailers (auto-trailer-
#     count ≥6 → harshest band)
#   - 3 commits carrying "Generated with Claude Code" markers (auto-
#     attribution-marker-count ≥3 → harshest band)
#
# Usage: build-noisy.sh <output-dir>
set -euo pipefail

DIR="${1:?Usage: $0 <output-dir>}"
rm -rf "$DIR"
mkdir -p "$DIR"
cd "$DIR"
git init -q -b main
git config user.email "anthony@acostanzo.com"
git config user.name  "Anthony"

mk_commit() {
  local idx="$1" subject="$2" body="$3"
  echo "line $idx" > "f$idx.txt"
  git add "f$idx.txt"
  if [[ -n "$body" ]]; then
    GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" \
    GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" \
      git commit -q -m "$subject" -m "$body"
  else
    GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" \
    GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" \
      git commit -q -m "$subject"
  fi
}

# 4 conventional, 6 non-conventional → ratio 4/14 = 0.286
mk_commit 0  "feat: ok"          ""
mk_commit 1  "fix: ok"           ""
mk_commit 2  "wip lol"           ""
mk_commit 3  "stuff"             ""
mk_commit 4  "more changes"      ""
mk_commit 5  "trying things"     ""

# 7 commits with auto Co-Authored-By trailers (cap deduction at 60 → cc=40)
mk_commit 6  "feat: with auto trailer" "Co-Authored-By: Claude <noreply@anthropic.com>"
mk_commit 7  "fix: with trailer"       "Co-Authored-By: Claude <noreply@anthropic.com>"
mk_commit 8  "more updates"            "Co-Authored-By: Claude <noreply@anthropic.com>"
mk_commit 9  "another"                 "Co-Authored-By: AI Bot <bot@example.com>"
mk_commit 10 "again"                   "Co-Authored-By: claude <x@y>"
mk_commit 11 "yep"                     "Co-Authored-By: Claude <z@w>"

# 1 commit with both an auto trailer and a Generated-with-Claude marker
mk_commit 12 "stuff2" "Co-Authored-By: Claude <a@b>

Generated with Claude Code"

# 2 more commits with Generated-with-Claude markers (markers total = 3)
mk_commit 13 "stuff3" "Generated with Claude Code"
mk_commit 14 "stuff4" "Generated with Claude Code"
