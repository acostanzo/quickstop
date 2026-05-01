---
id: q3
plan: quickstop-dev-tooling
status: open
updated: 2026-05-01
---

# Q3 — Smith dogfood fixes (from 2b1 lintguini)

## Scope

Q1 (smith enhancements) merged as `962b766`. Q2 (hone enhancements)
merged as `5b2ec8c`. The first true smith dogfood — 2b1, scaffolding
`lintguini` against the lint-posture rubric dimension — landed as
PR #73 (merge commit `1f3e631`). The dogfood produced a clean
scaffold and surfaced six smith-side findings: one customer-facing
documentation bug, one substitution rough edge, and four UX/scope
issues. The lintguini-side corrections went out in PR #73; the
smith-side fixes (so future scaffolds emit the right text out of the
box) are queued here.

This ticket is not a redesign — it's a punch list. The architecture
Q1 shipped is sound. These are template polish, branch tightening,
and one open question about what dogfood actually means when the
harness blocks model invocation of skills marked
`disable-model-invocation: true`.

## Findings

### B1 — README template references a non-existent `data` field

`.claude/skills/smith/SKILL.md` Phase 3.6 sibling README template
emits the line *"The \`data\` field contains observations pronto's
rubric translates into a dimension score"* in the standalone-invocation
section. The v2 wire contract
(`plugins/pronto/references/sibling-audit-contract.md`) puts
observations at the top level under `observations[]` — there is no
`data` field. Customer-facing documentation bug; first reader to use
a smith-scaffolded sibling sees misleading copy.

**Fix:** Replace the offending line in the Phase 3.6 template with
*"The \`observations[]\` field carries entries pronto's rubric
translates into a dimension score."*

**Verify:** `grep -n 'data` field' .claude/skills/smith/SKILL.md`
returns no matches; subsequent dogfood-via-recipe scaffolds produce a
README whose standalone-invocation paragraph references
`observations[]`.

### U3 — `SIBLING_DIMENSION_LABEL` substitution produces dangling prose

`.claude/skills/smith/SKILL.md` Phase 3.2a sibling `SKILL.md`
template carries:

```yaml
description: Audit a target codebase for <SIBLING_DIMENSION_LABEL> depth
```

When the dimension label is a column header with slashes (e.g.
"Lint / format / language rules"), the substitution yields
`Audit a target codebase for Lint / format / language rules depth` —
which reads as dangling prose. Author has to hand-rephrase.

**Fix:** Either (a) rephrase the frame so any label slugs in
gracefully ("Audit the \`<SIBLING_DIMENSION_SLUG>\` dimension in a
target codebase"), (b) source the description from the user's free-text
Q1 answer instead of substituting the rubric column header, or (c)
emit a placeholder description and prompt the author to write one.
Author preference: (a) — slug substitution is mechanical and survives
any column-header phrasing.

**Verify:** scaffolding any sibling whose dimension column header
contains slashes produces a `description` field that reads as a
complete sentence.

### U1 — `disable-model-invocation: true` blocks model dogfood

Calling `Skill(smith, ...)` from a Claude Code agent returns
`Skill smith cannot be used with Skill tool due to
disable-model-invocation`. The 2b1 ticket prompt assumed the model
could "type `/smith`" but the agent harness refuses. Dogfood worked
around this by executing the SKILL.md recipe by hand — which produced
a clean scaffold but isn't what "the model invokes the skill" means.

**Decision needed, then document:** Is `disable-model-invocation: true`
on smith intentional (only humans run smith via real keyboard input)
or an oversight? If intentional, document the rationale and the
recipe-by-hand path in `.claude/skills/smith/SKILL.md` so future
self-dogfood attempts know the constraint. If not intentional, drop the
flag.

**Verify:** post-decision, either the flag is removed and
`Skill(smith, ...)` from an agent successfully runs the skill, or
the flag remains and SKILL.md's intro names the constraint.

### U2 — Phase 1 expert-context fanout may be sunk cost

`.claude/skills/smith/SKILL.md` Phase 1 dispatches
`/claudit:knowledge ecosystem` (or two parallel research subagents on
fallback) before any user-visible scaffolding. For 2b1, the dogfood
skipped Phase 1 entirely — the templates in Phase 3.1–3.6 are fully
self-contained, and research output would not have changed a single
character of any scaffolded file.

**Fix (proposal):** Run Phase 1 lazily — only when a free-text answer
exposes a gap the templates don't cover (e.g. a non-standard plugin
type, an unfamiliar dimension, or a user request smith doesn't have a
template for). Default path skips Phase 1; the expert-context branch
is reserved for the genuinely-novel case.

**Open question:** does Phase 1 ever influence scaffolded output in
the standard sibling/tool paths? If "no" empirically, the lazy
path is safe. If "sometimes," we need to know which inputs trigger
the difference before short-circuiting it.

