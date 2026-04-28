#!/usr/bin/env bash
# Deterministic claudit parser.
#
# Emits the sibling-audit wire-contract JSON for the claude-code-config
# dimension by running pure shell measurements (wc, grep, jq) against
# <REPO_ROOT>. No LLM judgment is involved — the same repo state produces
# the same JSON bytes on every invocation.
#
# Usage:
#   score-claudit.sh <REPO_ROOT>
#
# Exit 0 on success (valid contract JSON on stdout). Exit 2 on argument
# or environment errors (message to stderr). Any other exit code is a
# bug in this script.

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

CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
SETTINGS="$REPO_ROOT/.claude/settings.json"
MCP="$REPO_ROOT/.mcp.json"

# Findings are collected as one JSON object per line, then streamed into
# category arrays by jq at the end. The category-name prefix keeps them
# routable without a second data structure.
FINDINGS_FILE="$(mktemp -t claudit-findings.XXXXXX.json)"
trap 'rm -f "$FINDINGS_FILE"' EXIT

emit_finding() {
  local category="$1" severity="$2" message="$3" file="${4:-}" line="${5:-}"
  jq -nc \
    --arg c "$category" --arg s "$severity" --arg m "$message" \
    --arg f "$file"    --arg l "$line" \
    '{category:$c, severity:$s, message:$m}
     + (if $f == "" then {} else {file:$f} end)
     + (if $l == "" then {} else {line:($l|tonumber)} end)
    ' >> "$FINDINGS_FILE"
}

# ------------------------------------------------------------------------
# Category 1: Over-Engineering Detection (weight 0.20, start 100)
# ------------------------------------------------------------------------
oe_score=100

claudemd_nb=$(nblines "$CLAUDE_MD")
if (( claudemd_nb > 200 )); then
  oe_score=$((oe_score - 20))
  emit_finding "over-engineering" "high" \
    "CLAUDE.md exceeds 200 non-blank lines ($claudemd_nb) — verbosity signal" \
    "CLAUDE.md" ""
fi

# Hook count — sum PreToolUse/PostToolUse/UserPromptSubmit/Stop etc. entries
# in .claude/settings.json if present. jq `.. | objects | .hooks?` traverses
# every matcher block.
hook_count=0
if [[ -f "$SETTINGS" ]]; then
  hook_count=$(jq '[.. | objects | .hooks? // empty | .[]?] | length' \
                  "$SETTINGS" 2>/dev/null || echo 0)
fi
if (( hook_count > 10 )); then
  oe_score=$((oe_score - 15))
  emit_finding "over-engineering" "medium" \
    "Hook count $hook_count exceeds 10 — hook sprawl signal" \
    ".claude/settings.json" ""
fi

# Prose restating built-in behavior. Fixed case-insensitive regex set so
# matches are byte-identical across runs. Cap deduction at 20.
oe_prose_matches=0
if [[ -f "$CLAUDE_MD" ]]; then
  oe_prose_matches=$(grep -ciE \
    '(use the (read|glob|grep|bash|write|edit) tool|claude should (read|use)|reads? files? (with|using) the read)' \
    "$CLAUDE_MD" 2>/dev/null; true)
  # grep -c exits non-zero on zero matches; ensure a single integer value.
  oe_prose_matches=${oe_prose_matches:-0}
fi
oe_prose_ded=$((oe_prose_matches * 5))
oe_prose_ded=$(clamp "$oe_prose_ded" 0 20)
if (( oe_prose_ded > 0 )); then
  oe_score=$((oe_score - oe_prose_ded))
  emit_finding "over-engineering" "$(severity_for "$oe_prose_ded")" \
    "CLAUDE.md restates built-in tool behavior ($oe_prose_matches match(es)) — deduction $oe_prose_ded" \
    "CLAUDE.md" ""
fi

oe_score=$(clamp "$oe_score" 0 100)

# ------------------------------------------------------------------------
# Category 2: CLAUDE.md Quality (weight 0.20, start 100)
# ------------------------------------------------------------------------
cq_score=100
if [[ ! -f "$CLAUDE_MD" ]]; then
  cq_score=0
  emit_finding "claudemd-quality" "high" \
    "CLAUDE.md missing at repo root" "CLAUDE.md" ""
