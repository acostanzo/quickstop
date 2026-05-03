#!/usr/bin/env bash
# strip-trailers.sh — canonical commventional v2.0 trailer-stripping
# capability. Strips engineering-ownership patterns from a text blob:
#
#   - Co-Authored-By: trailers (case-insensitive on each word's first letter)
#   - "Generated with/by Claude" footers (case-insensitive)
#
# Mirrors the perl substitution chain that v1.x's PreToolUse hook
# (hooks/enforce-ownership.sh) shipped — fixture parity against the
# pre-migration regex is invariant C of the v2.0 migration ticket
# (project/tickets/closed/phase-2-commventional-adr-006-conformance.md).
#
# Idempotent: running twice on the same input produces identical output.
# Read-only: writes only to stdout. No host state, no consumer-repo writes.
#
# Usage:
#   strip-trailers.sh --text "<text>"
#   echo "<text>" | strip-trailers.sh

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: strip-trailers.sh [--text <text>] [< stdin]

Strips Co-Authored-By trailers and "Generated with/by Claude" footers
from the input text. Reads from stdin if --text is not provided.
Output goes to stdout.
EOF
  exit 0
fi

if [[ "${1:-}" == "--text" ]]; then
  if [[ $# -lt 2 ]]; then
    echo "ERROR: --text requires an argument" >&2
    exit 2
  fi
  INPUT="$2"
else
  INPUT=$(cat)
fi

# Substitution (not line deletion) preserves trailing quote characters
# when attribution appears inline rather than in a HEREDOC. This matches
# the v1.x hook's bash-quoted-payload behaviour.
printf '%s\n' "$INPUT" | perl -pe '
  s/[Cc]o-[Aa]uthored-[Bb]y:[^"\x27\\]*//g;
  s/.*[Gg]enerated (?:with|by).*[Cc]laude[^"\x27\\]*//g;
' | cat -s
