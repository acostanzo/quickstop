---
name: audit
description: SDLC hygiene audit — scores plan freshness, ticket hygiene, ADR completeness, pulse cadence; emits pronto wire contract JSON under --json
argument-hint: "[--json]"
allowed-tools: Read, Bash, Glob, Grep
---

# /avanti:audit — SDLC hygiene audit

You are the `/avanti:audit` orchestrator. When the user runs `/avanti:audit`, walk `project/` and score four categories of SDLC hygiene — **plan freshness**, **ticket hygiene**, **ADR completeness**, **pulse cadence** — against thresholds from `${CLAUDE_PLUGIN_ROOT}/references/audit-thresholds.md`. Default output is a human-readable markdown scorecard. With `--json`, emit the pronto wire-contract JSON on stdout.

Avanti declares this audit in `plugin.json` under `pronto.audits` at dimension `project-record`, weight hint `0.05`. The output schema matches `plugins/pronto/references/sibling-audit-contract.md`.

## Phase 0: Parse and locate

### Step 1: Parse flags

- `--json` in `$ARGUMENTS` → set **JSON_MODE = true**. Else false.

### Step 2: Locate the repo root

Run `git rev-parse --show-toplevel 2>/dev/null`. Abort on failure. Store as **REPO_ROOT**.

### Step 3: Detect scaffold

If `${REPO_ROOT}/project/` does not exist, the repo isn't scaffolded. Emit a short diagnostic and exit cleanly:

- Markdown mode: "No `project/` directory in this repo. Run `/pronto:init` to scaffold, then re-run."
- JSON mode: emit a valid contract envelope with `composite_score: 0`, `letter_grade: "F"`, a single recommendation pointing at `/pronto:init`, and empty category findings.

### Step 4: Load thresholds

Read `${CLAUDE_PLUGIN_ROOT}/references/audit-thresholds.md`. Parse the thresholds table to get:

- **STALE_PLAN_DAYS** (default `60`)
- **TICKET_AGE_WARN_DAYS** (default `45`)
- **PULSE_CADENCE_WARN_DAYS** (default `30`)

If a per-repo `.avanti/config.json` override exists under REPO_ROOT, its `thresholds:` block takes precedence (keys not present fall back to reference defaults).

### Step 4b: Honor per-artifact overrides

Before any staleness, cadence, or ticket-age deduction runs in Phase 1, check the artifact's frontmatter for `audit_ignore: true`. If set, skip staleness/cadence deductions for that artifact but still include it in presence counts. Emit one **info**-severity finding per overridden artifact (under whichever category would have applied the deduction) of the form `"audit_ignore: true on <path> — staleness deductions skipped"` so consumers and reviewers can detect the pattern from the JSON envelope as well as the verbose markdown. See `references/audit-thresholds.md#overrides` for the semantics.

### Step 5: Resolve today

Run `date +%Y-%m-%d` → **TODAY**.

## Phase 1: Measure

Run measurements in parallel where feasible. For each category, produce a list of findings and a score 0-100.

### Category 1 — Plan freshness (weight 0.30)

Inputs: `project/plans/active/*.md`.

For each active plan, compute `days_since_touch`:

- Prefer `git log -1 --format=%cs -- <path>` for last-commit date.
- Fall back to frontmatter `updated:` if no git history.
- `days_since_touch = (TODAY - last_touched)` in whole days.

Findings:

- **high** — any active plan with `days_since_touch > STALE_PLAN_DAYS` → "Plan `<slug>` has been active for `<N>` days without a commit; consider promoting to `done/` or annotating why it's still active."
- **low** — if there are zero active plans in a repo that has at least one closed plan (`plans/done/` non-empty): no finding; empty-active after a done plan is fine.

Scoring:

- Start at 100.
- Deduct 20 per high finding, capped at -60.
- If there are no active plans at all, return 100 (vacuously clean).

### Category 2 — Ticket hygiene (weight 0.30)

Inputs: `project/tickets/open/*.md`, `project/tickets/closed/*.md`, `project/plans/*/*.md`.

For each open ticket, compute:

