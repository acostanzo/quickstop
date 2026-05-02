#!/usr/bin/env bash
# doc-staleness.test.sh — exercise score-doc-staleness.sh against
# git-init fixtures built at test-time with controlled commit
# timestamps. Filesystem mtimes are not used — git log is the
# determinism pin — so the test is reproducible across machines.
#
# Test cases:
#   stale     src committed >90 days after docs    -> stale_files == 1
#   fresh     src committed <90 days after docs    -> stale_files == 0
#   no-src    docs committed but no source files   -> empty-scope omit
#   no-docs   src committed but no docs touched    -> empty-scope omit
#   non-git   plain directory, no .git             -> empty-scope omit

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCORER="$HERE/../score-doc-staleness.sh"
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL [$label]: expected '$expected', got '$actual'" >&2
    fail=1
  fi
}

# Build a single-file commit at a controlled timestamp.
#   make_commit <repo> <iso_date> <message>
make_commit() {
  local repo="$1" iso="$2" msg="$3"
  GIT_AUTHOR_DATE="$iso" GIT_COMMITTER_DATE="$iso" \
    git -C "$repo" commit -q --allow-empty -m "$msg"
}

# Stage a file relative to the repo, then commit at the given timestamp.
#   commit_file <repo> <rel-path> <content> <iso_date> <message>
commit_file() {
  local repo="$1" path="$2" content="$3" iso="$4" msg="$5"
  mkdir -p "$repo/$(dirname "$path")"
  printf '%s\n' "$content" > "$repo/$path"
  git -C "$repo" add -- "$path"
  GIT_AUTHOR_DATE="$iso" GIT_COMMITTER_DATE="$iso" \
    git -C "$repo" commit -q -m "$msg"
}

# Initialise a fresh git repo for one fixture; configure deterministic
# committer identity so commit hashes/dates are reproducible across
# machines.
init_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email "fixture@inkwell.test"
  git -C "$repo" config user.name "Fixture Author"
}

triple_run() {
  local fixture="$1"
  local r1 r2 r3
  r1=$("$SCORER" "$fixture")
  r2=$("$SCORER" "$fixture")
  r3=$("$SCORER" "$fixture")
  if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
    echo "FAIL [$(basename "$fixture")]: triple-run output diverged" >&2
    fail=1
  fi
  printf '%s' "$r1"
}

WORKDIR="$(mktemp -d -t inkwell-doc-staleness-test.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

# ---- stale: docs at T0, src at T0+200d  ->  stale_files=1
STALE_REPO="$WORKDIR/stale"
init_repo "$STALE_REPO"
commit_file "$STALE_REPO" "README.md"   "# fixture-stale" "2026-01-01T00:00:00Z" "docs: initial readme"
commit_file "$STALE_REPO" "docs/api.md" "# api"          "2026-01-01T00:00:00Z" "docs: initial api"
commit_file "$STALE_REPO" "src/main.py" "print(1)"        "2026-07-19T00:00:00Z" "src: late update"

out=$(triple_run "$STALE_REPO")
assert_eq "stale id"             "docs-staleness-count" "$(echo "$out" | jq -r .id)"
assert_eq "stale kind"           "count"                "$(echo "$out" | jq -r .kind)"
assert_eq "stale stale_files"    "1"                    "$(echo "$out" | jq -r .evidence.stale_files)"
assert_eq "stale threshold_days" "90"                   "$(echo "$out" | jq -r .evidence.threshold_days)"
assert_eq "stale total"          "1"                    "$(echo "$out" | jq -r .evidence.total_source_files)"

# ---- fresh: docs at T0, src at T0+30d  ->  stale_files=0
FRESH_REPO="$WORKDIR/fresh"
init_repo "$FRESH_REPO"
commit_file "$FRESH_REPO" "README.md"   "# fixture-fresh" "2026-01-01T00:00:00Z" "docs: initial readme"
commit_file "$FRESH_REPO" "docs/api.md" "# api"          "2026-01-01T00:00:00Z" "docs: initial api"
commit_file "$FRESH_REPO" "src/main.py" "print(1)"        "2026-01-30T00:00:00Z" "src: minor update"

out=$(triple_run "$FRESH_REPO")
assert_eq "fresh stale_files" "0" "$(echo "$out" | jq -r .evidence.stale_files)"
assert_eq "fresh total"       "1" "$(echo "$out" | jq -r .evidence.total_source_files)"

# ---- no-src: docs only  ->  empty-scope omit
NO_SRC_REPO="$WORKDIR/no-src"
init_repo "$NO_SRC_REPO"
commit_file "$NO_SRC_REPO" "README.md" "# fixture-no-src" "2026-01-01T00:00:00Z" "docs: initial readme"
out=$(triple_run "$NO_SRC_REPO")
assert_eq "no-src no output" "" "$out"

# ---- no-docs: src only, no README, no docs/  ->  empty-scope omit
NO_DOCS_REPO="$WORKDIR/no-docs"
init_repo "$NO_DOCS_REPO"
commit_file "$NO_DOCS_REPO" "src/main.py" "print(1)" "2026-01-01T00:00:00Z" "src: initial"
out=$(triple_run "$NO_DOCS_REPO")
assert_eq "no-docs no output" "" "$out"

# ---- non-git: plain directory  ->  empty-scope omit
NON_GIT_REPO="$WORKDIR/non-git"
mkdir -p "$NON_GIT_REPO"
echo "# plain" > "$NON_GIT_REPO/README.md"
out=$(triple_run "$NON_GIT_REPO")
assert_eq "non-git no output" "" "$out"

if (( fail == 0 )); then
  echo "doc-staleness.test.sh: PASS"
  exit 0
else
  echo "doc-staleness.test.sh: FAIL" >&2
  exit 1
fi
