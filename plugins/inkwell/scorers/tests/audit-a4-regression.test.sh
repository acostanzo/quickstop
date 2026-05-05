#!/usr/bin/env bash
# audit-a4-regression.test.sh — A4 regression test from the
# inkwell-expansion plan. The load-bearing assertion: T5 must not
# regress non-inkwell consumers.
#
# Plan: run `bin/build-envelope.sh` against an inkwell-marked
# fixture AND against a derived "plain" copy of the same fixture
# with the inkwell frontmatter stripped from every `docs/**/*.md`
# (everything else — README, source layout, docs body content —
# is identical between the two). Diff the four pre-T5 scorers'
# contributions across the two envelopes:
#
#   - readme-arrival-coverage
#   - docs-coverage-ratio
#   - docs-staleness-count
#   - broken-internal-links-count
#
# These must be byte-equivalent across both runs, because the
# only delta between the two fixtures is the inkwell frontmatter
# the existing scorers are blind to. The new T5 conditional
# scorers (inkwell-template-compliance, inkwell-backlink-coverage,
# inkwell-duplicate-density) appear ONLY on the marked side and
# are absent on the plain side.
#
# Deriving the plain fixture from the marked one at test time —
# rather than maintaining two parallel blueprints — is what keeps
# the byte-equivalence assertion honest: there is no opportunity
# for fixture drift to mask a regression.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
ENVELOPE="$PLUGIN_ROOT/bin/build-envelope.sh"
MARKED_BLUEPRINT="$HERE/fixtures/inkwell-marked"
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL [$label]: expected '$expected', got '$actual'" >&2
    fail=1
  fi
}

# Pre-T5 ("legacy") observation IDs. These must contribute the same
# shape across both fixtures — either both empty-scope, or both
# populated with byte-equivalent observations (per-fixture content
# differs, but their *presence/absence* must align).
LEGACY_IDS=(
  "readme-arrival-coverage"
  "docs-coverage-ratio"
  "docs-staleness-count"
  "broken-internal-links-count"
)

# T5 conditional observation IDs. These must appear only on the
# inkwell-marked side and be absent on the plain side.
CONDITIONAL_IDS=(
  "inkwell-template-compliance"
  "inkwell-backlink-coverage"
  "inkwell-duplicate-density"
)

init_repo() {
  local dest="$1"
  ( cd "$dest" \
    && git init -q \
    && git config user.email "fixture@inkwell.test" \
    && git config user.name  "Fixture Author" \
    && git add -A \
    && GIT_AUTHOR_DATE="2026-05-05T12:00:00" \
       GIT_COMMITTER_DATE="2026-05-05T12:00:00" \
       git commit -q -m "fixture: initial" )
}

# strip_inkwell_frontmatter <docs-dir> — for every *.md, drop the
# leading YAML frontmatter block. Plain markdown with no frontmatter
# is what an inkwell-unaware repo's docs/ tree looks like. The body
# is preserved unchanged so the rest of the audit sees the same
# content — only the inkwell template marker is removed.
strip_inkwell_frontmatter() {
  local dir="$1" f tmp
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    tmp="$(mktemp)"
    awk '
      NR==1 && $0=="---" { in_fm = 1; next }
      in_fm && $0=="---" { in_fm = 0; next }
      in_fm { next }
      { print }
    ' "$f" >"$tmp"
    mv "$tmp" "$f"
  done < <(find "$dir" -type f -name '*.md')
}

MARKED_REPO="$(mktemp -d -t inkwell-a4-marked.XXXXXX)"
PLAIN_REPO="$(mktemp -d -t inkwell-a4-plain.XXXXXX)"
trap 'rm -rf "$MARKED_REPO" "$PLAIN_REPO"' EXIT

# Both repos start from the same blueprint. The plain repo then has
# its docs/*.md frontmatter stripped — the only delta between the
# two trees is the inkwell template markers.
cp -r "$MARKED_BLUEPRINT"/. "$MARKED_REPO"/
cp -r "$MARKED_BLUEPRINT"/. "$PLAIN_REPO"/
strip_inkwell_frontmatter "$PLAIN_REPO/docs"
init_repo "$MARKED_REPO"
init_repo "$PLAIN_REPO"

MARKED_ENV="$("$ENVELOPE" "$MARKED_REPO")"
PLAIN_ENV="$("$ENVELOPE"  "$PLAIN_REPO")"

# ---------------------------------------------------------------------
# A4 #1: legacy scorer observations are byte-equivalent across
# fixtures. Because the only delta between marked and plain is the
# inkwell frontmatter — content the existing scorers don't read —
# the four legacy scorers must produce identical observations on
# both sides. Any divergence is a regression A4 was written to
# catch.
# ---------------------------------------------------------------------

for id in "${LEGACY_IDS[@]}"; do
  marked_obs="$(echo "$MARKED_ENV" | jq -c --arg id "$id" '.observations[] | select(.id == $id)')"
  plain_obs="$(echo  "$PLAIN_ENV"  | jq -c --arg id "$id" '.observations[] | select(.id == $id)')"
  assert_eq "legacy scorer '$id' byte-equivalent" "$plain_obs" "$marked_obs"
done

# ---------------------------------------------------------------------
# A4 #2: T5 conditional scorers fire only on the marked side.
# ---------------------------------------------------------------------

for id in "${CONDITIONAL_IDS[@]}"; do
  marked_present="$(echo "$MARKED_ENV" | jq -r --arg id "$id" '[.observations[] | select(.id == $id)] | length > 0')"
  plain_present="$(echo  "$PLAIN_ENV"  | jq -r --arg id "$id" '[.observations[] | select(.id == $id)] | length > 0')"
  assert_eq "conditional '$id' present on marked"  "true"  "$marked_present"
  assert_eq "conditional '$id' absent on plain"    "false" "$plain_present"
done

# ---------------------------------------------------------------------
# A4 #3: composite envelope shape is unchanged on the plain side
# (schema_version, plugin, dimension, composite_score all match the
# pre-T5 envelope shape).
# ---------------------------------------------------------------------

assert_eq "plain schema_version"  "2"                    "$(echo "$PLAIN_ENV" | jq -r '."$schema_version"')"
assert_eq "plain plugin"          "inkwell"              "$(echo "$PLAIN_ENV" | jq -r '.plugin')"
assert_eq "plain dimension"       "code-documentation"   "$(echo "$PLAIN_ENV" | jq -r '.dimension')"
assert_eq "plain composite_score" "null"                 "$(echo "$PLAIN_ENV" | jq -r '.composite_score')"

if (( fail == 0 )); then
  echo "audit-a4-regression.test.sh: PASS"
  exit 0
else
  echo "audit-a4-regression.test.sh: FAIL" >&2
  exit 1
fi
