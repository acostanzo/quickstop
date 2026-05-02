#!/usr/bin/env bash
# snapshots.test.sh — invariant B regression suite for the towncrier
# three-fixture calibration set (python-low / python-mid / python-high).
#
# For each fixture under tests/fixtures/<slug>/:
#   1. Triple-run bin/build-envelope.sh against the fixture and confirm
#      all three runs are byte-equivalent (determinism regression).
#   2. Diff the rerun output against the locked envelope.json
#      (byte-equivalence regression — any drift in scorer output or
#      orchestrator shape fails the test).
#   3. Confirm $schema_version == 2.
#   4. Confirm observations[] length == 4 and the four observation IDs
#      match the event-emission contract in fixed order.
#   5. Confirm composite_score == null (the rubric stanza is the
#      authority; any inline composite math regression caught here).
#   6. Pipe the envelope through pronto's observations-to-score.sh and
#      assert the composite matches the calibration table:
#        python-low -> 35, python-mid -> 81, python-high -> 100.
#
# Unlike inkwell's snapshots.test.sh, towncrier doesn't materialise a
# git repo per fixture — none of the four scorers consume temporal
# signals (no doc-staleness equivalent), so the static fixture
# directories ARE the test inputs. Triple-run replaces per-fixture
# N=10 per the 2c3 ticket's "Variance harness shape" deviation.
#
# Run: ./snapshots.test.sh
# Exits 0 on all-green, non-zero on any failing case.
#
# Tool prerequisites — git, jq. Towncrier's scorers are pure shell +
# grep + awk + jq; no language toolchain is invoked, so there are no
# tool-absence-driven envelope drifts to defend against.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
BUILD_ENVELOPE="$PLUGIN_ROOT/bin/build-envelope.sh"
HELPER="$REPO_ROOT/plugins/pronto/agents/parsers/scorers/observations-to-score.sh"

EXPECTED_IDS='["structured-logging-ratio","metrics-instrumentation-count","trace-propagation-ratio","event-schema-consistency-ratio"]'

PASS=0
FAIL=0
FAILURES=()

note_pass() { PASS=$((PASS + 1)); }
note_fail() {
  local msg="$1"
  FAIL=$((FAIL + 1))
  FAILURES+=("$msg")
}

abort_missing() {
  local what="$1"
  echo "FATAL: $what" >&2
  exit 2
}

[[ -x "$BUILD_ENVELOPE" ]] || abort_missing "build-envelope.sh not executable at $BUILD_ENVELOPE"
[[ -x "$HELPER"         ]] || abort_missing "observations-to-score.sh not executable at $HELPER"
command -v jq >/dev/null 2>&1 || abort_missing "jq required"

ENV_FILE="$(mktemp -t towncrier-snapshots.XXXXXX.json)"
trap 'rm -f "$ENV_FILE"' EXIT

# run_fixture <slug> <expected-rubric-composite>
run_fixture() {
  local slug="$1" expected_composite="$2"
  local fixture="$HERE/$slug"
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
  r1=$(bash "$BUILD_ENVELOPE" "$fixture" 2>/dev/null)
  r2=$(bash "$BUILD_ENVELOPE" "$fixture" 2>/dev/null)
  r3=$(bash "$BUILD_ENVELOPE" "$fixture" 2>/dev/null)
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

  # 4. observations[] ID set matches the event-emission contract
  #    (exact set, exact order — fixed by build-envelope.sh).
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
  helper_composite=$(bash "$HELPER" event-emission "$ENV_FILE" 2>/dev/null | jq -r .composite_score)
  if [[ "$helper_composite" == "$expected_composite" ]]; then
    note_pass
  else
    note_fail "$slug: rubric composite expected $expected_composite got $helper_composite"
  fi
}

# Calibration table from phase-2-2c3-towncrier-contract-fixtures.md.
run_fixture "python-low"  35
run_fixture "python-mid"  81
run_fixture "python-high" 100

if (( FAIL == 0 )); then
  echo "snapshots.test.sh: PASS — $PASS checks across 3 fixtures"
  exit 0
else
  echo "snapshots.test.sh: FAIL — $PASS passed, $FAIL failed" >&2
  for msg in "${FAILURES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi
