#!/usr/bin/env bash
# observations-to-score.sh — translate a sibling's v2 audit JSON into a
# pronto-side dimension score by applying the per-observation rubric
# rules registered in references/rubric.md.
#
# Usage:
#   observations-to-score.sh <dimension-slug> <scorer-json-path>
#
# Reads the named dimension's JSON stanza out of rubric.md, walks the
# input's observations[] array, applies the per-observation rule per
# kind (ratio/count/presence/score), and emits a JSON envelope on
# stdout:
#
#   {
#     "composite_score": 78,
#     "observations_applied": [
#       { "id": "...", "kind": "ratio", "score": 70, "rule": "ladder" }
#     ],
#     "passthrough_used": false,
#     "dropped": [
#       { "id": "...", "reason": "no rubric rule registered" }
#     ]
#   }
#
# Contract: input must be a v2 envelope (`$schema_version: 2`).
# v1-only payloads (no `$schema_version`) were deprecated post-M3 on
# 2026-04-28; the helper now hard-errors on them rather than silently
# passing the legacy `composite_score` through. See the
# phase-2-passthrough-deprecation ticket for the deprecation rationale.
#
# The passthrough rule still applies in two cases — both v2-native:
#  - **No stanza** for the requested dimension in rubric.md (a sibling
#    emitted observations[] against an unregistered dimension; the
#    helper degrades rather than fails so the audit still produces a
#    score).
#  - **Empty `observations: []`** on a v2 envelope (the sibling chose
#    not to score this run, e.g. M2's empty-skills case or M3's
#    thin-history gate; honour the no-scope signal).
#
# In both cases the helper emits the envelope's legacy `composite_score`
# as the dimension score if present, or `composite_score: null` with
# `passthrough_used: true` so the caller can degrade to presence-cap.
#
# All progress / diagnostic output goes to stderr; only the JSON
# envelope lands on stdout.
#
# Exit 0 on success. Exit 2 on argument or environment errors.
# Exit 3 on stanza-loader errors (mixed-weight config, malformed JSON
# in rubric.md, unknown kind in stanza).
# Exit 4 on deprecated v1-only payload (no `$schema_version: 2`).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../.." && pwd)"
RUBRIC_PATH="${PRONTO_RUBRIC_PATH:-$PLUGIN_ROOT/references/rubric.md}"

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") <dimension-slug> <scorer-json-path>" >&2
  exit 2
fi

DIMENSION="$1"
INPUT_JSON="$2"

if [[ ! -f "$INPUT_JSON" ]]; then
  echo "Error: scorer JSON path '$INPUT_JSON' does not exist" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq required" >&2
  exit 2
fi
if [[ ! -f "$RUBRIC_PATH" ]]; then
  echo "Error: rubric.md not found at '$RUBRIC_PATH'" >&2
  exit 2
fi

# ---- Stanza extraction --------------------------------------------------
#
# rubric.md lays each translation stanza inside a fenced ```json block
# directly under a `### \`<dimension-slug>\` translation rules` heading.
# extract_stanza walks the file with awk:
#  - look for the heading whose first backtick-quoted token matches
#    the dimension slug;
#  - once seen, capture lines between the next ```json fence and its
#    closing ``` fence;
#  - stop after the first such block under that heading.

extract_stanza() {
  local slug="$1" rubric="$2"
  awk -v slug="$slug" '
    BEGIN { inheading=0; injson=0 }
    {
      if ($0 ~ "^### `" slug "` translation rules") {
        inheading = 1
        next
      }
      if (inheading && /^```json[[:space:]]*$/) {
        injson = 1
        next
      }
      if (injson && /^```[[:space:]]*$/) {
        exit
      }
      if (injson) {
        print
      }
      # Another heading at the same level closes the section.
      if (inheading && /^### / && $0 !~ "^### `" slug "`") {
        exit
      }
    }
  ' "$rubric"
}

STANZA="$(extract_stanza "$DIMENSION" "$RUBRIC_PATH")"
if [[ -z "$STANZA" ]]; then
  echo "Stanza loader: no stanza for dimension '$DIMENSION' in $RUBRIC_PATH" >&2
  echo "Falling through to legacy composite_score passthrough." >&2
  STANZA=""
