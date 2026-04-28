#!/usr/bin/env bash
# snapshots.test.sh — invariant B regression suite for commventional s M3
# migration.
#
# For each fixture under snapshots/{clean,mid,noisy}/:
#   1. Materialise the fixture (build script for clean/noisy; pinned SHA
#      worktree for mid).
#   2. Run score-commventional.sh against the materialised input.
#   3. Diff `jq .categories` against the staged snapshot s `.categories`
#      — any byte-level diff fails.
#   4. Diff the v1 field projection
#      `{plugin,dimension,composite_score,letter_grade,recommendations}`
#      — same byte-identity rule.
#   5. Confirm `."$schema_version" == 2`.
#   6. Confirm `.observations | length == 4` and IDs match the M3 contract.
#
# The mid fixture worktree is created at a temp path on first run and
# cleaned up on exit. If `git worktree add` fails (e.g. shallow clone),
# the mid case is skipped with a warning rather than failed — the
# clean/noisy cases still gate the regression.
#
# Run: ./snapshots.test.sh
# Exits 0 on all-green, non-zero on any failing case.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SNAPSHOTS_DIR="$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SCORER="$REPO_ROOT/plugins/pronto/agents/parsers/scorers/score-commventional.sh"

PASS=0
FAIL=0
SKIP=0
FAILURES=()

if [[ ! -x "$SCORER" ]]; then
  echo "FATAL: scorer not executable: $SCORER" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FATAL: jq required" >&2
  exit 2
fi
if ! command -v git >/dev/null 2>&1; then
  echo "FATAL: git required" >&2
  exit 2
fi

# ----- mid worktree setup/teardown ------------------------------------
MID_SHA=""
MID_WORKTREE=""
mid_worktree_setup() {
  local fixtures="$REPO_ROOT/plugins/pronto/tests/fixtures.json"
  if [[ ! -f "$fixtures" ]]; then
    echo "WARN: fixtures.json not found; skipping mid case" >&2
    return 1
  fi
  MID_SHA=$(jq -r ".fixtures.mid.sha // empty" "$fixtures")
  if [[ -z "$MID_SHA" ]]; then
    echo "WARN: mid sha not in fixtures.json; skipping mid case" >&2
    return 1
  fi
  MID_WORKTREE="$(mktemp -d -t commv-snap-mid.XXXXXX)"
  if ! git -C "$REPO_ROOT" worktree add --detach "$MID_WORKTREE" "$MID_SHA" \
        >/dev/null 2>&1; then
    echo "WARN: failed to create mid worktree at $MID_SHA; skipping mid case" >&2
    rmdir "$MID_WORKTREE" 2>/dev/null || true
    MID_WORKTREE=""
    return 1
  fi
  return 0
}
mid_worktree_teardown() {
  if [[ -n "$MID_WORKTREE" && -d "$MID_WORKTREE" ]]; then
    git -C "$REPO_ROOT" worktree remove --force "$MID_WORKTREE" \
      >/dev/null 2>&1 || true
    rm -rf "$MID_WORKTREE" 2>/dev/null || true
  fi
}

# ----- synthetic-fixture build helpers --------------------------------
SYNTHETIC_DIRS=()
build_synthetic() {
  local slug="$1"
  local builder="$SNAPSHOTS_DIR/inputs/build-$slug.sh"
  if [[ ! -x "$builder" ]]; then
    echo "FATAL: builder not executable: $builder" >&2
    return 1
  fi
  local out
  out="$(mktemp -d -t "commv-snap-$slug.XXXXXX")"
  if ! "$builder" "$out" >/dev/null 2>&1; then
    rm -rf "$out"
    echo "FATAL: $slug builder failed" >&2
    return 1
  fi
  SYNTHETIC_DIRS+=("$out")
  echo "$out"
}
synthetic_teardown() {
  for d in "${SYNTHETIC_DIRS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}

cleanup_all() { mid_worktree_teardown; synthetic_teardown; }
trap cleanup_all EXIT

# ----- bookkeeping ----------------------------------------------------
note_pass() { PASS=$((PASS + 1)); }
note_fail() {
  local msg="$1"
  FAIL=$((FAIL + 1))
  FAILURES+=("$msg")
}

# run_fixture <slug> <input-dir>
run_fixture() {
  local slug="$1" input="$2"
  local snap="$SNAPSHOTS_DIR/$slug/envelope.json"
  local actual
  if [[ ! -f "$snap" ]]; then
    note_fail "$slug: snapshot envelope.json not found at $snap"
    return
  fi
  if ! actual="$(bash "$SCORER" "$input" 2>/dev/null)"; then
    note_fail "$slug: scorer exited non-zero"
    return
  fi

  # 1. categories[] byte-identity.
  local snap_cat actual_cat
  snap_cat=$(jq -S ".categories" "$snap")
  actual_cat=$(echo "$actual" | jq -S ".categories")
  if [[ "$snap_cat" == "$actual_cat" ]]; then
    note_pass
  else
    note_fail "$slug: categories[] diverged"
    diff <(echo "$snap_cat") <(echo "$actual_cat") | head -20 >&2
  fi

  # 2. v1 projection byte-identity.
  local snap_proj actual_proj
  snap_proj=$(jq -S "{plugin,dimension,composite_score,letter_grade,recommendations}" "$snap")
  actual_proj=$(echo "$actual" | jq -S "{plugin,dimension,composite_score,letter_grade,recommendations}")
  if [[ "$snap_proj" == "$actual_proj" ]]; then
    note_pass
  else
    note_fail "$slug: v1 projection diverged"
    diff <(echo "$snap_proj") <(echo "$actual_proj") | head -20 >&2
  fi

  # 3. $schema_version == 2.
  local sv
  sv=$(echo "$actual" | jq -r ".\"\$schema_version\" // \"missing\"")
  if [[ "$sv" == "2" ]]; then
    note_pass
  else
    note_fail "$slug: \$schema_version expected 2 got $sv"
  fi

  # 4. observations[] length == 4.
  local olen
  olen=$(echo "$actual" | jq -r ".observations | length // 0")
  if (( olen == 4 )); then
    note_pass
  else
    note_fail "$slug: observations length expected 4 got $olen"
  fi

  # 5. observations[] ID set matches the M3 contract (exact set, exact order).
  local expected_ids actual_ids
  expected_ids="[\"conventional-commit-ratio\",\"auto-trailer-count\",\"auto-attribution-marker-count\",\"review-signal-presence\"]"
  actual_ids=$(echo "$actual" | jq -c "[.observations[].id]")
  if [[ "$expected_ids" == "$actual_ids" ]]; then
    note_pass
  else
    note_fail "$slug: observation IDs diverged. expected=$expected_ids got=$actual_ids"
  fi
}

# ----- run all three fixtures ----------------------------------------
clean_dir=$(build_synthetic clean) && run_fixture "clean" "$clean_dir"
noisy_dir=$(build_synthetic noisy) && run_fixture "noisy" "$noisy_dir"

if mid_worktree_setup; then
  run_fixture "mid" "$MID_WORKTREE"
else
  SKIP=$((SKIP + 5))
fi

# ----- summary -------------------------------------------------------
if (( FAIL == 0 )); then
  echo "OK — $PASS checks passed, $SKIP skipped"
  exit 0
else
  echo "FAIL — $PASS passed, $FAIL failed, $SKIP skipped" >&2
  for msg in "${FAILURES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi
