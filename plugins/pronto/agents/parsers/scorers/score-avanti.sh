#!/usr/bin/env bash
# Deterministic avanti parser.
#
# Emits the sibling-audit wire-contract JSON for the project-record
# dimension by running pure shell measurements (find, awk, sed, grep, jq,
# git) against <REPO_ROOT>/project/. No LLM judgment is involved — the
# same repo state produces the same JSON bytes on every invocation.
#
# Mirrors avanti's `/avanti:audit --json` four-category scoring rubric
# (plan freshness, ticket hygiene, ADR completeness, pulse cadence) using
# the thresholds documented in plugins/avanti/references/audit-thresholds.md
# defaults: STALE_PLAN_DAYS=60, TICKET_AGE_WARN_DAYS=45,
# PULSE_CADENCE_WARN_DAYS=30. Per-repo `.avanti/config.json` overrides are
# honored. Per-artifact `audit_ignore: true` frontmatter overrides are
# honored.
#
# Usage:
#   score-avanti.sh <REPO_ROOT>
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

# ------------------------------------------------------------------------
# Thresholds
# ------------------------------------------------------------------------
STALE_PLAN_DAYS=60
TICKET_AGE_WARN_DAYS=45
PULSE_CADENCE_WARN_DAYS=30

CONFIG="$REPO_ROOT/.avanti/config.json"
if [[ -f "$CONFIG" ]]; then
  v=$(jq -r '.thresholds.STALE_PLAN_DAYS // empty' "$CONFIG" 2>/dev/null || true)
  [[ -n "$v" ]] && STALE_PLAN_DAYS=$v
  v=$(jq -r '.thresholds.TICKET_AGE_WARN_DAYS // empty' "$CONFIG" 2>/dev/null || true)
  [[ -n "$v" ]] && TICKET_AGE_WARN_DAYS=$v
  v=$(jq -r '.thresholds.PULSE_CADENCE_WARN_DAYS // empty' "$CONFIG" 2>/dev/null || true)
  [[ -n "$v" ]] && PULSE_CADENCE_WARN_DAYS=$v
fi

# TODAY uses UTC for determinism within a worktree-bound eval run.
TODAY="$(date -u +%Y-%m-%d)"
TODAY_EPOCH=$(date -u -d "$TODAY" +%s)

PROJECT="$REPO_ROOT/project"

FINDINGS_FILE="$(mktemp -t avanti-findings.XXXXXX.json)"
RECS_FILE="$(mktemp -t avanti-recs.XXXXXX.json)"
trap 'rm -f "$FINDINGS_FILE" "$RECS_FILE"' EXIT

# ------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------

emit_finding() {
  # category severity message [file]
  local category="$1" severity="$2" message="$3" file="${4:-}"
  jq -nc \
    --arg c "$category" --arg s "$severity" --arg m "$message" --arg f "$file" \
    '{category:$c, severity:$s, message:$m}
     + (if $f == "" then {} else {file:$f} end)' >> "$FINDINGS_FILE"
}

emit_rec() {
  # priority category title impact_points [command]
  local priority="$1" category="$2" title="$3" impact="$4" command="${5:-}"
  jq -nc \
    --arg p "$priority" --arg c "$category" --arg t "$title" \
    --argjson i "$impact" --arg cmd "$command" \
    '{priority:$p, category:$c, title:$t, impact_points:$i}
     + (if $cmd == "" then {} else {command:$cmd} end)' >> "$RECS_FILE"
}

# fm_field <path> <key>  →  print trimmed YAML frontmatter value, else empty.
fm_field() {
  local f="$1" k="$2"
  [[ -f "$f" ]] || { echo ""; return; }
  awk -v key="$k" '
    BEGIN { in_fm=0 }
    NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
    in_fm && /^---[[:space:]]*$/ { exit }
    in_fm {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      if (substr(line, 1, length(key)+1) == key ":") {
        v = substr(line, length(key)+2)
        sub(/^[[:space:]]+/, "", v)
        sub(/[[:space:]]+$/, "", v)
        gsub(/^"|"$/, "", v)
        print v
        exit
      }
    }
  ' "$f"
}

# date_of_file <path>  →  ISO date (YYYY-MM-DD), preferring git, falling back to fm `updated:`.
date_of_file() {
  local f="$1"
  local d
  d=$(cd "$REPO_ROOT" && git log -1 --format=%cs -- "$f" 2>/dev/null || true)
  if [[ -z "$d" ]]; then
    d=$(fm_field "$f" "updated")
  fi
  echo "$d"
}