fi

# Validate stanza JSON if present.
if [[ -n "$STANZA" ]]; then
  if ! echo "$STANZA" | jq empty 2>/dev/null; then
    echo "Stanza loader: stanza for '$DIMENSION' is not valid JSON" >&2
    exit 3
  fi
  # Mixed-weight guardrail: either every observation declares a weight
  # or none do. Mixed configs produce silent miscalibration when the
  # weighting math runs (the implicit-weight observations would absorb
  # whatever fraction the explicit ones leave behind, which is rarely
  # what the author meant).
  weight_check="$(echo "$STANZA" | jq -r '
    [.observations[]? | has("weight")] as $flags
    | if ($flags | length) == 0 then "ok"
      elif ($flags | all) then "all"
      elif ($flags | any) then "mixed"
      else "none"
      end')"
  if [[ "$weight_check" == "mixed" ]]; then
    echo "Stanza loader: dimension '$DIMENSION' mixes explicit and implicit weights" >&2
    echo "Either every observation declares a weight or none do." >&2
    exit 3
  fi
  # Reject unknown kinds at load time so the per-observation loop never
  # has to defend against an unrecognised branch.
  unknown_kinds="$(echo "$STANZA" | jq -r '
    [.observations[]? | select(.kind | IN("ratio","count","presence","score") | not) | .id] | join(",")')"
  if [[ -n "$unknown_kinds" ]]; then
    echo "Stanza loader: unknown kind in observations [$unknown_kinds]" >&2
    exit 3
  fi
fi

# ---- Input shape --------------------------------------------------------
SCHEMA_VERSION="$(jq -r '."$schema_version" // empty' "$INPUT_JSON")"
HAS_OBS="$(jq '(.observations // [] | length) > 0' "$INPUT_JSON")"
HAS_COMPOSITE="$(jq 'has("composite_score") and (.composite_score | type == "number")' "$INPUT_JSON")"
LEGACY_COMPOSITE="$(jq -r '.composite_score // empty' "$INPUT_JSON")"

# ---- Schema gate (deprecation 2026-04-28) ------------------------------
#
# v1-only payloads (no `$schema_version: 2`) were valid input until M3
# closed the migration on every in-repo sibling. The translator now
# hard-errors on them rather than silently passing the legacy
# composite_score through — see project/tickets/closed/phase-2-
# passthrough-deprecation.md and ADR-005 §3 for the rationale.
if [[ "$SCHEMA_VERSION" != "2" ]]; then
  echo "Error: payload missing \$schema_version: 2 (got: ${SCHEMA_VERSION:-<absent>})" >&2
  echo "v1 composite_score passthrough was deprecated 2026-04-28 (post-M3)." >&2
  echo "Every sibling envelope must carry \$schema_version: 2 with an observations[] field." >&2
  exit 4
fi

# ---- Passthrough emit helper -------------------------------------------
#
# Two surviving cases land here, both on a valid v2 envelope:
#  1. No rubric stanza for the requested dimension (degrade rather than
#     fail — the audit still produces a score for unknown dimensions).
#  2. Empty `observations: []` — the sibling's v2-native "no scope"
#     signal (M2's empty-skills, M3's thin-history). Honour it.
emit_passthrough() {
  local note="$1"
  echo "Passthrough: $note" >&2
  if [[ "$HAS_COMPOSITE" == "true" ]]; then
    jq -n \
      --argjson cs "$LEGACY_COMPOSITE" \
      --argjson dropped "$DROPPED_JSON" \
      '{
        composite_score: $cs,
        observations_applied: [],
        passthrough_used: true,
        dropped: $dropped
      }'
  else
    jq -n \
      --argjson dropped "$DROPPED_JSON" \
      '{
        composite_score: null,
        observations_applied: [],
        passthrough_used: true,
        dropped: $dropped
      }'
  fi
}

DROPPED_JSON='[]'

# ---- Fall straight through if no observations or no stanza -------------
if [[ -z "$STANZA" || "$HAS_OBS" == "false" ]]; then
  if [[ "$HAS_OBS" == "false" ]]; then
    emit_passthrough "no observations[] in input"
  else
    emit_passthrough "no stanza for dimension '$DIMENSION'"
  fi
  exit 0
