---
id: m1
plan: phase-2-pronto
status: closed
updated: 2026-04-28
---

# M1 — Claudit observations[] emission

## Scope

H4 (merged) shipped pronto's observations-aware scorer plus the
`claude-code-config` rubric stanza calibrated against `score-claudit.sh`'s
v1 emission. With H4 alone, claudit still emits v1-shaped JSON
(`composite_score`, `categories[]`, no `observations[]`); the translator's
back-compat passthrough rule routes the v1 score through unchanged. M1
moves claudit to v2 emission so the rubric-derived score path is
exercised end-to-end on the harness fixture.

The migration target is **`plugins/pronto/agents/parsers/scorers/score-claudit.sh`**
— pronto's deterministic scorer for the claude-code-config dimension. The
LLM-driven `/claudit` slash command in
`plugins/claudit/skills/claudit/SKILL.md` is a separate banner-style
health-report orchestrator and is **not** modified by this ticket.

## Architecture

A pre-implementation survey on `survey/m1-claudit-observations` produced
`/tmp/m1-claudit-design.md` with the structural shape, observation IDs,
and calibration verification. Recap of the load-bearing pieces:

### `score-claudit.sh` becomes a v2 emitter

The script keeps every existing measurement and category emission. A
new `observations[]` block is added to the final `jq -n` envelope-build
step, alongside `categories[]`. The five rubric-registered observation
IDs map to existing shell variables in the script:

| Observation ID | Kind | Source variable | Evidence shape |
|---|---|---|---|
| `claude-md-redundancy-ratio` | ratio | `oe_prose_matches`, `claudemd_nb` | `{numerator, denominator, ratio}` |
| `mcp-server-count` | count | `mcp_server_count` | `{configured: N}` |
| `claude-md-line-count` | count | `claudemd_nb` | `{count: N}` |
| `settings-default-mode-explicit` | presence | `default_mode != "missing"/"bypassPermissions"` | `{present: bool}` |
| `broad-allow-glob-count` | count | `broad_count` | `{count: N}` |
| `claude-md-arrival-section-missing-count` | count | `cq_missing_sections` (new rubric ID — see below) | `{count: N}` |

The envelope also gains `"$schema_version": 2` at the top level. v1
fields (`plugin`, `dimension`, `categories`, `composite_score`,
`letter_grade`, `recommendations`) stay byte-identical.

### Rubric stanza calibration adjustments

The H4-shipped `claude-code-config` stanza in `rubric.md` mis-calibrates
on the harness `mid` fixture (rubric→76, score-claudit→96, 20-pt
drift). Two stanza adjustments converge the rubric path on
score-claudit's path within ±1 across `clean`, `mid`, `noisy` (verified
empirically during the survey):

1. **`mcp-server-count` band** — `else: 0` punishes "no `.mcp.json`
   present" while score-claudit treats it as MCP=100. Change `else: 0`
   → `else: 100`; drop the redundant `gte: 1 → 100` band. Final shape:
   `[{gte: 6, score: 50}, {else: 100}]`.
2. **New observation: `claude-md-arrival-section-missing-count`** — kind:
   count, ladder bands `[{gte: 3, score: 80}, {gte: 1, score: 95},
   {else: 100}]`. Models the `cq_missing_sections` deduction from
   score-claudit's CQ category. Without it, the rubric ignores the
   1-section gap on mid that drops score-claudit to 96.

These calibration changes ride in the same M1 PR as the emission code —
the rubric stanza and the emitter must agree on the observation ID set
or the translator drops the new ID with a "no rubric rule registered"
warning.

### Discovery path stays at step 2

ADR-005 §5 specifies a future migration where claudit gets a
`plugins/claudit/skills/audit/SKILL.md` and pronto resolves dispatch at
step 1 instead of step 2 (recommendations.json's `audit_command`
parser pointer). M1 does **not** ship that migration — it stays in
the score-claudit.sh + parser-agent + recommendations.json path.
Filing a follow-up M1.5 (skill-name migration) is recommended once M1
proves stable.

## Implementation order

1. **`plugins/pronto/references/rubric.md`** — apply the two calibration
   adjustments to the `claude-code-config` translation stanza
   (mcp-server-count `else: 100`; add
   `claude-md-arrival-section-missing-count`).
2. **`plugins/pronto/agents/parsers/scorers/score-claudit.sh`** — extend
   the final `jq -n` step to emit `observations[]` with the six IDs
   above. Add `"$schema_version": 2` at the top level. Confirm
   `categories[]` and the other v1 fields are byte-identical to
   pre-change for each fixture (use the snapshots below).
3. **`plugins/claudit/test-fixtures/snapshots/`** — already staged on
   the survey branch with `clean`, `mid`, `noisy` envelopes plus the
   synthetic input directories for clean/noisy. Move from the survey
   branch to M1's branch as test infrastructure for invariant B.
4. **`plugins/claudit/test-fixtures/snapshots/snapshots.test.sh`** — new
   regression test: for each fixture, run the (new) `score-claudit.sh`
   and diff the `categories[]` and other v1-projected fields against
   the staged snapshot. Confirms invariant B (categories[]
   byte-identity) and invariant A by mechanical proxy (scorer output is
   the wire payload; the LLM skill is untouched).
5. **`plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh`** —
   add a fixture-scoped case for the six-observation
   claude-code-config shape so the harness can spot calibration drift
   if the stanza or emission gets edited later.
6. **Eval harness on `mid`** — run with `N=20` against the H4-closeout
   baseline. Acceptance: composite stddev ≤ 1.0; per-dimension
   `claude-code-config` mean within ±0.5 of H4 baseline. (After the
   stanza fixes the deterministic dimension score is 96, matching
   today's path; the harness composite is unchanged.)

## Acceptance

- All six observation IDs emit on every run with deterministic evidence
  shape; `score-claudit.sh` exit code unchanged.
- `categories[]`, `plugin`, `dimension`, `composite_score`,
  `letter_grade`, `recommendations` byte-identical to pre-M1 snapshots
  for `clean`/`mid`/`noisy` fixtures.
- Translator (`observations-to-score.sh`) on the M1-emitted envelope
  produces a `composite_score` within ±1 of `score-claudit.sh`'s
  `composite_score` on each fixture.
- Eval harness on `mid` (N=20): composite stddev ≤ 1.0; per-dimension
  `claude-code-config` mean within ±0.5 of the H4-closeout baseline
  (composite=61, all-dim stddev=0).
- `plugins/claudit/skills/claudit/SKILL.md` and the rest of
  `plugins/claudit/skills/**` are unchanged in the diff.
- Audit-level passthrough summary line emitted by Phase 5 reads
  `<n-1>/<n> siblings scored via legacy passthrough — observations[]
  migration pending` after M1 ships (one fewer passthrough than today).

## Out of scope

- **Skill-name migration to `claudit:audit`.** ADR-005 §1's eventual
  discovery target. Filed as M1.5 follow-up.
- **Skillet observations migration (M2).** Independent ticket; same
  pattern, different sibling.
- **Commventional observations migration (M3).** Same.
- **Deprecating the back-compat passthrough rule.** Fires once M1 +
  M2 + M3 ship and the passthrough summary line reads `0/3`. Separate
  work cycle, tracked in `phase-2-pronto.md` under "Post-Phase-2 —
  legacy sibling migration."
- **Rebasing the redundancy-ratio observation as a count.** Survey
  identified that the `ratio` shape doesn't perfectly mirror
  score-claudit's absolute-count deduction, but the harness fixtures
  all happen to land within tolerance. Filed as a follow-up if the
  rubric format gets a second pass post-Phase-2.

## References

- `project/plans/active/phase-2-pronto.md` — M1 sits in the
  legacy-sibling-migration arc; closes after H4 and before M2/M3
- `project/tickets/closed/phase-2-h4-observations-aware-scorer.md` —
  the translator + rubric stanza this ticket calibrates against
- `project/adrs/005-sibling-skill-conventions.md` §3 — observations
  vs. score split, back-compat passthrough rule
- `plugins/pronto/references/sibling-audit-contract.md` — v2 wire
  contract (envelope shape, observation entry shape)
- `plugins/pronto/references/rubric.md` `## Observation translation
  rules` — the rubric stanza M1 calibrates and emits against
- `plugins/pronto/agents/parsers/scorers/observations-to-score.sh` —
  the translator that consumes M1's emission
- `plugins/pronto/agents/parsers/scorers/score-claudit.sh` — the file
  M1 modifies
- `plugins/claudit/test-fixtures/snapshots/` (staged on
  `survey/m1-claudit-observations`) — pre-M1 envelope snapshots for
  invariant B regression
- `/tmp/m1-claudit-design.md` (on Batdev, also at
  `/tmp/m1-claudit-design.md` on Batcomputer) — full survey design doc
  with calibration verification
