#!/usr/bin/env bash
# run-all.sh — drive every inkwell scorer test in one command.
#
# Per the 2a2 ticket: one test harness per scorer, all callable from
# this top-level runner for one-command verification.
#
# Tool-absent branches in link-health.test.sh (lychee) and
# docs-coverage.test.sh (interrogate / eslint / revive / cargo) are
# expected to fire on dev boxes without the tool installed; CI
# environments with tools installed exercise the count-check branches.
# Either branch is a PASS — the tool-absent invariant from the 2a2
# ticket is regression-protected by both shapes.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

for t in \
  readme-quality.test.sh \
  link-health.test.sh \
  doc-staleness.test.sh \
  docs-coverage.test.sh
do
  if ! bash "$HERE/$t"; then
    fail=1
  fi
done

# End-to-end snapshots regression — different fixture tree
# (plugins/inkwell/tests/fixtures/) because the staleness scorer
# requires real git history that the per-scorer fixtures don't carry.
SNAPSHOTS="$HERE/../../tests/fixtures/snapshots.test.sh"
if [[ -x "$SNAPSHOTS" ]]; then
  if ! bash "$SNAPSHOTS"; then
    fail=1
  fi
fi

if (( fail == 0 )); then
  echo "run-all.sh: ALL PASS"
  exit 0
else
  echo "run-all.sh: SOME FAILED" >&2
  exit 1
fi
