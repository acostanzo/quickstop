#!/usr/bin/env bash
# Deterministic commventional parser.
#
# Emits the sibling-audit wire-contract JSON for the commit-hygiene
# dimension by running regex and trailer counts over the last 50 non-merge
# commits in <REPO_ROOT>. The Conventional Comments category is scored
# purely from local git history (we do not hit GitHub) — GH API variance
# was a historical source of noise and is off the hot path now.
#
# Usage:
#   score-commventional.sh <REPO_ROOT>
#
# Exit 0 on success. Exit 2 on argument or environment errors.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
. "$HERE/_common.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <REPO_ROOT>" >&2
  exit 2
fi

REPO_ROOT="$1"
if [[ ! -d "$REPO_ROOT" ]]; then
  echo "Error: REPO_ROOT '$REPO_ROOT' is not a directory" >&2
  exit 2
fi
if ! command -v jq  >/dev/null 2>&1; then echo "Error: jq required"  >&2; exit 2; fi
if ! command -v git >/dev/null 2>&1; then echo "Error: git required" >&2; exit 2; fi

if ! git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  # Non-git repo — emit neutral but honest scorecard rather than failing.
  # Schema v2: empty observations[] tells the translator to fall through
  # to the v1 composite_score passthrough rule.
  jq -n '{
    "$schema_version": 2,
    plugin: "commventional",
    dimension: "commit-hygiene",
    categories: [
      {name:"Conventional Commits",   weight:0.50, score:50, findings:[{severity:"low", message:"Not a git repository — insufficient signal"}]},
      {name:"Engineering Ownership",  weight:0.30, score:100, findings:[]},
      {name:"Conventional Comments",  weight:0.20, score:100, findings:[{severity:"low", message:"No review signal (no git history available)"}]}
    ],
    observations: [],
    composite_score: 75,
    letter_grade: "B",
    recommendations: []
  }'
  exit 0
fi

FINDINGS_FILE="$(mktemp -t commv-findings.XXXXXX.json)"
RECS_FILE="$(mktemp -t commv-recs.XXXXXX.json)"
trap 'rm -f "$FINDINGS_FILE" "$RECS_FILE"' EXIT

emit_finding() {
  local category="$1" severity="$2" message="$3"
  jq -nc \
    --arg c "$category" --arg s "$severity" --arg m "$message" \
    '{category:$c, severity:$s, message:$m}' >> "$FINDINGS_FILE"
}
emit_rec() {
  local priority="$1" category="$2" title="$3" impact="$4"
  jq -nc \
    --arg p "$priority" --arg c "$category" --arg t "$title" \
    --argjson i "$impact" \
    '{priority:$p, category:$c, title:$t, impact_points:$i, command:"/commventional:commventional"}' \
    >> "$RECS_FILE"
}

# ------------------------------------------------------------------------
# Category 1: Conventional Commits (weight 0.50, start 100)
# ------------------------------------------------------------------------
subjects_file="$(mktemp -t commv-subjects.XXXXXX)"
git -C "$REPO_ROOT" log --no-merges -n 50 --pretty=format:'%s' >"$subjects_file" 2>/dev/null || true

total=$(wc -l <"$subjects_file")
total=${total:-0}

cc_score=100
CC_RE='^(feat|fix|chore|docs|refactor|test|perf|build|ci|style)(\([a-zA-Z0-9_.-]+(,[a-zA-Z0-9_.-]+)*\))?!?: .+'
if (( total < 5 )); then
  cc_score=50
  emit_finding "conventional-commits" "low" \
    "Only $total non-merge commit(s) in history — insufficient signal, scoring 50"
