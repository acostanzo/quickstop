#!/usr/bin/env bash
# run-all.sh — drive every commventional test in one command.
#
# Walk a fixed list of test scripts, fail the runner if any of them
# fails, summarise at the end.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
fail=0

for t in \
  "$PLUGIN_ROOT/test-fixtures/strip-trailers/cases.test.sh" \
  "$PLUGIN_ROOT/test-fixtures/snapshots/snapshots.test.sh" \
  "$PLUGIN_ROOT/test-fixtures/post-review/post-review-dryrun.test.sh"
do
  if [[ ! -x "$t" ]]; then
    echo "WARN: skipping $t (not executable)" >&2
    continue
  fi
  if ! bash "$t"; then
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
