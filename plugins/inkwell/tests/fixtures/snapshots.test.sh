#!/usr/bin/env bash
# snapshots.test.sh — invariant B regression suite for the inkwell
# three-fixture calibration set (low / mid / high).
#
# For each fixture under tests/fixtures/<slug>/:
#   1. Materialise the fixture via build-fixture.sh into a temp git
#      repo (the docs-staleness scorer requires real git history).
#   2. Run bin/build-envelope.sh against the materialised fixture.
#   3. Triple-run the orchestrator and confirm all three runs are
#      byte-equivalent (determinism regression).
#   4. Diff the rerun output against the locked envelope.json
#      (byte-equivalence regression — any drift in scorer output or
#      orchestrator shape fails the test).
#   5. Confirm $schema_version == 2.
#   6. Confirm observations[] length == 4 and the four observation IDs
#      match the code-documentation contract in fixed order.
#   7. Confirm composite_score == null (the rubric stanza is the
#      authority; any inline composite math regression caught here).
#   8. Pipe the envelope through pronto's observations-to-score.sh and
#      assert the composite matches the calibration table:
#        low  -> 45, mid  -> 81, high -> 100.
#
# Run: ./snapshots.test.sh
# Exits 0 on all-green, non-zero on any failing case.
#
# Tool prerequisites — interrogate, lychee, git, jq. Missing any of
# these would silently drop one of the four observations and break
# byte-equivalence with the locked envelope; the test errors out
# early rather than emit a misleading pass.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
BUILD_FIXTURE="$HERE/build-fixture.sh"
BUILD_ENVELOPE="$PLUGIN_ROOT/bin/build-envelope.sh"
HELPER="$REPO_ROOT/plugins/pronto/agents/parsers/scorers/observations-to-score.sh"

EXPECTED_IDS='["readme-arrival-coverage","docs-coverage-ratio","docs-staleness-count","broken-internal-links-count"]'

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

[[ -x "$BUILD_FIXTURE"  ]] || abort_missing "build-fixture.sh not executable at $BUILD_FIXTURE"
[[ -x "$BUILD_ENVELOPE" ]] || abort_missing "build-envelope.sh not executable at $BUILD_ENVELOPE"
[[ -x "$HELPER"         ]] || abort_missing "observations-to-score.sh not executable at $HELPER"
command -v jq          >/dev/null 2>&1 || abort_missing "jq required"
command -v git         >/dev/null 2>&1 || abort_missing "git required"
command -v interrogate >/dev/null 2>&1 || abort_missing "interrogate required (pipx install interrogate). Without it the docs-coverage observation drops and locked envelopes diverge."
command -v lychee      >/dev/null 2>&1 || abort_missing "lychee required (cargo install lychee or download binary release). Without it the broken-internal-links observation drops and locked envelopes diverge."

ENV_FILE="$(mktemp -t inkwell-snapshots.XXXXXX.json)"
WORKDIR="$(mktemp -d -t inkwell-snapshots-work.XXXXXX)"
trap 'rm -f "$ENV_FILE"; rm -rf "$WORKDIR"' EXIT

# run_fixture <slug> <expected-rubric-composite>
run_fixture() {
  local slug="$1" expected_composite="$2"
  local blueprint="$HERE/$slug"
  local snap="$blueprint/envelope.json"
  local out_dir="$WORKDIR/$slug"

  if [[ ! -d "$blueprint" ]]; then
    note_fail "$slug: blueprint directory missing at $blueprint"
    return
  fi
  if [[ ! -f "$snap" ]]; then
    note_fail "$slug: locked envelope.json missing at $snap"
    return
  fi

  if ! bash "$BUILD_FIXTURE" "$slug" "$out_dir" >/dev/null 2>&1; then
    note_fail "$slug: build-fixture.sh failed"
    return
  fi

  # Triple-run determinism on the orchestrator.
  local r1 r2 r3
  r1=$(bash "$BUILD_ENVELOPE" "$out_dir" 2>/dev/null)
  r2=$(bash "$BUILD_ENVELOPE" "$out_dir" 2>/dev/null)
  r3=$(bash "$BUILD_ENVELOPE" "$out_dir" 2>/dev/null)
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

  # 4. observations[] ID set matches the code-documentation contract
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
  helper_composite=$(bash "$HELPER" code-documentation "$ENV_FILE" 2>/dev/null | jq -r .composite_score)
  if [[ "$helper_composite" == "$expected_composite" ]]; then
    note_pass
  else
    note_fail "$slug: rubric composite expected $expected_composite got $helper_composite"
  fi
}

# Calibration table from phase-2-2a3-inkwell-contract-fixtures.md.
run_fixture "low"  45
run_fixture "mid"  81
run_fixture "high" 100

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