else
  matches=$(grep -cE "$CC_RE" "$subjects_file" 2>/dev/null; true)
  matches=${matches:-0}
  # Ratio computed in jq to avoid bash float arithmetic.
  ratio=$(jq -n --argjson m "$matches" --argjson t "$total" '$m/$t')
  # Thresholds (matches playbook):
  #   >=0.95 → keep 100
  #   0.80-0.94 → -10
  #   0.50-0.79 → -30
  #   <0.50    → -60
  ded=$(jq -rn --argjson r "$ratio" '
    if $r >= 0.95 then 0
    elif $r >= 0.80 then 10
    elif $r >= 0.50 then 30
    else 60 end')
  if (( ded > 0 )); then
    cc_score=$((cc_score - ded))
    pct=$(jq -rn --argjson r "$ratio" '($r*100) | round')
    emit_finding "conventional-commits" "$(severity_for "$ded")" \
      "Only $matches/$total recent commits ($pct%) match the conventional-commit regex"
  fi
fi
cc_score=$(clamp "$cc_score" 0 100)
rm -f "$subjects_file"

# ------------------------------------------------------------------------
# Category 2: Engineering Ownership (weight 0.30, start 100)
# ------------------------------------------------------------------------
# Count commits whose full body contains an automated Co-Authored-By
# trailer or a "Generated with Claude Code" marker. Each counts as one
# offense (deduction -10, cap 60).
bodies_file="$(mktemp -t commv-bodies.XXXXXX)"
# --pretty="%B%x00" delimits commits with NUL for robust counting.
git -C "$REPO_ROOT" log --no-merges -n 50 --pretty='format:%B%x00' >"$bodies_file" 2>/dev/null || true

eo_score=100
auto_trailers=$(grep -c 'Co-Authored-By:.*\(noreply@anthropic\.com\|claude\|Claude\|AI\|bot\)' "$bodies_file" 2>/dev/null; true)
auto_trailers=${auto_trailers:-0}
# Also catch "Generated with Claude Code" style auto-attribution
auto_marker=$(grep -c 'Generated with Claude Code' "$bodies_file" 2>/dev/null; true)
auto_marker=${auto_marker:-0}

trailer_ded=$((auto_trailers * 10))
trailer_ded=$(clamp "$trailer_ded" 0 60)
marker_ded=$((auto_marker * 10))
marker_ded=$(clamp "$marker_ded" 0 30)

if (( trailer_ded > 0 )); then
  eo_score=$((eo_score - trailer_ded))
  emit_finding "engineering-ownership" "$(severity_for "$trailer_ded")" \
    "$auto_trailers commit(s) carry automated Co-Authored-By trailers"
fi
if (( marker_ded > 0 )); then
  eo_score=$((eo_score - marker_ded))
  emit_finding "engineering-ownership" "$(severity_for "$marker_ded")" \
    "$auto_marker commit(s) contain 'Generated with Claude Code' marker"
fi
eo_score=$(clamp "$eo_score" 0 100)
rm -f "$bodies_file"

# ------------------------------------------------------------------------
# Category 3: Conventional Comments (weight 0.20)
# ------------------------------------------------------------------------
# We deliberately do NOT hit GitHub here. Network access is a determinism
# hazard and the playbook permits a default when no review signal is
# available. Score 100 with a low-severity info finding.
cmt_score=100
emit_finding "conventional-comments" "low" \
  "Review-comment signal not sampled (network-free audit); category defaults to 100"

# ------------------------------------------------------------------------
# Composite
# ------------------------------------------------------------------------
composite=$(jq -n \
  --argjson cc "$cc_score" --argjson eo "$eo_score" --argjson cmt "$cmt_score" \
  '($cc*0.50 + $eo*0.30 + $cmt*0.20) | round')
grade=$(grade_for "$composite")

if (( cc_score  < 75 )); then emit_rec "high"   "conventional-commits"  "Adopt conventional-commit subject-line format"        "$((75 - cc_score))"; fi
if (( eo_score  < 75 )); then emit_rec "high"   "engineering-ownership" "Stop auto-trailers / Generated-with-Claude markers"   "$((75 - eo_score))"; fi
if (( cmt_score < 75 )); then emit_rec "medium" "conventional-comments" "Adopt labeled review feedback"                        "$((75 - cmt_score))"; fi

# ------------------------------------------------------------------------
# Observation shaping (v2 sibling-audit contract)
# ------------------------------------------------------------------------
# Per ADR-005 §3 / sibling-audit-contract.md schema 2: emit a stable
# observations[] array alongside the legacy categories[] payload. Each
# observation's evidence is sourced from a measurement variable already
# computed above; the rubric stanza in references/rubric.md applies the
# scoring rule. Categories[] / composite_score / letter_grade /
# recommendations / plugin / dimension are byte-identical to v1.
#
# Default-init any variable that's only set inside a conditional branch
# above so the observation block is safe under set -u when the history
# is too thin (total < 5) or the relevant grep finds nothing.
: "${matches:=0}"
: "${total:=0}"
: "${auto_trailers:=0}"
: "${auto_marker:=0}"

# Conventional-commit ratio — 4dp deterministic, awk-computed. Zero
# denominator yields zero ratio (history < 5 commits, ratio meaningless).
obs_cc_ratio=$(awk -v n="$matches" -v d="$total" \
  'BEGIN { if (d > 0) printf "%.4f", n/d; else printf "0.0000" }')

# review-signal-presence is always false: the scorer is intentionally
# network-free and never samples GitHub review comments.
obs_review_present=false

jq -n \
  --argjson cc "$cc_score" --argjson eo "$eo_score" --argjson cmt "$cmt_score" \
  --argjson composite "$composite" \
  --arg grade "$grade" \
  --argjson cc_matches    "$matches" \
  --argjson cc_total      "$total" \
  --argjson cc_ratio      "$obs_cc_ratio" \
  --argjson trailer_count "$auto_trailers" \
  --argjson marker_count  "$auto_marker" \
  --argjson review_present "$obs_review_present" \
  --slurpfile findings "$FINDINGS_FILE" \
  --slurpfile recs     "$RECS_FILE" \
  '{
    "$schema_version": 2,
    plugin: "commventional",
    dimension: "commit-hygiene",
    categories: [
      {name:"Conventional Commits",  weight:0.50, score:$cc,
       findings: [$findings[] | select(.category=="conventional-commits")  | del(.category)]},
      {name:"Engineering Ownership", weight:0.30, score:$eo,
       findings: [$findings[] | select(.category=="engineering-ownership") | del(.category)]},
      {name:"Conventional Comments", weight:0.20, score:$cmt,
       findings: [$findings[] | select(.category=="conventional-comments") | del(.category)]}
    ],
    observations: [
      {
        id: "conventional-commit-ratio",
        kind: "ratio",
        evidence: {
          numerator: $cc_matches,
          denominator: $cc_total,
          ratio: $cc_ratio
        },
        summary: "\($cc_matches)/\($cc_total) recent non-merge commits match the conventional-commit regex"
      },
      {
        id: "auto-trailer-count",
        kind: "count",
        evidence: { count: $trailer_count },
        summary: "\($trailer_count) commit(s) carry automated Co-Authored-By trailers"
      },
      {
        id: "auto-attribution-marker-count",
        kind: "count",
        evidence: { count: $marker_count },
        summary: "\($marker_count) commit(s) contain a Generated-with-Claude-Code marker"
      },
      {
        id: "review-signal-presence",
        kind: "presence",
        evidence: { present: $review_present },
        summary: "Review-comment signal not sampled (scorer is network-free)"
      }
    ],
    composite_score: $composite,
    letter_grade:    $grade,
    recommendations: $recs
  }'
