---
id: t1
plan: phase-1-followup-avanti
status: closed
updated: 2026-04-26
---

# T1 — Declare compatible_pronto and align audit emission to the v1 contract

## Context

Avanti Phase 1 PR #41 merged before pronto wired the `compatible_pronto` handshake (Phase 2 PR H1) and before ADR-005 ratified the sibling skill conventions. Pronto v0.2.0 now reads `compatible_pronto` from each sibling at audit dispatch and emits a soft finding when it's missing; pronto's `sibling-audit-contract.md` codifies finding/recommendation field names that avanti's audit skill diverges from.

This ticket is the alignment patch.

## What landed

### Plugin metadata

`plugins/avanti/.claude-plugin/plugin.json`:

- Added `compatible_pronto: ">=0.1.0"` to the `pronto` block.
- Bumped `version` 0.1.2 → 0.1.3.

`.claude-plugin/marketplace.json` and root `README.md` updated to reflect v0.1.3 per the repo's three-file version-bump convention.

### Wire-contract field rename in audit skill

`plugins/avanti/skills/audit/SKILL.md` — renamed every divergent field name to match `plugins/pronto/references/sibling-audit-contract.md`:

| Where | Was | Now (contract) |
|---|---|---|
| `findings[]` | `level` | `severity` |
| `findings[]` | `path` | `file` |
| `recommendations[]` | `action` | `title` |
| `recommendations[]` | `rationale` | (split into `command` + `category` + `impact_points`) |

Markdown scorecard label updated from `[<level>] <path>` to `[<severity>] <file>` for consistency. The recommendations rendering example was also brought across the rename — `1. [<priority>] <action>` / `   <rationale>` became `1. [<priority>] <title>  (+<impact_points> pts <category>)` / `   <command, if any>`. The prose paragraph on recommendations now references the contract directly.

### audit_ignore surfaces in JSON too

Step 4b previously surfaced `audit_ignore: true` overrides only in verbose markdown output. Promoted to also emit one **info**-severity JSON finding per overridden artifact under whichever category would have applied the deduction, so consumers (and pronto, eventually) can detect the pattern programmatically.

### A3 step 3 verification (structural + live)

**Structural trace** against current main:

```
=== Discovery & declaration ===
pronto version:           0.2.0
avanti version:           0.1.3
avanti.compatible_pronto: >=0.1.0
avanti claims dimension:  project-record
avanti audit_command:     /avanti:audit --json
skills/audit/SKILL.md:    yes  (ADR-005 §1)

=== Handshake ===
{"branch":"in_range","message":"pronto 0.2.0 satisfies sibling's compatible_pronto range '>=0.1.0'."}
```

**Live integration** — `claude --print --plugin-dir <pronto> --plugin-dir <avanti> --no-session-persistence --max-budget-usd 5.00 "/pronto:audit --json"` against a fresh fixture repo with both plugins side-loaded. The full pronto envelope embedded avanti's contract:

```json
{
  "dimension": "project-record",
  "weight": 5,
  "score": 100,
  "weighted_contribution": 5.0,
  "source": "sibling",
  "source_plugin": "avanti",
  "source_audit": {
    "plugin": "avanti",
    "dimension": "project-record",
    "categories": [ /* 4 entries: Plan freshness/Ticket hygiene/ADR completeness/Pulse cadence */ ],
    "composite_score": 100,
    "letter_grade": "A+",
    "recommendations": []
  },
  "notes": null
}
```

`sibling_integration_notes` for the run carried a single avanti entry confirming clean dispatch:

```
"avanti: dispatched via Skill tool, composite 100 (A+)."
```

And, contrasting against the three Phase-1-shipped siblings that have not yet declared `compatible_pronto`:

```
"claudit does not declare compatible_pronto; dispatching at sibling's risk per ADR-004 §2."
"skillet does not declare compatible_pronto; dispatching at sibling's risk per ADR-004 §2."
"commventional does not declare compatible_pronto; dispatching at sibling's risk per ADR-004 §2."
```

Avanti is the only sibling on this run that gets dispatched **without** a `compatible_pronto`-missing soft note — the value proposition of this ticket validated end-to-end. Pronto's project-record contribution lands at `weighted_contribution: 5.0` (full weight per the rubric), not the 50-cap kernel-presence fallback.

## Acceptance

- `compatible-pronto-check.sh "0.2.0" ">=0.1.0"` returns `branch: "in_range"` ✓
- Finding and recommendation field names in `skills/audit/SKILL.md` match the pronto contract ✓
- `./scripts/check-plugin-versions.sh` passes (avanti bumped 0.1.2 → 0.1.3) ✓
- `grep -nE '"level"|"path":|"action":|"rationale":|<action>|<rationale>|\[<level>\]' plugins/avanti/skills/audit/SKILL.md` → zero matches (covers both JSON keys and markdown placeholders) ✓
- Author-string grep on `plugins/avanti/` → zero matches ✓
- Project-record dispatch trace ends at `source: sibling` ✓

## Notes

The remaining Phase 2-shaped follow-up — migrating `/avanti:audit` to emit `observations[]` per ADR-005 §3 — is **blocked on pronto Phase 2 PR H3** (wire-contract `$schema_version: 2`). Per ADR-005 §3 back-compat, avanti's current `score` emission keeps working in the v2 world via pronto's passthrough rule, so there's no urgency. The next ticket gets queued the day H3 lands.

Pronto's `recommendations.json` still lists avanti at `plugin_status: phase-1b`. That's a pronto data-file change; flagging here for the pronto session to update on their next pass.

Latent bug found while filing this ticket: `/avanti:ticket`'s ID-collision check globs `project/tickets/*/${NEW_ID}-*.md` repo-wide, which would falsely block a new plan from minting its own `t1` whenever any other plan's `t1-*.md` already exists. The convention is plan-scoped IDs — the check should glob per-id then read frontmatter for `plan:` match, only aborting on same-plan reuse. Filing this as a separate ticket on the next pass; not bundled here to keep the follow-up focused. Ticket records hand-authored during this branch dodge the bug because the skill isn't invoked.

## Links

- Plan: `project/plans/active/phase-1-followup-avanti.md`
- Pronto wire contract: `plugins/pronto/references/sibling-audit-contract.md`
- ADR-004: `project/adrs/004-sibling-composition-contract.md`
- ADR-005: `project/adrs/005-sibling-skill-conventions.md`
- PR #41 (merged): https://github.com/acostanzo/quickstop/pull/41
