#!/usr/bin/env bash
# run-all.sh — drive every towncrier scorer test in one command.
#
# Per the 2c2 ticket: one test harness per scorer, all callable from
# this top-level runner for one-command verification. Triple-run
# determinism, empty-scope short-circuits, and the bait-and-switch
# acceptance bars (ts-mixed for structured-logging-ratio,
# python-bait for event-schema-consistency) are regression-protected
# by the per-scorer harnesses.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

for t in \
  structured-logging-ratio.test.sh \
  metrics-presence.test.sh \
  trace-propagation.test.sh \
  event-schema-consistency.test.sh
do
  if ! bash "$HERE/$t"; then
    fail=1
  fi
done

if (( fail == 0 )); then
  echo "run-all.sh: ALL PASS"
  exit 0
else
  echo "run-all.sh: SOME FAILED" >&2
  exit 1
fi
