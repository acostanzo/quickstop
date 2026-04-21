---
id: a2
plan: phase-1-avanti
status: closed
updated: 2026-04-21
---

# A2 — Lifecycle round-trip

## Context

Exercise `/avanti:promote` against the A1 fixture. Round-trip a plan through `draft → active → done`; promote a ticket `open → closed`; promote an ADR `proposed → accepted`. At each step, verify the file lives at the folder the new state specifies, frontmatter `status:` matches the folder, `updated:` bumps to today, and a pulse entry records the transition.

## Result

**PASS** — dry-run simulation against the A1 fixture.

Transitions executed in order:

| # | Action | Current | Next | Outcome |
|---|---|---|---|---|
| 1 | `/avanti:promote plan:feature-x` | active | done | **Blocked by guard** — 1 open ticket (`t1-first-step`). Message: "Cannot promote plan to done: 1 ticket still open." |
| 2 | `/avanti:promote ticket:t1-first-step` | open | closed | File moved `open/ → closed/`; frontmatter updated; pulse entry appended at `## 19:20`. |
| 3 | `/avanti:promote plan:feature-x` | active | done | Guard now passes; file moved `active/ → done/`; frontmatter updated; pulse entry at `## 19:22`. |
| 4 | `/avanti:promote adr:001-choose-foo` | proposed | accepted | Flat folder unchanged; frontmatter `status: accepted`; pulse entry at `## 19:24`. |

Final fixture tree:

```
project/
├── adrs/001-choose-foo.md           # status: accepted, flat folder unchanged
├── plans/done/feature-x.md          # status: done, moved from active/
├── pulse/2026-04-21.md              # four ## HH:MM entries (started, ticket close, plan done, ADR accept)
└── tickets/closed/t1-first-step.md  # status: closed, moved from open/
```

## Findings from the dry-run

One finding surfaced and was fixed in place:

- **Missing plan active→done guard**. The promote skill as originally authored proposed `active → done` for any active plan without checking whether every ticket in the plan's `tickets:` frontmatter array was closed. The SDLC conventions reference already stated the rule ("A plan only leaves `active` when every ticket it owns is closed"), but the skill did not enforce it. Fix: added Step 3a in Phase 1 of the promote skill — scan `tickets:`, verify each corresponding file lives in `tickets/closed/`, block the promotion with a ticket-by-ticket error listing if any are not closed.

## Acceptance

- Round-trip produces correct folder + frontmatter at each step ✓
- `updated:` bumps to today at each transition ✓
- Pulse entry appended for every transition ✓
- ADR supersession path verified separately (flat folder; `--supersedes` required — covered in skill spec, not exercised here since no second ADR is needed for A2 as written)
- Illegal transitions (active→done with open tickets) errored clearly ✓

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Conventions: `plugins/avanti/references/sdlc-conventions.md#state-machines`