else
  if (( claudemd_nb < 10 )); then
    cq_score=$((cq_score - 40))
    emit_finding "claudemd-quality" "critical" \
      "CLAUDE.md skeletal ($claudemd_nb non-blank lines, <10)" "CLAUDE.md" ""
  elif (( claudemd_nb > 200 )); then
    cq_score=$((cq_score - 20))
    emit_finding "claudemd-quality" "high" \
      "CLAUDE.md verbose ($claudemd_nb non-blank lines, >200)" "CLAUDE.md" ""
  fi

  # Arrival sections — case-insensitive keyword presence. Three keywords
  # mapped to three concerns; 5 points each if absent (cap 20).
  cq_missing_sections=0
  grep -qiE 'overview|architecture|what (is|this)' "$CLAUDE_MD" \
    || cq_missing_sections=$((cq_missing_sections + 1))
  grep -qiE 'test|tests|testing' "$CLAUDE_MD" \
    || cq_missing_sections=$((cq_missing_sections + 1))
  grep -qiE 'convention|guideline|style|format' "$CLAUDE_MD" \
    || cq_missing_sections=$((cq_missing_sections + 1))
  cq_section_ded=$((cq_missing_sections * 5))
  cq_section_ded=$(clamp "$cq_section_ded" 0 20)
  if (( cq_section_ded > 0 )); then
    cq_score=$((cq_score - cq_section_ded))
    emit_finding "claudemd-quality" "$(severity_for "$cq_section_ded")" \
      "CLAUDE.md missing $cq_missing_sections arrival section(s)" \
      "CLAUDE.md" ""
  fi
fi
cq_score=$(clamp "$cq_score" 0 100)

# ------------------------------------------------------------------------
# Category 3: Security Posture (weight 0.15, start 100)
# ------------------------------------------------------------------------
sec_score=100

if [[ -f "$SETTINGS" ]]; then
  default_mode=$(jq -r '.permissions.defaultMode // "missing"' "$SETTINGS" 2>/dev/null || echo "missing")
  if [[ "$default_mode" == "missing" || "$default_mode" == "bypassPermissions" ]]; then
    sec_score=$((sec_score - 20))
    emit_finding "security-posture" "high" \
      "permissions.defaultMode is '$default_mode'" \
      ".claude/settings.json" ""
  fi
  # Broad Bash(*) / Write(*) allows
  broad_count=$(jq '[.permissions.allow[]? | select(test("^(Bash|Write)\\(\\*\\)$"))] | length' \
                  "$SETTINGS" 2>/dev/null || echo 0)
  broad_ded=$((broad_count * 15))
  broad_ded=$(clamp "$broad_ded" 0 30)
  if (( broad_ded > 0 )); then
    sec_score=$((sec_score - broad_ded))
    emit_finding "security-posture" "$(severity_for "$broad_ded")" \
      "$broad_count broad Bash(*)/Write(*) allow entry(ies)" \
      ".claude/settings.json" ""
  fi
else
  # No settings.json → default mode is implicit "missing" → same -20
  sec_score=$((sec_score - 20))
  emit_finding "security-posture" "high" \
    "permissions.defaultMode not declared (no .claude/settings.json)" \
    ".claude/settings.json" ""
fi