- `days_since_touch` (same as above, using git log or frontmatter `updated:`).
- Whether its `plan:` frontmatter resolves to an existing plan file under `project/plans/*/<plan-slug>.md`.
- If the resolved plan lives in `plans/done/`, flag the ticket as orphaned-after-done.

Findings:

- **critical** — ticket with no `plan:` frontmatter field, or `plan:` that doesn't resolve → "Ticket `<id>-<slug>` is not linked to any plan. Every ticket must belong to a plan."
- **high** — ticket whose plan lives in `plans/done/` → "Ticket `<id>-<slug>` is open but its plan `<plan-slug>` is done. Either close the ticket or move the plan back to active."
- **medium** — ticket with `days_since_touch > TICKET_AGE_WARN_DAYS` and `status: open` (not `in-progress`) → "Ticket `<id>-<slug>` has been open `<N>` days with no start. Consider moving to in-progress or closing."

Scoring:

- Start at 100.
- Deduct 30 per critical finding (capped at -90).
- Deduct 15 per high finding (capped at -60).
- Deduct 5 per medium finding (capped at -30).
- If there are zero open tickets, return 100.

### Category 3 — ADR completeness (weight 0.20)

Inputs: `project/adrs/*.md`.

For each ADR, read the body and check:

- Contains a non-empty `## Decision` section (not just a `TODO:` placeholder).
- If `status: superseded`, `superseded_by:` is non-null and references an existing ADR.
- If the frontmatter references `superseded_by: <id>`, that id's file exists.

Findings:

- **high** — ADR with `status: proposed` whose `## Decision` section is empty or TODO-only → "ADR `<NNN>-<slug>` is proposed but has no decision recorded. Either flesh out the decision or withdraw the ADR."
- **high** — superseded ADR with null or dangling `superseded_by:` → "ADR `<NNN>-<slug>` is marked superseded but `superseded_by:` is null or points to a non-existent ADR."
- **low** — ADR with `superseded_by:` pointing to an ADR that does not record `supersedes:` in reverse → "ADR `<NNN>-<slug>` supersedes `<target>` but the target ADR does not cross-link back."

Scoring:

- Start at 100.
- Deduct 15 per high finding (capped at -60).
- Deduct 5 per low finding (capped at -20).
- If there are zero ADRs, return 100 (vacuously clean — no ADRs means no hygiene problem).

### Category 4 — Pulse cadence (weight 0.20)

Inputs: `project/pulse/*.md`.

Find the most recent day-file (lexicographically max filename). Read its content and locate the most recent `## HH:MM` entry.

Compute:

- `days_since_last_entry = (TODAY - most_recent_day_file_date)`.
- Whether the pulse directory is empty (`project/pulse/` has no day-files).

Findings:

- **critical** — `project/pulse/` exists but is empty → "Pulse journal has never been written to. Log an entry with `/avanti:pulse`."
- **high** — `days_since_last_entry > PULSE_CADENCE_WARN_DAYS` → "Pulse journal is `<N>` days old (last entry `<date>`). Cadence threshold is `<T>` days."
- **low** — most recent day-file exists but is header-only (no `## HH:MM` entries) → "Most recent pulse day-file (`<date>.md`) has no entries."

Scoring:

- Start at 100.
- Empty pulse dir → score 0 (critical; cannot compute cadence).
- `days_since_last_entry > PULSE_CADENCE_WARN_DAYS` → deduct 20 for each block of `PULSE_CADENCE_WARN_DAYS` past the threshold, minimum 0.
- Header-only most-recent day-file → deduct 10.

## Phase 2: Composite + letter grade

```
composite_score = round(
  0.30 * plan_freshness_score +
  0.30 * ticket_hygiene_score +
  0.20 * adr_completeness_score +
  0.20 * pulse_cadence_score
)
```

Letter grade bands (matching the pronto contract):

| Score | Grade |
|---|---|
| 95-100 | A+ |
| 90-94 | A |
| 75-89 | B |
| 60-74 | C |
| 40-59 | D |
| 0-39 | F |

## Phase 3: Recommendations

