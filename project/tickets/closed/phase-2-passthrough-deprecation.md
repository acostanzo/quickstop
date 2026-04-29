---
id: passthrough-deprecation
plan: phase-2-pronto
status: closed
updated: 2026-04-29
---

# Back-compat passthrough deprecation (post-M3)

## Trigger

M1 (`#61`), M2 (`#62`), and M3 (`#63`) all merged on 2026-04-28. The audit reports' passthrough-count line now reads **`0/3 siblings scored via legacy passthrough — observations[] migration complete`**.

ADR-005 §3 and the H4 ticket both name this exact line as the trigger to deprecate the v1 composite_score passthrough rule. This ticket captures that follow-up.

## Scope

The translator (`plugins/pronto/agents/parsers/scorers/observations-to-score.sh`) currently falls through to v1 `composite_score` passthrough in three cases:

1. **Stanza missing** — no rubric stanza for the dimension. (Fall through with a stderr warning.)
2. **`$schema_version` absent / not `2`** — payload is a pure v1 envelope.
3. **`observations` field absent OR present-but-empty** — payload is v2 schema, but the sibling chose not to (or had nothing meaningful to) emit observations. (M2's empty-skills case and M3's thin-history case both deliberately ride this — see PR #62 / #63 for the empty-array pattern.)

The deprecation **only** removes case (2). Case (3) is the v2-native "no scope to score" signal and stays — empty `observations: []` MUST continue to fall through to v1 `composite_score`. Case (1) stays as a safety net for siblings that emit `observations[]` against an unregistered dimension (degraded, but not catastrophic).

After this lands, a v1-only payload (`$schema_version` field absent or != 2, no `observations` key) stops being scoreable. The translator emits a hard error rather than silently passing the legacy `composite_score` through. Every in-repo sibling (claudit, skillet, commventional) is already on v2 post-M1/M2/M3, so this is a no-op for shipped behaviour — but it closes the door on ever shipping a v1-only sibling again, and removes a permanent calibration-drift surface (a v1 sibling could ship a wildly different scoring scale than the rubric expects, and passthrough would let it through unchallenged).

## Changes

### `plugins/pronto/agents/parsers/scorers/observations-to-score.sh`

- Replace the v1-payload branch's `emit_passthrough "no observations[] present, falling through to v1"` with an explicit error: log `Error: payload missing $schema_version: 2 (got: <value>) — v1 passthrough deprecated as of <date>` to stderr, exit non-zero (suggest exit 4, distinct from the existing 2/3).
- Keep the `observations[]` present-but-empty branch's passthrough unchanged. Add a comment explicitly distinguishing the two: "Empty observations[] is a v2-native 'no scope' signal — the sibling chose not to score this run. Honour it."
- Update the helper's header comment to reflect the new contract.

### `plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh`

- Add a test asserting that a payload without `$schema_version: 2` exits non-zero with the expected error message.
- Update the "v1 passthrough" test to either:
  - use a v2 envelope with empty `observations: []` (still passes through), or
  - mark the v1-only test as expected-failure with the new contract.
- Confirm the empty-observations case test still passes unchanged.

### `plugins/pronto/references/rubric.md`

- Remove the "v1 `composite_score` passthrough" language wherever it appears as a fallback path. Replace with explicit pointers to the empty-observations[] signal as the only contract-supported way to score 0 / opt out.
- The trailing per-dimension passthrough notes ("When `claudit` migrates to native v2 emission..." etc) become stale and can be removed — the migration is complete.

### `plugins/pronto/skills/audit/SKILL.md` (Phase 4.1)

- Update the prose to drop the v1-passthrough description. The translator now requires `$schema_version: 2` on every sibling envelope.

### Audit report passthrough-count line

- Currently reads `N/3 siblings scored via legacy passthrough — ...`. Post-deprecation, the metric is meaningless (passthrough is always 0). Decide between:
  - Remove the line entirely.
  - Replace with a `siblings on v2 schema: 3/3` health line (cheap, unambiguous, useful for audit hygiene).

## Acceptance

- Translator exits non-zero on a v1-only payload (no `$schema_version`, no `observations`), with a stderr message naming the deprecated path.
- Translator still passes a v2 envelope with `observations: []` through to v1 `composite_score` (the M2/M3 empty-scope contract).
- All three in-repo siblings (claudit, skillet, commventional) score end-to-end via the rubric path on every fixture (clean, mid, noisy, empty-tempdir).
- Eval harness composite stddev still ≤ 1.0 across all three siblings; per-dim means within ±0.5 of post-M3 baseline (composite=61).
- `observations-to-score.test.sh` passes with all branches covered.
- `rubric.md` no longer mentions the v1-passthrough fallback as a contract.

## Out of scope

- Removing `composite_score` from sibling output. The siblings still emit `composite_score` as a categories[]-derived legacy field — the translator just stops *consuming* it as a scoring fallback. Keeping it on the wire is cheap and gives `pronto:replay` something readable for archived envelopes.
- Phase 2 sibling PRs (2a/2b/2c). Those plug into the v2-only path from day one regardless of this ticket.

## Estimated scope

**Small.** One conditional branch in `observations-to-score.sh`, one or two test cases, three doc edits, optionally one audit-report line refactor. No new code path, no calibration work.

## References

- `project/plans/active/phase-2-pronto.md` — Hardening group, post-H4 follow-ups.
- ADR-005 §3 — Original passthrough rule definition + sunset clause.
- `project/tickets/closed/phase-2-h4-observations-aware-scorer.md` — H4's "Out of scope" section names this ticket as the future deprecation work.
- `project/tickets/closed/phase-2-m{1,2,3}-*-observations-emission.md` — The migrations that drove passthrough-count to 0/3.
- PRs `#61` (M1), `#62` (M2), `#63` (M3) — sibling migration commits.
