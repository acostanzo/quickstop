#!/usr/bin/env bash
# Deterministic skillet parser.
#
# Emits the sibling-audit wire-contract JSON for the skills-quality
# dimension by walking SKILL.md files under <REPO_ROOT> and applying
# fixed counted/regex-matched deductions per skill. No LLM judgment —
# the same filesystem produces the same JSON bytes every run.
#
# Usage:
#   score-skillet.sh <REPO_ROOT>
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

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq required" >&2
  exit 2
fi

# Collect SKILL.md files, sorted null-delimited for determinism across filesystems.
mapfile -d '' SKILLS_SORTED < <(
  { find "$REPO_ROOT/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 2>/dev/null
    find "$REPO_ROOT/plugins"        -mindepth 4 -maxdepth 4 -path '*/skills/*/SKILL.md' -print0 2>/dev/null
  } | sort -zu
)

# Empty-scope short-circuit.
if (( ${#SKILLS_SORTED[@]} == 0 )); then
  jq -n '{
    plugin: "skillet",
    dimension: "skills-quality",
    categories: [],
    composite_score: 0,
    letter_grade: "F",
    recommendations: [{
      priority: "low",
      title: "No skills present — author one with /skillet:build or roll your own per references/roll-your-own/skills-quality.md",
      command: "/skillet:build"
    }]
  }'
  exit 0
fi

FINDINGS_FILE="$(mktemp -t skillet-findings.XXXXXX.json)"
RECS_FILE="$(mktemp -t skillet-recs.XXXXXX.json)"
trap 'rm -f "$FINDINGS_FILE" "$RECS_FILE"' EXIT

emit_finding() {
  local category="$1" severity="$2" message="$3" file="${4:-}"
  jq -nc \
    --arg c "$category" --arg s "$severity" --arg m "$message" --arg f "$file" \
    '{category:$c, severity:$s, message:$m}
     + (if $f == "" then {} else {file:$f} end)' >> "$FINDINGS_FILE"
}

# Extract the YAML frontmatter block (between the first two `---` lines)
# from a SKILL.md and echo it. Empty output if no frontmatter.
frontmatter_of() {
  awk 'NR==1 && /^---$/ {infm=1; next} infm && /^---$/ {exit} infm {print}' "$1"
}

# Category totals, averaged across skills at the end. We track a cumulative
# score (float) and a per-skill count to support truncation to integer at
# emission time.
fm_total=0; iq_total=0; ad_total=0; ds_total=0; oe_total=0; rt_total=0
ad_counted=0  # Agent-Design is only scored on skills that dispatch subagents.

n=${#SKILLS_SORTED[@]}
for skill in "${SKILLS_SORTED[@]}"; do
  rel="${skill#$REPO_ROOT/}"
  fm="$(frontmatter_of "$skill")"
  lines=$(nblines "$skill")

  # ---- Frontmatter (start 100) ----
  fm_score=100
  if ! grep -qE '^name: *[^ ]' <<<"$fm"; then
    fm_score=$((fm_score - 40))
    emit_finding "frontmatter" "critical" "Missing 'name' in frontmatter ($rel)" "$rel"
  fi
  if ! grep -qE '^description: *[^ ]' <<<"$fm"; then
    fm_score=$((fm_score - 30))
    emit_finding "frontmatter" "high" "Missing 'description' in frontmatter ($rel)" "$rel"
  fi
  # allowed-tools: either the key is missing, or its value is the universe
  # (a literal `*` or absent list). Presence of the key with a concrete
  # scalar/array value passes.
  if ! grep -qE '^allowed-tools:' <<<"$fm"; then
    fm_score=$((fm_score - 20))
    emit_finding "frontmatter" "high" "Missing 'allowed-tools' in frontmatter ($rel)" "$rel"
  elif grep -qE '^allowed-tools: *["'"'"']?\*' <<<"$fm"; then
    fm_score=$((fm_score - 20))
    emit_finding "frontmatter" "high" "'allowed-tools: *' grants universal tool access ($rel)" "$rel"
  fi
  if ! grep -qE '^disable-model-invocation:' <<<"$fm"; then
    fm_score=$((fm_score - 10))
    emit_finding "frontmatter" "medium" "Missing 'disable-model-invocation' in frontmatter ($rel)" "$rel"
  fi
  fm_score=$(clamp "$fm_score" 0 100)
  fm_total=$((fm_total + fm_score))

  # ---- Instruction Quality (start 100) ----
  iq_score=100
  if (( lines < 20 )); then
    iq_score=$((iq_score - 40))
    emit_finding "instruction-quality" "critical" "Skeletal SKILL.md ($lines non-blank lines <20) ($rel)" "$rel"
  fi
  if (( lines > 100 )) && ! grep -qE '^(#+ +(Phase|Step))' "$skill" 2>/dev/null; then
    iq_score=$((iq_score - 20))
    emit_finding "instruction-quality" "high" "Unstructured long doc (no Phase/Step headings, $lines lines) ($rel)" "$rel"
  fi
  todo_count=$(grep -c 'TODO' "$skill" 2>/dev/null; true)
  todo_count=${todo_count:-0}
  todo_ded=$((todo_count * 10))
  todo_ded=$(clamp "$todo_ded" 0 30)
  if (( todo_ded > 0 )); then
    iq_score=$((iq_score - todo_ded))
    emit_finding "instruction-quality" "$(severity_for "$todo_ded")" \
      "SKILL.md contains $todo_count TODO marker(s) ($rel)" "$rel"
  fi
  iq_score=$(clamp "$iq_score" 0 100)
  iq_total=$((iq_total + iq_score))

  # ---- Agent Design (start 100, only if dispatch detected) ----
  dispatches=0
  if grep -qE '(subagent_type|Task tool|\bAgent tool\b|dispatch[a-z ]+(agent|subagent))' "$skill" 2>/dev/null; then
    dispatches=1
  fi
  if (( dispatches == 1 )); then
    ad_score=100
    plugin_dir="${skill%/skills/*}"
    if [[ ! -d "$plugin_dir/agents" ]]; then
      ad_score=$((ad_score - 30))
      emit_finding "agent-design" "high" \
        "Skill mentions dispatch but no agents/ dir ($rel)" "$rel"
    fi
    ad_score=$(clamp "$ad_score" 0 100)
    ad_total=$((ad_total + ad_score))
    ad_counted=$((ad_counted + 1))
  fi

  # ---- Directory Structure (start 100) ----
  ds_score=100
  # Convention: file must be at .../skills/<name>/SKILL.md (depth 2 under skills/).
  # Our Glob already restricts to that pattern, so the only way to fail is
  # having stray non-conforming files in the skill directory.
  skill_dir="$(dirname "$skill")"
  stray_count=0
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    case "$base" in
      .DS_Store|*.bak|tmp.*|*~) stray_count=$((stray_count + 1)) ;;
    esac
  done < <(find "$skill_dir" -maxdepth 1 -type f -print0 2>/dev/null | sort -z)
  stray_ded=$((stray_count * 5))
  stray_ded=$(clamp "$stray_ded" 0 15)
  if (( stray_ded > 0 )); then
    ds_score=$((ds_score - stray_ded))
    emit_finding "directory-structure" "$(severity_for "$stray_ded")" \
      "$stray_count stray file(s) in skill dir ($rel)" "$rel"
  fi
  if (( lines > 400 )) && [[ ! -d "$skill_dir/references" ]]; then
    ds_score=$((ds_score - 20))
    emit_finding "directory-structure" "high" \
      "SKILL.md over 400 lines with no references/ directory ($rel)" "$rel"
  fi
  ds_score=$(clamp "$ds_score" 0 100)
  ds_total=$((ds_total + ds_score))

  # ---- Over-Engineering (start 100) ----
  oe_score=100
  restated_matches=$(grep -ciE \
    '(read tool reads|use the (glob|grep|read|bash|write|edit) tool|claude should (read|use))' \
    "$skill" 2>/dev/null; true)
  restated_matches=${restated_matches:-0}
  restated_ded=$((restated_matches * 10))
  restated_ded=$(clamp "$restated_ded" 0 30)
  if (( restated_ded > 0 )); then
    oe_score=$((oe_score - restated_ded))
    emit_finding "over-engineering" "$(severity_for "$restated_ded")" \
      "SKILL.md restates built-in tool behavior ($restated_matches match(es)) ($rel)" "$rel"
  fi
  oe_score=$(clamp "$oe_score" 0 100)
  oe_total=$((oe_total + oe_score))

  # ---- Reference & Tooling (start 100) ----
  rt_score=100
  # Broken references/X.md mentions. Resolution order: skill-local
  # `./references/X.md` first, then plugin-level `<plugin>/references/X.md`.
  # Only count as broken if neither resolves.
  plugin_dir="${skill%/skills/*}"
  broken_refs=0
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    if [[ -f "$skill_dir/$ref" ]]; then
      continue
    fi
    if [[ -f "$plugin_dir/$ref" ]]; then
      continue
    fi
    broken_refs=$((broken_refs + 1))
  done < <(grep -oE 'references/[A-Za-z0-9_./-]+\.md' "$skill" 2>/dev/null | sort -u)
  ref_ded=$((broken_refs * 20))
  ref_ded=$(clamp "$ref_ded" 0 40)
  if (( ref_ded > 0 )); then
    rt_score=$((rt_score - ref_ded))
    emit_finding "reference-tooling" "$(severity_for "$ref_ded")" \
      "$broken_refs broken references/ pointer(s) ($rel)" "$rel"
  fi
  rt_score=$(clamp "$rt_score" 0 100)
  rt_total=$((rt_total + rt_score))
done

# Averages. Agent Design is weighted redistribution: if no skill dispatched,
# treat category as neutral 100 so it doesn't drag the composite.
fm_avg=$(( fm_total / n ))
iq_avg=$(( iq_total / n ))
ad_avg=100
if (( ad_counted > 0 )); then
  ad_avg=$(( ad_total / ad_counted ))
fi
ds_avg=$(( ds_total / n ))
oe_avg=$(( oe_total / n ))
rt_avg=$(( rt_total / n ))

composite=$(jq -n \
  --argjson fm "$fm_avg" --argjson iq "$iq_avg" --argjson ad "$ad_avg" \
  --argjson ds "$ds_avg" --argjson oe "$oe_avg" --argjson rt "$rt_avg" \
  '($fm*0.20 + $iq*0.20 + $ad*0.15 + $ds*0.15 + $oe*0.15 + $rt*0.15) | round')
grade=$(grade_for "$composite")

emit_rec() {
  local priority="$1" category="$2" title="$3" impact="$4"
  jq -nc \
    --arg p "$priority" --arg c "$category" --arg t "$title" \
    --argjson i "$impact" \
    '{priority:$p, category:$c, title:$t, impact_points:$i, command:"/skillet:audit"}' \
    >> "$RECS_FILE"
}
if (( fm_avg < 75 )); then emit_rec "high"   "frontmatter"         "Fill missing frontmatter fields across skills" "$((75 - fm_avg))"; fi
if (( iq_avg < 75 )); then emit_rec "high"   "instruction-quality" "Expand or structure thin/unstructured SKILL.md files" "$((75 - iq_avg))"; fi
if (( ad_avg < 75 )); then emit_rec "medium" "agent-design"        "Fix dispatch declarations (missing agents/ dir)" "$((75 - ad_avg))"; fi
if (( ds_avg < 75 )); then emit_rec "medium" "directory-structure" "Remove stray files and split oversized skills" "$((75 - ds_avg))"; fi
if (( oe_avg < 75 )); then emit_rec "medium" "over-engineering"    "Remove restated built-in tool instructions" "$((75 - oe_avg))"; fi
if (( rt_avg < 75 )); then emit_rec "high"   "reference-tooling"   "Fix broken references/ pointers" "$((75 - rt_avg))"; fi

jq -n \
  --argjson fm "$fm_avg" --argjson iq "$iq_avg" --argjson ad "$ad_avg" \
  --argjson ds "$ds_avg" --argjson oe "$oe_avg" --argjson rt "$rt_avg" \
  --argjson composite "$composite" \
  --arg grade "$grade" \
  --slurpfile findings "$FINDINGS_FILE" \
  --slurpfile recs     "$RECS_FILE" \
  '{
    plugin: "skillet",
    dimension: "skills-quality",
    categories: [
      {name:"Frontmatter",          weight:0.20, score:$fm,
       findings: [$findings[] | select(.category=="frontmatter")         | del(.category)]},
      {name:"Instruction Quality",  weight:0.20, score:$iq,
       findings: [$findings[] | select(.category=="instruction-quality") | del(.category)]},
      {name:"Agent Design",         weight:0.15, score:$ad,
       findings: [$findings[] | select(.category=="agent-design")        | del(.category)]},
      {name:"Directory Structure",  weight:0.15, score:$ds,
       findings: [$findings[] | select(.category=="directory-structure") | del(.category)]},
      {name:"Over-Engineering",     weight:0.15, score:$oe,
       findings: [$findings[] | select(.category=="over-engineering")    | del(.category)]},
      {name:"Reference & Tooling",  weight:0.15, score:$rt,
       findings: [$findings[] | select(.category=="reference-tooling")   | del(.category)]}
    ],
    composite_score: $composite,
    letter_grade:    $grade,
    recommendations: $recs
  }'