# Secrets in instruction files (CLAUDE.md + any .claude/rules/**/*.md).
# Uses fixed regex set; one-shot -40 (not repeated per match).
SECRETS_RE='AWS_SECRET|AWS_SECRET_ACCESS_KEY|API_KEY *= *["'\''][^"'\'']+|password *= *["'\''][^"'\'']+'
secret_hit=0
if [[ -f "$CLAUDE_MD" ]] && grep -qE "$SECRETS_RE" "$CLAUDE_MD" 2>/dev/null; then
  secret_hit=1
fi
if [[ "$secret_hit" -eq 0 && -d "$REPO_ROOT/.claude/rules" ]]; then
  if grep -rqE "$SECRETS_RE" "$REPO_ROOT/.claude/rules" 2>/dev/null; then
    secret_hit=1
  fi
fi
if (( secret_hit == 1 )); then
  sec_score=$((sec_score - 40))
  emit_finding "security-posture" "critical" \
    "Possible secret literal detected in instruction files" "" ""
fi
sec_score=$(clamp "$sec_score" 0 100)

# ------------------------------------------------------------------------
# Category 4: MCP Configuration (weight 0.15, start 100)
# ------------------------------------------------------------------------
mcp_score=100
mcp_server_count=0
if [[ -f "$MCP" ]]; then
  mcp_server_count=$(jq '(.mcpServers // {}) | length' "$MCP" 2>/dev/null || echo 0)
  if (( mcp_server_count > 5 )); then
    mcp_score=$((mcp_score - 10))
    emit_finding "mcp-configuration" "medium" \
      "$mcp_server_count MCP servers declared (>5 sprawl signal)" \
      ".mcp.json" ""
  fi
  # Reachability: for each server with a scalar string `command`, check
  # that `command -v` resolves it. -15 per unreachable, cap 40. Absolute
  # paths are checked via `test -x`. Sorted by server key so output is
  # order-stable.
  mcp_unreach_ded=0
  while IFS=$'\t' read -r name cmd; do
    [[ -z "$name" ]] && continue
    if [[ "$cmd" == /* ]]; then
      if [[ ! -x "$cmd" ]]; then
        mcp_unreach_ded=$((mcp_unreach_ded + 15))
        emit_finding "mcp-configuration" "high" \
          "MCP server '$name' command '$cmd' not executable" ".mcp.json" ""
      fi
    elif [[ -n "$cmd" && "$cmd" != "null" ]]; then
      if ! command -v "$cmd" >/dev/null 2>&1; then
        mcp_unreach_ded=$((mcp_unreach_ded + 15))
        emit_finding "mcp-configuration" "high" \
          "MCP server '$name' command '$cmd' not on PATH" ".mcp.json" ""
      fi
    fi
  done < <(jq -r '(.mcpServers // {})
                   | to_entries
                   | sort_by(.key)
                   | .[]
                   | [.key, (.value.command // "")]
                   | @tsv' "$MCP" 2>/dev/null)
  mcp_unreach_ded=$(clamp "$mcp_unreach_ded" 0 40)
  mcp_score=$((mcp_score - mcp_unreach_ded))
fi
mcp_score=$(clamp "$mcp_score" 0 100)

# ------------------------------------------------------------------------
# Category 5: Plugin Health (weight 0.15, start 100)
# ------------------------------------------------------------------------
# Uses the fixture's own marketplace.json as the plugin inventory when
# present — this keeps the signal repo-scoped and host-independent
# (the original playbook read ~/.claude/plugins/installed_plugins.json,
# which tied variance to the host's global install state). Falls back to
# the host path only when the repo has no marketplace.
ph_score=100
ph_plugin_count=0
if [[ -f "$REPO_ROOT/.claude-plugin/marketplace.json" ]]; then
  ph_plugin_count=$(jq '(.plugins // []) | length' "$REPO_ROOT/.claude-plugin/marketplace.json" 2>/dev/null || echo 0)
  # Missing version field per plugin — check all (not "sample two") for
  # determinism. Cap 20.
  ph_missing=$(jq '[.plugins[]? | select((.version // null) == null)] | length' \
                 "$REPO_ROOT/.claude-plugin/marketplace.json" 2>/dev/null || echo 0)
  ph_missing_ded=$((ph_missing * 10))
  ph_missing_ded=$(clamp "$ph_missing_ded" 0 20)
  if (( ph_missing_ded > 0 )); then
    ph_score=$((ph_score - ph_missing_ded))
    emit_finding "plugin-health" "$(severity_for "$ph_missing_ded")" \
      "$ph_missing plugin entry(ies) missing 'version' field" \
      ".claude-plugin/marketplace.json" ""
  fi
elif [[ -f "$HOME/.claude/plugins/installed_plugins.json" ]]; then
  ph_plugin_count=$(jq '[.. | objects | select(has("version")) | .version] | length' \
                      "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null || echo 0)
fi
if (( ph_plugin_count > 10 )); then
  ph_score=$((ph_score - 10))
  emit_finding "plugin-health" "medium" \
    "$ph_plugin_count plugins inventoried (>10 sprawl signal)" "" ""
fi
ph_score=$(clamp "$ph_score" 0 100)

# ------------------------------------------------------------------------
# Category 6: Context Efficiency (weight 0.15, start 100)
# ------------------------------------------------------------------------
ce_score=100
agg_lines=0
agg_lines=$(( agg_lines + $(nblines "$CLAUDE_MD") ))
if [[ -d "$REPO_ROOT/.claude/rules" ]]; then
  while IFS= read -r -d '' f; do
    agg_lines=$(( agg_lines + $(nblines "$f") ))
  done < <(find "$REPO_ROOT/.claude/rules" -type f -name '*.md' -print0 2>/dev/null | sort -z)
fi
if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
  agg_lines=$(( agg_lines + $(nblines "$HOME/.claude/CLAUDE.md") ))
fi
if [[ -d "$HOME/.claude/rules" ]]; then
  while IFS= read -r -d '' f; do
    agg_lines=$(( agg_lines + $(nblines "$f") ))
  done < <(find "$HOME/.claude/rules" -type f -name '*.md' -print0 2>/dev/null | sort -z)
fi
if (( agg_lines > 1000 )); then
  ce_score=$((ce_score - 40))
  emit_finding "context-efficiency" "critical" \
    "$agg_lines aggregate instruction non-blank lines (>1000)" "" ""
elif (( agg_lines > 500 )); then
  ce_score=$((ce_score - 20))
  emit_finding "context-efficiency" "high" \
    "$agg_lines aggregate instruction non-blank lines (>500)" "" ""
fi

# Broken @import references — grep for `@<path>` style imports in
# CLAUDE.md; resolve each path, check existence. -5 each, cap 15.
broken_imports=0
if [[ -f "$CLAUDE_MD" ]]; then
  while IFS= read -r imp; do
    [[ -z "$imp" ]] && continue
    if [[ "$imp" == /* ]]; then
      [[ -f "$imp" ]] || broken_imports=$((broken_imports + 1))
    elif [[ "$imp" == ~* ]]; then
      resolved="${imp/#\~/$HOME}"
      [[ -f "$resolved" ]] || broken_imports=$((broken_imports + 1))
    else
      [[ -f "$REPO_ROOT/$imp" ]] || broken_imports=$((broken_imports + 1))
    fi
  done < <(grep -oE '@[^[:space:]]+\.md' "$CLAUDE_MD" 2>/dev/null | sed 's/^@//' | sort -u)
fi
imp_ded=$((broken_imports * 5))
imp_ded=$(clamp "$imp_ded" 0 15)
if (( imp_ded > 0 )); then
  ce_score=$((ce_score - imp_ded))
  emit_finding "context-efficiency" "$(severity_for "$imp_ded")" \
    "$broken_imports broken @import reference(s) in CLAUDE.md" \
    "CLAUDE.md" ""
fi
ce_score=$(clamp "$ce_score" 0 100)

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
# above so the observation block is safe under set -u when CLAUDE.md or
# .claude/settings.json is absent.
: "${cq_missing_sections:=0}"
: "${default_mode:=missing}"
: "${broad_count:=0}"

# Redundancy ratio — 4dp deterministic, awk-computed. Zero denominator
# yields zero ratio (CLAUDE.md absent or empty).
obs_redundancy_ratio=$(awk -v n="$oe_prose_matches" -v d="$claudemd_nb" \
  'BEGIN { if (d > 0) printf "%.4f", n/d; else printf "0.0000" }')
obs_default_mode_present=false
if [[ "$default_mode" != "missing" && "$default_mode" != "bypassPermissions" ]]; then
  obs_default_mode_present=true
fi

# ------------------------------------------------------------------------
# Assemble output
# ------------------------------------------------------------------------

# Weighted composite, rounded to int. jq's `round` is half-away-from-zero.
composite=$(jq -n \
  --argjson oe  "$oe_score" --argjson cq  "$cq_score" \
  --argjson s   "$sec_score" --argjson mcp "$mcp_score" \
  --argjson ph  "$ph_score"  --argjson ce  "$ce_score" \
  '($oe*0.20 + $cq*0.20 + $s*0.15 + $mcp*0.15 + $ph*0.15 + $ce*0.15) | round')
grade=$(grade_for "$composite")

# Recommendations — one per category that dropped below 75 (the B band).
RECS_FILE="$(mktemp -t claudit-recs.XXXXXX.json)"
trap 'rm -f "$FINDINGS_FILE" "$RECS_FILE"' EXIT
emit_rec() {
  local priority="$1" category="$2" title="$3" impact="$4"
  jq -nc \
    --arg p "$priority" --arg c "$category" --arg t "$title" \
    --argjson i "$impact" \
    '{priority:$p, category:$c, title:$t, impact_points:$i, command:"/claudit"}' \
    >> "$RECS_FILE"
}
if (( oe_score  < 75 )); then emit_rec "high"   "over-engineering"    "Trim CLAUDE.md / hook sprawl / builtin-restating prose"     "$((75 - oe_score))"; fi
if (( cq_score  < 75 )); then emit_rec "high"   "claudemd-quality"    "Raise CLAUDE.md substance or add missing arrival sections"  "$((75 - cq_score))"; fi
if (( sec_score < 75 )); then emit_rec "high"   "security-posture"    "Set explicit permissions.defaultMode and narrow allow list" "$((75 - sec_score))"; fi
if (( mcp_score < 75 )); then emit_rec "medium" "mcp-configuration"   "Resolve unreachable MCP server commands"                    "$((75 - mcp_score))"; fi
if (( ph_score  < 75 )); then emit_rec "medium" "plugin-health"       "Fill missing plugin 'version' fields"                       "$((75 - ph_score))"; fi
if (( ce_score  < 75 )); then emit_rec "medium" "context-efficiency"  "Trim aggregate instruction lines / fix broken @imports"     "$((75 - ce_score))"; fi

jq -n \
  --argjson oe  "$oe_score" --argjson cq  "$cq_score" \
  --argjson s   "$sec_score" --argjson mcp "$mcp_score" \
  --argjson ph  "$ph_score"  --argjson ce  "$ce_score" \
  --argjson composite "$composite" \
  --arg grade "$grade" \
  --argjson oe_prose_matches  "$oe_prose_matches" \
  --argjson claudemd_nb       "$claudemd_nb" \
  --argjson redundancy_ratio  "$obs_redundancy_ratio" \
  --argjson mcp_server_count  "$mcp_server_count" \
  --argjson default_mode_present "$obs_default_mode_present" \
  --arg     default_mode      "$default_mode" \
  --argjson broad_count       "$broad_count" \
  --argjson cq_missing_sections "$cq_missing_sections" \
  --slurpfile findings "$FINDINGS_FILE" \
  --slurpfile recs     "$RECS_FILE" \
  '{
    "$schema_version": 2,
    plugin: "claudit",
    dimension: "claude-code-config",
    categories: [
      {name:"Over-Engineering Detection", weight:0.20, score:$oe,
       findings: [$findings[] | select(.category=="over-engineering")   | del(.category)]},
      {name:"CLAUDE.md Quality",          weight:0.20, score:$cq,
       findings: [$findings[] | select(.category=="claudemd-quality")   | del(.category)]},
      {name:"Security Posture",           weight:0.15, score:$s,
       findings: [$findings[] | select(.category=="security-posture")   | del(.category)]},
      {name:"MCP Configuration",          weight:0.15, score:$mcp,
       findings: [$findings[] | select(.category=="mcp-configuration")  | del(.category)]},
      {name:"Plugin Health",              weight:0.15, score:$ph,
       findings: [$findings[] | select(.category=="plugin-health")      | del(.category)]},
      {name:"Context Efficiency",         weight:0.15, score:$ce,
       findings: [$findings[] | select(.category=="context-efficiency") | del(.category)]}
    ],
    observations: [
      {
        id: "claude-md-redundancy-ratio",
        kind: "ratio",
        evidence: {
          numerator: $oe_prose_matches,
          denominator: $claudemd_nb,
          ratio: $redundancy_ratio
        },
        summary: (if $claudemd_nb > 0
                  then "\($oe_prose_matches)/\($claudemd_nb) CLAUDE.md lines restate built-in tool behavior"
                  else "CLAUDE.md absent — no redundancy to assess"
                  end)
      },
      {
        id: "mcp-server-count",
        kind: "count",
        evidence: { configured: $mcp_server_count },
        summary: "\($mcp_server_count) MCP servers configured"
      },
      {
        id: "claude-md-line-count",
        kind: "count",
        evidence: { count: $claudemd_nb },
        summary: "\($claudemd_nb) non-blank lines in CLAUDE.md"
      },
      {
        id: "settings-default-mode-explicit",
        kind: "presence",
        evidence: { present: $default_mode_present },
        summary: (if $default_mode_present
                    then "permissions.defaultMode is set"
                    else "permissions.defaultMode is missing/bypass"
                  end)
      },
      {
        id: "broad-allow-glob-count",
        kind: "count",
        evidence: { count: $broad_count },
        summary: "\($broad_count) broad Bash(*)/Write(*) allow entries"
      },
      {
        id: "claude-md-arrival-section-missing-count",
        kind: "count",
        evidence: { count: $cq_missing_sections },
        summary: "\($cq_missing_sections) CLAUDE.md arrival section(s) missing"
      }
    ],
    composite_score: $composite,
    letter_grade:    $grade,
    recommendations: $recs
  }'
