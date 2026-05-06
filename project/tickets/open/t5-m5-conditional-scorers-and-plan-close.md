---
id: t5
plan: lintguini-expansion
status: open
updated: 2026-05-06
---

# t5 — Conditional audit scorers + plan close

## Context

The M5 milestone — wires the conditional audit scorers and closes the plan. Two scorers land:

- **`scorers/score-lint-pass-rate.sh`** (required) — actually runs the configured linter on the consumer repo and grades the pass rate. Gated on lintguini-config presence (detected via M1's `lintguini-detect-language.sh`); empty-scope on non-lintguini consumers, preserving today's audit semantics.
- **`scorers/score-suppression-staleness.sh`** (stretch) — flags suppressions for rules that no longer fire. Same gating.

In the same milestone: bump `plugin.json` `version` from `0.4.1` → `0.5.0`, update `marketplace.json` and root `README.md` to match, run `./scripts/check-plugin-versions.sh`, and promote the plan from `plans/active/` to `plans/done/`.

The architectural rationale (rubric-as-authority) lives in ADR-008; this ticket implements its consequence — the new conditional scorers grade against the rubric, not against lintguini-internal definitions. Implements the "Tickets" T5 row, "Definition of done", and acceptance bar A4 of `project/plans/active/lintguini-expansion.md`.

## Acceptance criteria

- `plugins/lintguini/scorers/score-lint-pass-rate.sh` exists, is executable, and follows the existing scorers' contract (one observation entry on stdout, empty-scope when gated).
- The pass-rate scorer is gated on lintguini-config presence: against a `lintguini-marked` fixture (configured by `/lintguini:configure`) it returns a non-empty observation with a numeric pass rate; against a `lintguini-plain` fixture (derived from `lintguini-marked` at test time by stripping the lintguini self-describing comment) it emits empty-scope.
- The `lintguini-plain` fixture is derived from `lintguini-marked` at test time, not maintained as a separate hand-edited fixture — A4 of the plan calls this out as the load-bearing assertion that catches drift.
- The four pre-T5 scorers' observations on `lintguini-plain` are byte-equivalent to today's 0.4.1 envelope captured in tests (envelope unchanged on non-lintguini consumers).
- (Stretch) `plugins/lintguini/scorers/score-suppression-staleness.sh` lands with the same gating; if it doesn't, it's documented as a follow-up rather than blocking M5.
- `plugins/lintguini/.claude-plugin/plugin.json` `version` is `"0.5.0"`.
- `.claude-plugin/marketplace.json` lintguini entry's `version` matches `0.5.0`; the `source` field is present and unchanged.
- Root `README.md` displays `lintguini` at version `0.5.0`.
- `./scripts/check-plugin-versions.sh` exits 0.
- `project/plans/active/lintguini-expansion.md` has been promoted to `project/plans/done/lintguini-expansion.md` (via `/avanti:promote plan:lintguini-expansion`); the file's frontmatter `status:` reads `done`.
- ADR-008 status remains `accepted` (set during the scaffolding PR; this ticket verifies it has not regressed).

## Notes

`score-lint-pass-rate.sh` consumes the `path:line:rule:message` finding shape locked in T3. If T3's contract drifted, this scorer breaks — the dependency is intentional and is why T3's acceptance criteria pin the contract inline in the SKILL.md.

A4 derivation: the plain fixture is generated from the marked fixture at test time by stripping the lintguini self-describing leading comment (the marker ADR-008 mandates). Maintaining two hand-edited fixtures invites drift; deriving one from the other guarantees that any regression in the marker logic surfaces immediately rather than masking behind divergent fixtures.

The plan-close step (`/avanti:promote plan:lintguini-expansion`) is the last action of the M5 dev-chat — once every other ticket is closed and every A-bar passes.

## Links

- Plan: `project/plans/active/lintguini-expansion.md` (see "Tickets" T5, "Definition of done", and acceptance bar A4)
- ADR: `project/adrs/008-lintguini-rubric-authority.md` (rubric-as-authority — the contract the new scorers grade against)
- Rubric: `plugins/pronto/references/roll-your-own/lint-posture.md`
- Quickstop marketplace rules: `CLAUDE.md` (the three-file version bump dance)
- Precedent: `project/plans/done/inkwell-expansion.md` T5 (parallel "conditional scorers + plan close" pattern)