**Verify:** scaffolding `/smith` against three standard cases
(sibling, tool with hooks-considered, tool without hooks) produces
byte-identical files with Phase 1 enabled vs. skipped.

### U4 — Phase 4.2 root README placement instruction is ambiguous

`.claude/skills/smith/SKILL.md` Phase 4.2 currently says: *"add a
new plugin section … after the last plugin entry with version
v0.1.0."* Two readings, both grammatical:

1. *"after the last plugin entry [whose version is] v0.1.0"* — places
   the new section after Towncrier (which is no longer the last
   plugin entry; that's currently Avanti).
2. *"after the last plugin entry [the new one has version] v0.1.0"* —
   places the new section at the end of the list.

The 2b1 dogfood picked reading (2). Both readings produce different
file layouts and the instruction doesn't discriminate.

**Fix:** Replace the line with *"Add as the last plugin entry."*

**Verify:** `grep -n 'last plugin entry' .claude/skills/smith/SKILL.md`
shows the rewritten unambiguous instruction.

### U5 — Q5 (Components) is misleading for siblings

`.claude/skills/smith/SKILL.md` Q5 offers Skills / Agents / MCP /
Reference files as a multi-select. For `IS_SIBLING=true`, both
`skills/audit/` and `agents/parse-<name>.md` are mandatory and
auto-created irrespective of what the user picks. Selecting "no
skills" doesn't suppress `audit` creation. The questionnaire offers
a choice it then ignores.

**Fix:** For siblings, either (a) skip Q5's Skills/Agents toggles
entirely with a one-line note that they're auto-included, or (b)
default-check both with a hint that they're required by the sibling
shape and can't be deselected.

**Verify:** running `/smith` with role=sibling never offers a path
that suppresses `skills/audit/SKILL.md` or
`agents/parse-<name>.md` creation.

### U6 — Marketplace.json edit anchor is fragile

`.claude/skills/smith/SKILL.md` Phase 4.1 says *"Use Edit to add the
entry — do not overwrite the entire file"* (correct guidance), but the
suggested `old_string` anchor depends on which plugin is currently
last in `marketplace.json`. Each new plugin shifts the anchor; the
template instruction needs updating in lockstep, and the dogfood saw
the model produce a brittle `old_string` referencing avanti's closing
brace.

**Fix:** Anchor on the structural closing of the `plugins` array
(e.g. `\n  ]\n}\n` at end-of-file or the closing `]` before
`marketplaceVersion`/`updated`/etc.) rather than on the last
plugin's content. Document the anchor explicitly in the Phase 4.1
guidance.

**Verify:** scaffolding two siblings back-to-back (without rewriting
smith between them) produces working `marketplace.json` edits both
times.

## Out of scope

- **`/smith inkwell` formal dogfood.** Inkwell is hand-implemented
  per its 2a1 spec, not regenerated by smith (per the dev-tooling plan
  gating clause). 2b1 was the first true dogfood; subsequent dogfoods
  ride along with future siblings and `audit`-extension work.
- **Templates for `:doctor` / `:fix` skills.** ADR-005 §2 / §4
  reservations remain; no contract.
- **Hook scaffolding.** Q1's invariant D (smith never scaffolds hooks)
  holds; no hook branch in the questionnaire is added by Q3.
- **Multi-dimension siblings.** Out-of-scope per Q1's deferred list;
  unchanged here.

## Acceptance

- All six findings either (a) addressed by a smith-side template edit
  with a concrete file diff, or (b) resolved by an explicit
  decision-and-documentation step (U1's `disable-model-invocation`
  question).
- Re-running the 2b1 recipe against a fresh sibling name (e.g.
  `/smith myaudit` with role=sibling, dimension=any-existing-rubric-row)
  produces a scaffold whose README references `observations[]`,
  whose `audit/SKILL.md` description reads as a complete sentence,
  and whose marketplace.json edit succeeds without hand-editing the
  anchor.
- Phase 1's lazy-path question is decided either way, with a
  one-paragraph rationale captured in SKILL.md.

## References

- PR #73 (the dogfood that produced these findings):
  https://github.com/acostanzo/quickstop/pull/73
- 2b1 ticket: `project/tickets/open/phase-2-2b1-lintguini-scaffold.md`
  (will move to closed/ once #73 merges; effectively closed by this
  ticket's creation)
- Q1 ticket: `project/tickets/closed/quickstop-dev-tooling-q1-smith-enhancements.md`
- Q2 ticket: `project/tickets/closed/quickstop-dev-tooling-q2-hone-enhancements.md`
- Smith today: `.claude/skills/smith/SKILL.md`
- Wire contract: `plugins/pronto/references/sibling-audit-contract.md`
- ADR-005: `project/adrs/005-sibling-skill-conventions.md`
- ADR-006: `project/adrs/006-plugin-responsibility-boundary.md`