fi

# ---- Observation walk --------------------------------------------------
#
# For each input observation: look up the rule, branch on kind, score
# it, accumulate. Drops record their reason. One jq invocation per
# observation keeps the logic obvious; total observation counts are
# small (~3-5 per dimension) so this is not a hot loop.

OBS_COUNT="$(jq '.observations | length' "$INPUT_JSON")"
APPLIED_FILE="$(mktemp -t obs-applied.XXXXXX.json)"
DROPPED_FILE="$(mktemp -t obs-dropped.XXXXXX.json)"
trap 'rm -f "$APPLIED_FILE" "$DROPPED_FILE"' EXIT

for ((i=0; i<OBS_COUNT; i++)); do
  obs="$(jq -c ".observations[$i]" "$INPUT_JSON")"
  obs_id="$(echo "$obs" | jq -r '.id // empty')"
  obs_kind="$(echo "$obs" | jq -r '.kind // empty')"
  if [[ -z "$obs_id" || -z "$obs_kind" ]]; then
    jq -nc --arg id "$obs_id" --arg reason "missing id or kind" \
      '{id:$id, reason:$reason}' >> "$DROPPED_FILE"
    continue
  fi

  rule="$(echo "$STANZA" | jq -c --arg id "$obs_id" '.observations[]? | select(.id == $id)')"
  if [[ -z "$rule" ]]; then
    jq -nc --arg id "$obs_id" --arg reason "no rubric rule registered" \
      '{id:$id, reason:$reason}' >> "$DROPPED_FILE"
    continue
  fi

  # Kind-mismatch guard: if the input observation's kind disagrees with
  # the rubric rule's kind, drop it. The rubric is authoritative on what
  # shape the rule expects.
  rule_kind="$(echo "$rule" | jq -r '.kind')"
  if [[ "$rule_kind" != "$obs_kind" ]]; then
    jq -nc --arg id "$obs_id" --arg reason "kind mismatch (input=$obs_kind, rubric=$rule_kind)" \
      '{id:$id, reason:$reason}' >> "$DROPPED_FILE"
    continue
  fi

  rule_name="$(echo "$rule" | jq -r '.rule')"
  score=""
  case "$obs_kind" in
    ratio|count)
      if [[ "$rule_name" != "ladder" ]]; then
        jq -nc --arg id "$obs_id" --arg reason "rule '$rule_name' not supported for kind '$obs_kind'" \
          '{id:$id, reason:$reason}' >> "$DROPPED_FILE"
        continue
      fi
      # Ratio observations expect evidence.ratio; count expects an
      # integer measurement. We accept either evidence.<canonical> or
      # the first numeric field on .evidence as a convenience.
      if [[ "$obs_kind" == "ratio" ]]; then
        value="$(echo "$obs" | jq -r '
          if (.evidence | type == "object") and (.evidence | has("ratio")) then .evidence.ratio
          elif (.evidence | type == "object") and (.evidence | has("numerator")) and (.evidence | has("denominator")) and (.evidence.denominator != 0)
            then (.evidence.numerator / .evidence.denominator)
          else empty end')"
      else
        value="$(echo "$obs" | jq -r '
          if (.evidence | type == "object") and (.evidence | has("count"))      then .evidence.count
          elif (.evidence | type == "object") and (.evidence | has("configured")) then .evidence.configured
          elif (.evidence | type == "object") and (.evidence | has("value"))    then .evidence.value
          else
            (.evidence // {} | to_entries | map(select(.value | type == "number")) | .[0].value // empty)
          end')"
      fi
      if [[ -z "$value" || "$value" == "null" ]]; then
        jq -nc --arg id "$obs_id" --arg reason "evidence missing numeric value for kind '$obs_kind'" \
          '{id:$id, reason:$reason}' >> "$DROPPED_FILE"
        continue
      fi
      score="$(echo "$rule" | jq -r --argjson v "$value" '
        (.bands // []) as $bands
        | (first(
            $bands[]
            | (if has("gte") then (if $v >= .gte then .score else empty end)
               elif has("else") then .else
               else empty end)
          )) // null')"
      if [[ "$score" == "null" || -z "$score" ]]; then
        jq -nc --arg id "$obs_id" --arg reason "no band matched for value $value" \
          '{id:$id, reason:$reason}' >> "$DROPPED_FILE"
        continue
      fi
      ;;
    presence)
      if [[ "$rule_name" != "boolean" ]]; then
        jq -nc --arg id "$obs_id" --arg reason "rule '$rule_name' not supported for kind 'presence'" \
          '{id:$id, reason:$reason}' >> "$DROPPED_FILE"
        continue
      fi
      present_val="$(echo "$obs" | jq -r '
        if (.evidence | type == "object") and (.evidence | has("present"))
        then .evidence.present
        else empty end')"
      if [[ -z "$present_val" ]]; then
        jq -nc --arg id "$obs_id" --arg reason "evidence.present missing for kind 'presence'" \
          '{id:$id, reason:$reason}' >> "$DROPPED_FILE"
        continue
      fi
      if [[ "$present_val" == "true" ]]; then
        score="$(echo "$rule" | jq -r '.present')"
      else
        score="$(echo "$rule" | jq -r '.absent')"
      fi
      ;;
    score)
      # passthrough — the score on the observation IS the dimension
      # score for this observation. Honours the contract's "score
      # observations are pre-scored 0-100" semantic.
      if [[ "$rule_name" != "passthrough" ]]; then
        jq -nc --arg id "$obs_id" --arg reason "rule '$rule_name' not supported for kind 'score'" \
          '{id:$id, reason:$reason}' >> "$DROPPED_FILE"
        continue
      fi
      score="$(echo "$obs" | jq -r '
        if (.evidence | type == "object") and (.evidence | has("score"))
        then .evidence.score
        else empty end')"
      if [[ -z "$score" ]]; then
        jq -nc --arg id "$obs_id" --arg reason "evidence.score missing for kind 'score'" \
          '{id:$id, reason:$reason}' >> "$DROPPED_FILE"
        continue
      fi
      ;;
  esac

  # Persist the applied observation. Pull weight from the rule if
  # present; the aggregator below will fill in equal-share for absent
  # weights.
  weight="$(echo "$rule" | jq -r '.weight // empty')"
  if [[ -n "$weight" ]]; then
    jq -nc \
      --arg id "$obs_id" --arg kind "$obs_kind" --arg rule "$rule_name" \
      --argjson score "$score" --argjson weight "$weight" \
      '{id:$id, kind:$kind, rule:$rule, score:$score, weight:$weight}' >> "$APPLIED_FILE"
  else
    jq -nc \
      --arg id "$obs_id" --arg kind "$obs_kind" --arg rule "$rule_name" \
      --argjson score "$score" \
      '{id:$id, kind:$kind, rule:$rule, score:$score}' >> "$APPLIED_FILE"
  fi
done

# Slurp the streamed jsonl files into arrays.
DROPPED_JSON="$(jq -s '.' "$DROPPED_FILE")"
APPLIED_JSON="$(jq -s '.' "$APPLIED_FILE")"
APPLIED_COUNT="$(echo "$APPLIED_JSON" | jq 'length')"

if [[ "$APPLIED_COUNT" == "0" ]]; then
  emit_passthrough "all observations dropped"
  exit 0
fi

# Aggregate. Equal-share weighting (1/n) when no observation declares a
# weight; explicit weights are used as-is. Mixed configs were rejected
# at stanza-load time, so by here the applied set is uniform.
COMPOSITE="$(echo "$APPLIED_JSON" | jq -r '
  (map(has("weight")) | all) as $all_weighted
  | if $all_weighted then
      ([.[] | (.score * .weight)] | add | round)
    else
      ((length) as $n
       | (map(.score) | add) / $n
       | round)
    end')"

jq -n \
  --argjson cs "$COMPOSITE" \
  --argjson applied "$APPLIED_JSON" \
  --argjson dropped "$DROPPED_JSON" \
  '{
    composite_score: $cs,
    observations_applied: $applied,
    passthrough_used: false,
    dropped: $dropped
  }'
