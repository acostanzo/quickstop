#!/usr/bin/env bash
# run-all.sh — drive every lintguini scorer test and the lifted
# end-to-end smoke. One-command verification per the 2b2 ticket.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

for t in \
  linter-presence.test.sh \
  formatter-presence.test.sh \
  ci-lint-wired.test.sh \
  suppression-count.test.sh \
  end-to-end.test.sh \
  snapshots.test.sh
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