# days_since <iso-date>  →  whole days from <iso-date> to TODAY. Empty/invalid → 0.
days_since() {
  local d="$1"
  [[ -z "$d" ]] && { echo 0; return; }
  local d_epoch
  d_epoch=$(date -u -d "$d" +%s 2>/dev/null) || { echo 0; return; }
  echo $(( (TODAY_EPOCH - d_epoch) / 86400 ))
}

# slug_of <path>  →  filename without `.md` extension.
slug_of() {
  local b
  b=$(basename "$1")
  echo "${b%.md}"
}

# audit_ignore <path>  →  prints "true" if frontmatter has `audit_ignore: true`, else empty.
audit_ignore() {
  local v
  v=$(fm_field "$1" "audit_ignore")
  if [[ "$v" == "true" ]]; then echo "true"; else echo ""; fi
}

# rel_path <abs-path>  →  path relative to REPO_ROOT.
rel_path() {
  local p="$1"
  echo "${p#"$REPO_ROOT/"}"
}

# decision_section_empty <adr-path>  →  "true" if `## Decision` is empty/TODO-only, else "".
decision_section_empty() {
  local f="$1"
  awk '
    BEGIN { in_sect=0; has_content=0 }
    /^## +Decision[[:space:]]*$/ { in_sect=1; next }
    in_sect && /^## / { exit }
    in_sect {
      line=$0
      gsub(/[[:space:]]+/, " ", line)
      sub(/^ /, "", line); sub(/ $/, "", line)
      if (line == "") next
      # TODO-only lines do not count as content.
      if (line ~ /^TODO/ || line ~ /^- *TODO/) next
      has_content=1
    }
    END { if (has_content==1) print "false"; else print "true" }
  ' "$f"
}

# ------------------------------------------------------------------------
# Scaffold check
# ------------------------------------------------------------------------

if [[ ! -d "$PROJECT" ]]; then
  # Degraded envelope per avanti's spec.
  jq -n \
    '{
      plugin: "avanti",
      dimension: "project-record",
      categories: [
        {name:"Plan freshness",    weight:0.30, score:0, findings:[]},
        {name:"Ticket hygiene",    weight:0.30, score:0, findings:[]},
        {name:"ADR completeness",  weight:0.20, score:0, findings:[]},
        {name:"Pulse cadence",     weight:0.20, score:0, findings:[]}
      ],
      composite_score: 0,
      letter_grade: "F",
      recommendations: [
        {
          priority:"critical",
          category:"scaffold",
          title:"Scaffold project/ with /pronto:init",
          impact_points:100,
          command:"/pronto:init"
        }
      ]
    }'
  exit 0
fi

# ------------------------------------------------------------------------
# Category 1: Plan freshness (weight 0.30)
# ------------------------------------------------------------------------
pf_score=100
pf_high_count=0
pf_active_count=0

