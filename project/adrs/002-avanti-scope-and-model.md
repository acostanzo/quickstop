---
id: 002
status: accepted
superseded_by: null
updated: 2026-04-21
---

# ADR 002 — Avanti's scope and model

## Context

The quickstop constellation needs an authority on SDLC records — plans, tickets, ADRs, and the pulse journal that live under `project/` in consumer repos. Pronto Phase 1 scaffolds the `project/` container but explicitly defers contents to "a sibling plugin to be named later." Three options were on the table:

1. Bundle the authoring skills into pronto itself. Pronto would own both the rubric/audit orchestration and the SDLC work.
2. Build a separate standalone repo (`acostanzo/avanti`) that ships on its own cadence, with its own marketplace registration, unrelated to quickstop.
3. Build avanti as a plugin inside `acostanzo/quickstop` — sibling to claudit, skillet, commventional, pronto — independent versioning, shared marketplace.

Compounding the choice: pronto's rubric includes a "Project record" dimension which is presence-only until an SDLC-specific auditor exists to measure depth. That auditor is naturally scoped to the same plugin that owns the authoring skills, which forced the scope choice to include "audit emission," not just authoring.

## Decision

We will build avanti as a plugin under `acostanzo/quickstop/plugins/avanti/`, sibling to pronto. It is the **SDLC work layer** of the constellation: it authors and maintains the records under `project/` and drives each record through its lifecycle. It also emits a pronto-contract-compliant audit on `--json` so pronto's "Project record" dimension picks up depth scoring the moment both plugins are installed.

The scope of avanti includes:

- Authoring skills for plans, tickets, ADRs, and pulse entries.
- A lifecycle skill (`/avanti:promote`) that drives all three stateful artifact types forward through their legal transitions.
- A status skill and a depth-audit skill.
- Templates, a conventions reference, and a thresholds reference.

The scope of avanti does **not** include: presence checks on `project/` (pronto's kernel), cross-repo aggregation, authoring skills for non-SDLC artifacts (release notes → towncrier; code docs → inkwell), or automatic artifact generation from chat transcripts.

## Consequences

### Positive

- Clear domain separation: pronto orchestrates and presence-checks; avanti authors and depth-scores. Each plugin's reason to change is distinct.
- Native wire-contract emission from day one — avanti's `plugin.json` declares its audit, setting the pattern other siblings will follow.
- Either pronto or avanti can land first; the two compose cleanly when both are installed.
- Independent versioning — avanti can iterate on SDLC conventions without pushing pronto releases.

### Negative

- Two plugins to install for the full SDLC experience. Mitigated by pronto's recommendation engine offering the install.
- Duplicated boilerplate (plugin.json, README, references/) across two closely-related plugins. Accepted as the cost of the split.

### Neutral

- `project/` container stays a pronto-scaffolded concept. Consumers touching only docs or code config never see avanti, and that is correct.
- Consumer repos with only pronto installed see "Project record: presence only — install avanti for depth scoring" in their audit. A gentle nudge, not a block.

## Alternatives considered

### Bundle into pronto

Rejected. Pronto's role is rubric + orchestration + kernel presence. Adding authoring skills and depth audit would make pronto the one-plugin-to-rule-them-all, conflicting with the delegation-to-siblings architecture that is the whole point of pronto's pivot from self-contained-template to meta-orchestrator.

### Separate repo (`acostanzo/avanti`)

Rejected. Splitting repos imposes coordination costs (cross-repo versioning, separate marketplace plumbing, shared CI absent) without any corresponding benefit. The two plugins are designed to ship together; they should live together.

### Defer avanti to Phase 2

Rejected. Pronto's "Project record" dimension is capped at 50 (presence-only) without avanti. Shipping pronto without avanti leaves the rubric permanently hobbled on that dimension. Pairing the two as Phase 1a / Phase 1b lets pronto land with a real depth score waiting in the wings.

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Sibling: `project/plans/active/phase-1-pronto.md`
- Related ADR: `project/adrs/003-lifecycle-state-machine.md` — the lifecycle model this plugin implements.
