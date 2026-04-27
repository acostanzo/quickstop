#!/usr/bin/env bash
# Pronto audit composite-envelope composer.
#
# Phase 6's deterministic emit step. Reads the prepared composite envelope
# from .pronto/composite-out.json, validates the schema, and prints the JSON
# byte-clean to stdout for the orchestrator to transmit verbatim.
#
# The point is to remove the LLM-controlled *construction* step from the
# emit boundary. Phase 5/6 builds the envelope into the file via jq; this
# script reads it back and emits it. The orchestrator's job at emit time
# becomes "byte-identical transcription of this script's stdout" instead
# of "assemble a multi-KB JSON object with all required fields."
#
# Exit codes:
#   0  envelope validated and printed
#   2  envelope file missing
#   3  envelope failed schema validation (stderr shows the file content)
#
# This script is deliberately minimal — it does not patch, repair, or
# normalise the envelope. If the prepared file is wrong, that is a Phase 5/6
# orchestrator bug that should surface, not be silently rewritten.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "compose-composite: usage: compose-composite.sh <REPO_ROOT>" >&2
    exit 2
fi

REPO_ROOT="$1"
ENVELOPE_PATH="${REPO_ROOT%/}/.pronto/composite-out.json"

if [[ ! -f "$ENVELOPE_PATH" ]]; then
    echo "compose-composite: envelope file not found: $ENVELOPE_PATH" >&2
    echo "compose-composite: Phase 6 step 1 must write the envelope to this path before invoking the composer." >&2
    exit 2
fi

# Validate the discriminators and required structural fields. The two
# discriminators (schema_version + dimensions[]) are what distinguish a
# composite envelope from a sibling sub-audit; the rest are required
# top-level fields per references/report-format.md.
if ! jq -e '
    (.schema_version == 1)
    and (.repo | type == "string") and (.repo | length > 0)
    and (.timestamp | type == "string") and (.timestamp | length > 0)
    and (.composite_score | type == "number")
    and (.composite_score >= 0) and (.composite_score <= 100)
    and (.composite_grade | type == "string")
    and (.composite_label | type == "string")
    and (.dimensions | type == "array")
    and (.dimensions | length == 8)
    and (.kernel | type == "object")
    and (.sibling_integration_notes | type == "array")
' "$ENVELOPE_PATH" >/dev/null 2>&1; then
    echo "compose-composite: envelope at $ENVELOPE_PATH failed schema validation" >&2
    echo "compose-composite: required: schema_version=1, repo, timestamp, composite_score 0-100, composite_grade, composite_label, dimensions[8], kernel{}, sibling_integration_notes[]" >&2
    echo "compose-composite: file content follows on stderr:" >&2
    cat "$ENVELOPE_PATH" >&2 || true
    exit 3
fi

# Emit byte-clean. -c produces compact (no internal whitespace) JSON;
# tr -d '\n' strips the trailing newline jq always appends. The orchestrator
# transcribes the stdout exactly — there must be no trailing whitespace
# for downstream `jq` consumers piping pronto's stdout.
jq -c . "$ENVELOPE_PATH" | tr -d '\n'
