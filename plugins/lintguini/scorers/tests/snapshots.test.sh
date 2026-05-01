#!/usr/bin/env bash
# snapshots.test.sh — invariant B regression suite for the lintguini
# end-to-end fixture set.
#
# For each fixture under fixtures/end-to-end/<lang>-{low,mid,high}/:
#   1. Run bin/build-envelope.sh against the fixture.
#   2. Diff the rerun output against the locked envelope.json
#      (byte-equivalence regression — any drift in scorer output or
#      orchestrator shape fails the test).
#   3. Triple-run the orchestrator and confirm all three runs are
#      byte-equivalent (determinism regression).
#   4. Confirm $schema_version == 2.
#   5. Confirm observations[] length == 4 and the four observation IDs
#      match the lint-posture contract in fixed order.
#   6. Confirm composite_score == null (the rubric stanza is the
#      authority; any inline composite math regression caught here).
#   7. Pipe the envelope through pronto's observations-to-score.sh and
#      assert the composite matches the calibration verification table
#      in phase-2-2b3-lintguini-contract-fixtures.md.
#
# Run: ./snapshots.test.sh
# Exits 0 on all-green, non-zero on any failing case.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
BUILD="$PLUGIN_ROOT/bin/build-envelope.sh"
HELPER="$REPO_ROOT/plugins/pronto/agents/parsers/scorers/observations-to-score.sh"
FIXTURES="$HERE/fixtures/end-to-end"

EXPECTED_IDS='["linter-strictness-ratio","formatter-configured-count","ci-lint-wired-ratio","lint-suppression-count"]'

PASS=0
FAIL=0
FAILURES=()

note_pass() { PASS=$((PASS + 1)); }
note_fail() {
  local msg="$1"
  FAIL=$((FAIL + 1))
  FAILURES+=("$msg")
}

if [[ ! -x "$BUILD" ]]; then
  echo "FATAL: build-envelope.sh not executable at $BUILD" >&2
  exit 2
fi
if [[ ! -x "$HELPER" ]]; then
  echo "FATAL: observations-to-score.sh not executable at $HELPER" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "FATAL: jq required" >&2
  exit 2
fi

ENV_FILE="$(mktemp -t lintguini-snapshots.XXXXXX.json)"
trap 'rm -f "$ENV_FILE"' EXIT

# run_fixture <slug> <expected-rubric-composite>
run_fixture() {
  local slug="$1" expected_composite="$2"
  local fixture="$FIXTURES/$slug"
  local snap="$fixture/envelope.json"

  if [[ ! -d "$fixture" ]]; then
    note_fail "$slug: fixture directory missing at $fixture"
    return
  fi
  if [[ ! -f "$snap" ]]; then
    note_fail "$slug: locked envelope.json missing at $snap"
    return
  fi

  # Triple-run determinism on the orchestrator.
  local r1 r2 r3
  r1=$(bash "$BUILD" "$fixture" 2>/dev/null)
  r2=$(bash "$BUILD" "$fixture" 2>/dev/null)
  r3=$(bash "$BUILD" "$fixture" 2>/dev/null)
  if [[ "$r1" != "$r2" || "$r2" != "$r3" ]]; then
    note_fail "$slug: triple-run output diverged"
    return
  fi
  note_pass

  # 1. byte-equivalence vs locked envelope (jq -S sorts keys to
  # neutralise key-order drift; the only acceptable difference is none).
  local snap_norm rerun_norm
  snap_norm=$(jq -S '.' "$snap")
  rerun_norm=$(echo "$r1" | jq -S '.')
  if [[ "$snap_norm" == "$rerun_norm" ]]; then
    note_pass
  else
    note_fail "$slug: envelope diverged from locked snapshot"
    diff <(echo "$snap_norm") <(echo "$rerun_norm") | head -20 >&2
  fi

  # 2. $schema_version == 2.
  local sv
  sv=$(echo "$r1" | jq -r '."$schema_version" // "missing"')
  if [[ "$sv" == "2" ]]; then
    note_pass
  else
    note_fail "$slug: \$schema_version expected '2' got '$sv'"
  fi

  # 3. observations[] length == 4.
  local olen
  olen=$(echo "$r1" | jq -r '.observations | length // 0')
  if [[ "$olen" == "4" ]]; then
    note_pass
  else
    note_fail "$slug: observations length expected 4 got $olen"
  fi

  # 4. observations[] ID set matches the lint-posture contract (exact set, exact order).
  local actual_ids
  actual_ids=$(echo "$r1" | jq -c '[.observations[].id]')
  if [[ "$EXPECTED_IDS" == "$actual_ids" ]]; then
    note_pass
  else
    note_fail "$slug: observation IDs diverged. expected=$EXPECTED_IDS got=$actual_ids"
  fi

  # 5. composite_score is null (rubric stanza is the authority).
  local cs
  cs=$(echo "$r1" | jq -r '.composite_score')
  if [[ "$cs" == "null" ]]; then
    note_pass
  else
    note_fail "$slug: composite_score expected null got $cs"
  fi

  # 6. translator-derived composite matches the calibration table.
  echo "$r1" > "$ENV_FILE"
  local helper_composite
  helper_composite=$(bash "$HELPER" lint-posture "$ENV_FILE" 2>/dev/null | jq -r .composite_score)
  if [[ "$helper_composite" == "$expected_composite" ]]; then
    note_pass
  else
    note_fail "$slug: rubric composite expected $expected_composite got $helper_composite"
  fi
}

# Calibration table from phase-2-2b3-lintguini-contract-fixtures.md:
#   python {28, 86, 100} / ruby {28, 91, 100} / typescript {28, 81, 100}
run_fixture "python-low"      28
run_fixture "python-mid"      86
run_fixture "python-high"     100
run_fixture "ruby-low"        28
run_fixture "ruby-mid"        91
run_fixture "ruby-high"       100
run_fixture "typescript-low"  28
run_fixture "typescript-mid"  81
run_fixture "typescript-high" 100

if (( FAIL == 0 )); then
  echo "snapshots.test.sh: PASS — $PASS checks across 9 fixtures"
  exit 0
else
  echo "snapshots.test.sh: FAIL — $PASS passed, $FAIL failed" >&2
  for msg in "${FAILURES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi
