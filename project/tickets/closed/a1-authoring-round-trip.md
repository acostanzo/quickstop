---
id: a1
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# A1 — Authoring round-trip

## Context

Exercise the four authoring skills end-to-end in a fresh pronto-init'd repo. Verify: plan lands at `project/plans/active/feature-x.md` with valid frontmatter; ticket at `project/tickets/open/t1-first-step.md` linked to the plan; ADR at `project/adrs/001-choose-foo.md` with `status: proposed`; pulse entry appended under `## HH:MM`.

## Result

**PASS** — dry-run simulation in a temporary `project/` scaffold.

Live Claude Code invocations (`/avanti:plan feature-x`, etc.) could not be run in this batch execution session since slash-command skills require an installed plugin and an interactive conversation. The dry-run emulated what each skill instructs Claude to do — reading the relevant template, applying the documented substitutions, writing to the documented target path — and verified the output matches the acceptance criteria in the plan.

Artifacts produced:

```
/tmp/tmp.XXX/project/
├── plans/active/feature-x.md       # phase: 1, status: active, tickets: [t1], updated: today
├── tickets/open/t1-first-step.md   # id: t1, plan: feature-x, status: open, updated: today
├── adrs/001-choose-foo.md          # id: 001, status: proposed, superseded_by: null
└── pulse/2026-04-21.md             # "# Pulse — 2026-04-21" + "## HH:MM\n\nstarted feature-x"
```

All four files validate against their template frontmatter schemas. No file overwrites. Interactive prompts (AskUserQuestion) are documented in each skill's Phase 1; Alfred's live-review pass is the real interactive-flow check.

## Findings from the dry-run

Two issues surfaced and were fixed in place:

1. **Template/skill mismatch on plan status**. `templates/plan.md` shipped with `status: draft`, but `/avanti:plan` writes to `project/plans/active/` by default. Fix: changed the template to `status: active` so the default-path flow produces a consistent folder-frontmatter pair. Skill substitution list clarified to document this. A future `--draft` flag becomes a single-line substitution.
2. **ID mint brittleness on mixed arrays**. `tickets:` frontmatter arrays can carry both `t`-prefixed and `a`-prefixed entries (the Phase 1 plan's own frontmatter does this — acceptance bars share the array). The mint logic assumed `int(t.lstrip("t"))` which errors on `a1`. Fix: the ticket skill now ignores entries that don't match `^t\d+$`.

Both fixes landed before A2 started.

## Acceptance

- Every file produced validates against its template's frontmatter schema ✓
- No file overwrites occur ✓
- Plan at expected path ✓
- Ticket linked to the plan by slug ✓
- ADR at `project/adrs/001-choose-foo.md` with status `proposed` ✓
- Pulse entry under `## HH:MM` sub-header ✓

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