if [[ -d "$PROJECT/plans/active" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    pf_active_count=$((pf_active_count + 1))
    slug=$(slug_of "$f")
    if [[ "$(audit_ignore "$f")" == "true" ]]; then
      emit_finding "plan-freshness" "info" \
        "audit_ignore: true on $(rel_path "$f") — staleness deductions skipped" \
        "$(rel_path "$f")"
      continue
    fi
    d=$(date_of_file "$f")
    n=$(days_since "$d")
    if (( n > STALE_PLAN_DAYS )); then
      pf_high_count=$((pf_high_count + 1))
      emit_finding "plan-freshness" "high" \
        "Plan \`$slug\` has been active for $n days without a commit; consider promoting to \`done/\` or annotating why it's still active." \
        "$(rel_path "$f")"
    fi
  done < <(find "$PROJECT/plans/active" -maxdepth 1 -type f -name '*.md' -print 2>/dev/null | sort)
fi

# Deduct 20 per high, capped at -60.
pf_ded=$((pf_high_count * 20))
pf_ded=$(clamp "$pf_ded" 0 60)
pf_score=$((pf_score - pf_ded))
pf_score=$(clamp "$pf_score" 0 100)

# Vacuous-clean rule: zero active plans → 100 (per avanti spec).
if (( pf_active_count == 0 )); then
  pf_score=100
fi

# ------------------------------------------------------------------------
# Category 2: Ticket hygiene (weight 0.30)
# ------------------------------------------------------------------------
th_score=100
th_crit=0
th_high=0
th_med=0
th_open_count=0

# Build set of plan slugs across active/ + done/ for plan-link resolution.
PLANS_INDEX=$(mktemp -t avanti-plans.XXXXXX)
trap 'rm -f "$FINDINGS_FILE" "$RECS_FILE" "$PLANS_INDEX"' EXIT
if [[ -d "$PROJECT/plans" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    plan_slug=$(slug_of "$f")
    plan_loc="active"
    [[ "$f" == */plans/done/* ]] && plan_loc="done"
    printf "%s\t%s\n" "$plan_slug" "$plan_loc" >> "$PLANS_INDEX"
  done < <(find "$PROJECT/plans" -maxdepth 2 -type f -name '*.md' -print 2>/dev/null | sort)
fi

if [[ -d "$PROJECT/tickets/open" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    th_open_count=$((th_open_count + 1))
    slug=$(slug_of "$f")
    plan_link=$(fm_field "$f" "plan")
    status=$(fm_field "$f" "status")

    # Plan link resolution.
    if [[ -z "$plan_link" ]]; then
      th_crit=$((th_crit + 1))
      emit_finding "ticket-hygiene" "critical" \
        "Ticket \`$slug\` is not linked to any plan. Every ticket must belong to a plan." \
        "$(rel_path "$f")"
    else
      plan_loc=""
      while IFS=$'\t' read -r pslug ploc; do
        if [[ "$pslug" == "$plan_link" ]]; then
          plan_loc=$ploc
          break
        fi
      done < "$PLANS_INDEX"
      if [[ -z "$plan_loc" ]]; then
        th_crit=$((th_crit + 1))
        emit_finding "ticket-hygiene" "critical" \
          "Ticket \`$slug\` references plan \`$plan_link\` which does not resolve to any file under \`project/plans/\`." \
          "$(rel_path "$f")"
      elif [[ "$plan_loc" == "done" ]]; then
        th_high=$((th_high + 1))
        emit_finding "ticket-hygiene" "high" \
          "Ticket \`$slug\` is open but its plan \`$plan_link\` is done. Either close the ticket or move the plan back to active." \
          "$(rel_path "$f")"
      fi
    fi

    # Age check (medium, only on status=open, not in-progress).
    if [[ "$(audit_ignore "$f")" == "true" ]]; then
      emit_finding "ticket-hygiene" "info" \
        "audit_ignore: true on $(rel_path "$f") — staleness deductions skipped" \
        "$(rel_path "$f")"
    elif [[ "$status" == "open" ]]; then
      d=$(date_of_file "$f")
      n=$(days_since "$d")
      if (( n > TICKET_AGE_WARN_DAYS )); then
        th_med=$((th_med + 1))
        emit_finding "ticket-hygiene" "medium" \
          "Ticket \`$slug\` has been open $n days with no start. Consider moving to in-progress or closing." \
          "$(rel_path "$f")"
      fi
    fi
  done < <(find "$PROJECT/tickets/open" -maxdepth 1 -type f -name '*.md' -print 2>/dev/null | sort)
fi

th_crit_ded=$((th_crit * 30)); th_crit_ded=$(clamp "$th_crit_ded" 0 90)
th_high_ded=$((th_high * 15)); th_high_ded=$(clamp "$th_high_ded" 0 60)
th_med_ded=$((th_med * 5));    th_med_ded=$(clamp "$th_med_ded"  0 30)
th_score=$((th_score - th_crit_ded - th_high_ded - th_med_ded))
th_score=$(clamp "$th_score" 0 100)
if (( th_open_count == 0 )); then
  th_score=100
fi

# ------------------------------------------------------------------------
# Category 3: ADR completeness (weight 0.20)
# ------------------------------------------------------------------------
adr_score=100
adr_high=0
adr_low=0
adr_count=0

declare -A ADR_BY_ID=()
declare -A ADR_SUPERSEDES=()

if [[ -d "$PROJECT/adrs" ]]; then
  # First pass: index ADRs by their numeric id (filename starts with NNN-).
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    adr_count=$((adr_count + 1))
    fb=$(basename "$f")
    if [[ "$fb" =~ ^([0-9]+)- ]]; then
      ADR_BY_ID["${BASH_REMATCH[1]}"]="$f"
    fi
    sup=$(fm_field "$f" "supersedes")
    [[ -n "$sup" ]] && ADR_SUPERSEDES["$f"]="$sup"
  done < <(find "$PROJECT/adrs" -maxdepth 1 -type f -name '*.md' -print 2>/dev/null | sort)

  # Second pass: per-ADR checks.
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    slug=$(slug_of "$f")
    status=$(fm_field "$f" "status")
    superseded_by=$(fm_field "$f" "superseded_by")

    # Decision section completeness on `proposed`.
    if [[ "$status" == "proposed" ]]; then
      empty=$(decision_section_empty "$f")
      if [[ "$empty" == "true" ]]; then
        adr_high=$((adr_high + 1))
        emit_finding "adr-completeness" "high" \
          "ADR \`$slug\` is proposed but has no decision recorded. Either flesh out the decision or withdraw the ADR." \
          "$(rel_path "$f")"
      fi
    fi

    # Superseded ADR with null/dangling superseded_by.
    if [[ "$status" == "superseded" ]]; then
      if [[ -z "$superseded_by" || "$superseded_by" == "null" ]]; then
        adr_high=$((adr_high + 1))
        emit_finding "adr-completeness" "high" \
          "ADR \`$slug\` is marked superseded but \`superseded_by:\` is null or missing." \
          "$(rel_path "$f")"
      else
        # Strip leading zeros for lookup (numeric id).
        sup_id="$superseded_by"
        sup_id="${sup_id##0}"; sup_id="${sup_id##0}"
        if [[ -z "${ADR_BY_ID[$superseded_by]:-}" && -z "${ADR_BY_ID[$sup_id]:-}" ]]; then
          adr_high=$((adr_high + 1))
          emit_finding "adr-completeness" "high" \
            "ADR \`$slug\` is marked superseded but \`superseded_by: $superseded_by\` does not match any ADR id." \
            "$(rel_path "$f")"
        fi
      fi
    fi

    # Reverse-link check: superseded_by points to ADR that doesn't list `supersedes:` back.
    if [[ -n "$superseded_by" && "$superseded_by" != "null" ]]; then
      # Find the target ADR file.
      target=""
      sup_id="$superseded_by"
      sup_id="${sup_id##0}"; sup_id="${sup_id##0}"
      target="${ADR_BY_ID[$superseded_by]:-${ADR_BY_ID[$sup_id]:-}}"
      if [[ -n "$target" ]]; then
        target_supersedes="${ADR_SUPERSEDES[$target]:-}"
        # Self id: leading numeric component of basename.
        own_id=""
        if [[ "$(basename "$f")" =~ ^([0-9]+)- ]]; then
          own_id="${BASH_REMATCH[1]}"
        fi
        if [[ -n "$own_id" && "$target_supersedes" != "$own_id" && "$target_supersedes" != "${own_id##0}" ]]; then
          adr_low=$((adr_low + 1))
          emit_finding "adr-completeness" "low" \
            "ADR \`$slug\` supersedes \`$superseded_by\` but the target ADR does not cross-link back via \`supersedes:\`." \
            "$(rel_path "$f")"
        fi
      fi
    fi
  done < <(find "$PROJECT/adrs" -maxdepth 1 -type f -name '*.md' -print 2>/dev/null | sort)
fi

adr_high_ded=$((adr_high * 15)); adr_high_ded=$(clamp "$adr_high_ded" 0 60)
adr_low_ded=$((adr_low * 5));    adr_low_ded=$(clamp "$adr_low_ded"  0 20)
adr_score=$((adr_score - adr_high_ded - adr_low_ded))
adr_score=$(clamp "$adr_score" 0 100)
if (( adr_count == 0 )); then
  adr_score=100
fi

# ------------------------------------------------------------------------
# Category 4: Pulse cadence (weight 0.20)
# ------------------------------------------------------------------------
pc_score=100

if [[ ! -d "$PROJECT/pulse" ]]; then
  # Pulse dir absent — treat as vacuously clean (the dir is created by /pronto:init).
  pc_score=100
else
  # Sorted day-files (YYYY-MM-DD.md style → lex sort = chronological sort).
  pulse_files=()
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    pulse_files+=("$f")
  done < <(find "$PROJECT/pulse" -maxdepth 1 -type f -name '*.md' -print 2>/dev/null | sort)

  if (( ${#pulse_files[@]} == 0 )); then
    pc_score=0
    emit_finding "pulse-cadence" "critical" \
      "Pulse journal has never been written to. Log an entry with \`/avanti:pulse\`." \
      "project/pulse/"
  else
    most_recent="${pulse_files[-1]}"
    mr_base=$(basename "$most_recent" .md)
    # Extract YYYY-MM-DD from filename if it matches; otherwise fall back to git/fm date.
    if [[ "$mr_base" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      mr_date="${BASH_REMATCH[1]}"
    else
      mr_date=$(date_of_file "$most_recent")
    fi
    n=$(days_since "$mr_date")

    # days past threshold (block-of-PULSE_CADENCE_WARN_DAYS)
    if (( n > PULSE_CADENCE_WARN_DAYS )); then
      blocks=$(( (n - PULSE_CADENCE_WARN_DAYS) / PULSE_CADENCE_WARN_DAYS + 1 ))
      ded=$((blocks * 20))
      pc_score=$((pc_score - ded))
      emit_finding "pulse-cadence" "high" \
        "Pulse journal is $n days old (last entry $mr_date). Cadence threshold is $PULSE_CADENCE_WARN_DAYS days." \
        "$(rel_path "$most_recent")"
    fi

    # Header-only check on most-recent day-file (no `## HH:MM` entries).
    if ! grep -qE '^##[[:space:]]+[0-9]{2}:[0-9]{2}' "$most_recent" 2>/dev/null; then
      pc_score=$((pc_score - 10))
      emit_finding "pulse-cadence" "low" \
        "Most recent pulse day-file ($mr_base.md) has no \`## HH:MM\` entries." \
        "$(rel_path "$most_recent")"
    fi
  fi
fi
pc_score=$(clamp "$pc_score" 0 100)

# ------------------------------------------------------------------------
# Composite + recommendations
# ------------------------------------------------------------------------
composite=$(jq -n \
  --argjson pf "$pf_score" --argjson th "$th_score" \
  --argjson adr "$adr_score" --argjson pc "$pc_score" \
  '($pf*0.30 + $th*0.30 + $adr*0.20 + $pc*0.20) | round')
grade=$(grade_for "$composite")

# One recommendation per category that dropped below 75.
if (( pf_score  < 75 )); then emit_rec "high"   "Plan freshness"     "Promote or annotate stale active plans"            "$((75 - pf_score))" "/avanti:promote plan:<slug>"; fi
if (( th_score  < 75 )); then emit_rec "high"   "Ticket hygiene"     "Resolve unlinked or orphaned tickets"              "$((75 - th_score))" "/avanti:close ticket:<slug>"; fi
if (( adr_score < 75 )); then emit_rec "medium" "ADR completeness"   "Complete proposed-ADR decisions or fix superseded_by links" "$((75 - adr_score))" ""; fi
if (( pc_score  < 75 )); then emit_rec "medium" "Pulse cadence"      "Log a pulse entry to refresh cadence"              "$((75 - pc_score))" "/avanti:pulse"; fi

# ------------------------------------------------------------------------
# Assemble output
# ------------------------------------------------------------------------
jq -n \
  --argjson pf "$pf_score" --argjson th "$th_score" \
  --argjson adr "$adr_score" --argjson pc "$pc_score" \
  --argjson composite "$composite" \
  --arg grade "$grade" \
  --slurpfile findings "$FINDINGS_FILE" \
  --slurpfile recs     "$RECS_FILE" \
  '{
    plugin: "avanti",
    dimension: "project-record",
    categories: [
      {name:"Plan freshness",    weight:0.30, score:$pf,
       findings: [$findings[] | select(.category=="plan-freshness")   | del(.category)]},
      {name:"Ticket hygiene",    weight:0.30, score:$th,
       findings: [$findings[] | select(.category=="ticket-hygiene")   | del(.category)]},
      {name:"ADR completeness",  weight:0.20, score:$adr,
       findings: [$findings[] | select(.category=="adr-completeness") | del(.category)]},
      {name:"Pulse cadence",     weight:0.20, score:$pc,
       findings: [$findings[] | select(.category=="pulse-cadence")    | del(.category)]}
    ],
    composite_score: $composite,
    letter_grade:    $grade,
    recommendations: $recs
  }'