Compile the top findings across all categories into a ranked recommendation list. Ordering: critical → high → medium → low. Within a priority tier, sort by category weight (so ticket hygiene / plan freshness recommendations surface before ADR / pulse recommendations at equal priority).

Each recommendation carries the wire-contract fields per `plugins/pronto/references/sibling-audit-contract.md` §`recommendations[]`: `priority`, `category` (the avanti subcategory the recommendation lifts — e.g. `Plan freshness`), `title` (short imperative), `impact_points` (estimated lift to that subcategory's score), and `command` where applicable (e.g. `/avanti:promote plan:<slug>`).

## Phase 4: Emit

### Markdown mode (default)

Print a scorecard:

```
╔═══════════════════════════════════════════════════════════════╗
║                AVANTI SDLC HYGIENE REPORT                    ║
╠═══════════════════════════════════════════════════════════════╣
║  Composite: <XX>/100    Grade: <G>                           ║
╚═══════════════════════════════════════════════════════════════╝

Plan freshness       ██████████████░░░░░░░░░░░  <XX>/100
Ticket hygiene       ██████████████░░░░░░░░░░░  <XX>/100
ADR completeness     ██████████████░░░░░░░░░░░  <XX>/100
Pulse cadence        ██████████████░░░░░░░░░░░  <XX>/100

FINDINGS
--------
<for each finding, grouped by category, ordered by severity>
  [<severity>] <file or "-"> — <message>

RECOMMENDATIONS
---------------
1. [<priority>] <action>
   <rationale>
2. …
```

For bars, use `█` filled and `░` empty; scale to 25 characters total; append `XX/100`.

### JSON mode (`--json`)

**Emit ONLY the JSON object to stdout. Nothing else.**

Hard rules (violating any of these breaks `jq` piping and is a test failure, not a style nit):

- No markdown code fences. Do not wrap the output in ` ```json ` / ` ``` `. The first byte on stdout must be `{` and the last must be `}`.
- No prose preamble, no trailing narrative, no debug prints.
- No blank line before or after the JSON object.
- Any diagnostic must go to **stderr** (`echo "..." >&2`) or be suppressed. Never to stdout.

If you are tempted to explain what you did, send it to stderr via `echo >&2` or omit it. The caller (pronto or another consumer) pipes stdout through a JSON parser without filtering — any extra byte is a bug.

Shape (per `plugins/pronto/references/sibling-audit-contract.md`; the example below documents the schema, **it is not a template to copy its fences from**):

```json
{
  "plugin": "avanti",
  "dimension": "project-record",
  "categories": [
    {
      "name": "Plan freshness",
      "weight": 0.30,
      "score": 80,
      "findings": [
        { "severity": "high", "message": "...", "file": "project/plans/active/foo.md" }
      ]
    },
    {
      "name": "Ticket hygiene",
      "weight": 0.30,
      "score": 70,
      "findings": []
    },
    {
      "name": "ADR completeness",
      "weight": 0.20,
      "score": 90,
      "findings": []
    },
    {
      "name": "Pulse cadence",
      "weight": 0.20,
      "score": 60,
      "findings": []
    }
  ],
  "composite_score": 75,
  "letter_grade": "B",
  "recommendations": [
    {
      "priority": "high",
      "category": "Plan freshness",
      "title": "Promote or annotate stale active plans",
      "impact_points": 6,
      "command": "/avanti:promote plan:<slug>"
    }
  ]
}
```

## Error handling

- **`project/` missing**: emit the degraded envelope (`composite_score: 0`, recommendation pointing at `/pronto:init`) and exit cleanly. Do not throw.
- **Thresholds file missing**: fall back to hardcoded defaults (60, 45, 30) and note in the report's preamble (markdown mode only; JSON stays clean).
- **Malformed frontmatter on an individual file**: log the path + parse error as a **low** finding under whichever category owns it; do not crash.
- **Git log unavailable for a file**: use `updated:` from frontmatter; do not fail the audit.
- **`.avanti/config.json` override is malformed**: fall back to reference defaults; log a low finding if malformed (markdown mode only) — don't contaminate the JSON shape.
