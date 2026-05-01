---
id: 2b3
plan: phase-2-pronto
status: open
updated: 2026-05-02
---

# 2b3 — Lintguini contract compliance + locked fixtures + variance harness

## Scope

The original 2b3 plan-line is broad (contract compliance + multi-language fixtures + variance harness), but 2b2 deviated from the inkwell-2a3 pattern by pulling the SKILL.md wiring, the orchestrator (`bin/build-envelope.sh`), and the three end-to-end fixtures (`python-mid`, `ruby-mid`, `typescript-mid`) forward to honour the lifted 2b1 smoke. So 2b3's actual remaining scope is narrower than the plan-line suggests — it is the **calibration layer + cleanup**:

1. **Rubric stanza** — add `lint-posture` translation rules to `plugins/pronto/references/rubric.md`. Four observation entries with bands matching the four scorers shipped in 2b2. The stanza becomes the authority over composite scoring.
2. **`recommendations.json` flip** — populate `install_command`, `audit_command`, `parser_agent` for the `lint-posture` row; `plugin_status` `phase-2-plus` → `shipped`. Discovery flips from step-2 (parser agent) to step-1 (canonical `:audit` skill) per ADR-005 §5.
3. **Transitional composite math excision** — drop the `# Transitional composite math (REPLACED IN 2b3 by the rubric stanza)` block from `bin/build-envelope.sh` (the literal anchor flagged in 2b2's commit `02d97d7`); replace `composite_score: $composite` with `composite_score: null`. The rubric path becomes the sole authority.
4. **Locked envelopes** — capture the populated v2 envelope per fixture as `envelope.json`. Byte-equivalence anchors for invariant B.
5. **Fixture-set extension to triples** — extend each language from `<lang>-mid` to `<lang>-{low,mid,high}` (nine fixtures total). The brief explicitly recommends triples per language; calibration is stronger with three points per language and the fixtures are small text-and-config trees.
6. **Snapshots test** — `plugins/lintguini/scorers/tests/snapshots.test.sh` mirroring the M3 / skillet-snapshots pattern. Per-fixture envelope diff against the locked `envelope.json`, plus the lint-posture observation-ID set assertion.
7. **Translator test extension** — extend `observations-to-score.test.sh` with cases for the four `lint-posture` observation IDs against the controlled-stub stanza, so any drift between stub and the real rubric stanza is caught.
8. **`rubric.md` table updates** — `lint-posture` row's description column flips from presence-only summary to a depth-signal summary; phase column flips `Phase 2+` → `Shipped`. Phase-2+ list mid-document drops `lintguini`. Mechanical-vs-judgment table row for `lint-posture` rewritten to point at the new translation rules.

This is the ticket where the path lights up end-to-end: lintguini's audit emits `composite_score: null`, the orchestrator stops doing scoring math, the rubric stanza becomes the authority, and pronto's translator produces the dimension score from `observations[]` against the calibrated bands.

## Architecture

### `lint-posture` rubric stanza

```json
{
  "observations": [
    {
      "id": "linter-strictness-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 1.00, "score": 100 },
        { "gte": 0.80, "score": 85  },
        { "gte": 0.60, "score": 70  },
        { "gte": 0.40, "score": 50  },
        { "else": 30 }
      ]
    },
    {
      "id": "formatter-configured-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 1, "score": 100 },
        { "else": 0 }
      ]
    },
    {
      "id": "ci-lint-wired-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 1.00, "score": 100 },
        { "gte": 0.80, "score": 85  },
        { "gte": 0.60, "score": 70  },
        { "gte": 0.40, "score": 50  },
        { "else": 30 }
      ]
    },
    {
      "id": "lint-suppression-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 101, "score": 25 },
        { "gte": 51,  "score": 50 },
        { "gte": 21,  "score": 70 },
        { "gte": 6,   "score": 85 },
        { "gte": 1,   "score": 95 },
        { "else": 100 }
      ]
    }
  ],
  "default_rule": "passthrough"
}
```

**Anchors:**

- `linter-strictness-ratio` mirrors the inkwell `readme-arrival-coverage` shape from 2a3: five-band ladder bottoming out at 30, with the `gte 0.40 → 50` floor putting a half-baselined linter at presence-only territory and the `gte 1.00 → 100` peak rewarding meeting the language baseline. Anchored against the per-language baselines documented in `score-linter-presence.sh` (python = 8 ruff rules, ts = 6 strict-bundle-equivalents, ruby = 5 cop departments, etc.).
- `formatter-configured-count` is **a boolean dressed as a count** — `score-formatter-presence.sh` emits `configured: 0|1` only. Two-band ladder (`gte 1 → 100`, else 0) makes the boolean read cleanly through the `count` kind. Documented here so a reader doesn't trip on the `count` kind: it's not a "more is better" count, it's a present-or-absent flag the kind happens to wrap.
- `ci-lint-wired-ratio` mirrors the linter-strictness ladder shape — same five-band ramp. A repo with one CI surface and one wired = 1.00 → 100; a multi-surface repo with half the surfaces wired = 0.50 → 50 (presence-cap territory).
- `lint-suppression-count` mirrors the existing transitional ladder retired from `build-envelope.sh`, anchored to `score-suppression-count.sh`'s documented `threshold_high: 50`. Bands: `0 → 100`, `1-5 → 95`, `6-20 → 85`, `21-50 → 70`, `51-100 → 50`, `>100 → 25`. Reads top-to-bottom: 51..100 hits `gte 51 → 50`; 101+ hits `gte 101 → 25` first.

`default_rule: passthrough` — empty `observations[]` still falls through to the envelope's `composite_score` (now `null` post-excision) and then to presence-cap, preserving the case-3 carve-out semantic the orchestrator depends on for empty-scope fixtures.

### Calibration verification table

The table is hand-walked from the band shapes above against the predicted observation values for each fixture. Fixtures will be constructed to match the predicted inputs.

| Fixture        | Linter ratio | Fmt count | CI ratio | Supp count | Bands hit         | Composite | Letter |
|---             |---           |---        |---       |---         |---                |---        |---     |
| python-low     | 0.25 (2/8)   | 0         | 0/1=0.00 | 60         | 30, 0, 30, 50     | **28**    | F      |
| python-mid     | 0.50 (4/8)   | 1         | 1/1=1.00 | 2          | 50, 100, 100, 95  | **86**    | B      |
| python-high    | 1.00 (8/8)   | 1         | 1/1=1.00 | 0          | 100, 100, 100, 100| **100**   | A+     |
| ruby-low       | 0.20 (1/5)   | 0         | 0/1=0.00 | 51         | 30, 0, 30, 50     | **28**    | F      |
| ruby-mid       | 0.60 (3/5)   | 1         | 1/1=1.00 | 2          | 70, 100, 100, 95  | **91**    | A      |
| ruby-high      | 1.00 (5/5)   | 1         | 1/1=1.00 | 0          | 100, 100, 100, 100| **100**   | A+     |
| typescript-low | 0.17 (1/6)   | 0         | 0/1=0.00 | 60         | 30, 0, 30, 50     | **28**    | F      |
| typescript-mid | 0.33 (2/6)   | 1         | 1/1=1.00 | 2          | 30, 100, 100, 95  | **81**    | B      |
| typescript-high| 1.00 (6/6)   | 1         | 1/1=1.00 | 0          | 100, 100, 100, 100| **100**   | A+     |

The existing 2b2 `*-mid` envelopes carry transitional composites (python=86, ruby=89, typescript=82) computed by the soon-retired inline math in `build-envelope.sh`. Under the rubric stanza:

- **python-mid stays at 86** (band-aligned coincidence — 0.5000 → 50, mean (50+100+100+95)/4 = 86.25 → 86).
- **ruby-mid moves 89 → 91** (transitional rounded ratio×100=60; rubric ladder gte-0.60 = 70).
- **typescript-mid moves 82 → 81** (transitional ratio×100=33.33; rubric `else 30` band).

The ±1-2 movement is the cost of moving from arithmetic-on-ratio to a banded ladder. None of the moves cross a letter-grade boundary on these fixtures, but they will on borderline ones — which is the point of having the band ladder in the first place.

### `recommendations.json` flip

The `lint-posture` row flips from stub to populated, mirroring the M1/M2/M3 shape:

```json
{
  "dimension": "lint-posture",
  "dimension_label": "Lint / format / language rules",
  "recommended_plugin": "lintguini",
  "plugin_status": "shipped",
  "install_command": "/plugin install lintguini@quickstop",
  "audit_command": "/lintguini:audit --json",
  "parser_agent": "parsers/lintguini",
  "roll_your_own_ref": "roll-your-own/lint-posture.md",
  "presence_check": "Language-appropriate lint config file exists"
}
```

`parser_agent` stays populated for one minor version per ADR-005 §5 (the documented step-2 fallback). The `parse-lintguini` agent shipped in 2b1 lives under `plugins/lintguini/agents/parse-lintguini.md`; its removal is filed as a follow-up after step-1 discovery is verified in production for one minor version (mirrors 2a3's `parse-inkwell` handling).

### `rubric.md` updates

- **Line 15** (`lint-posture` row, table at the top): description column flips from `Language-appropriate lint config file exists (e.g. .eslintrc*, pyproject.toml with [tool.ruff], rustfmt.toml)` to a depth-signal summary (e.g. `Linter strictness + formatter presence + CI lint wiring + suppression count`). Phase column flips `Phase 2+` → `Shipped`.
- **Line 46** (Phase-2+ list mid-document): remove `lintguini` from the list. (`inkwell` and `autopompa` stay until 2a3 / 2c-towncrier ship; `autopompa` flips to `towncrier` per the 2c sweep.)
- **Line 94** (mechanical-vs-judgment table row for `lint-posture`): rewrite from `Deterministic presence check via skills/audit/presence-check.sh lint-posture ${REPO_ROOT} — fixed list of language-appropriate lint config files → 50 capped (sibling lintguini not yet shipped).` to a pointer to the new translation rules section (`Sibling lintguini's /lintguini:audit --json emits a v2 wire-contract envelope with four observations consumed by the lint-posture translation rules below.`). Match the row-rewrite shape used post-M1/M2/M3 for `claude-code-config`, `skills-quality`, `commit-hygiene`.
- Add a new `### lint-posture translation rules` section after the existing translation-rules sections. Stanza JSON above plus a hand-walked verification paragraph mirroring M3's shape, including the "boolean dressed as count" anchor for `formatter-configured-count` and the band-interpretation note for `lint-suppression-count`.

### `build-envelope.sh` excision

The lines flagged in 2b2 with `# Transitional composite math (REPLACED IN 2b3 by the rubric stanza).` are dropped:

- The `# ---------------- Transitional composite math (...)` comment block.
- The `COMPOSITE=$(jq -s '...'`)` block computing the equal-share mean.
- `--argjson composite "$COMPOSITE"` from the final `jq -s` invocation.

`composite_score: $composite` becomes `composite_score: null`. The orchestrator stops doing scoring math entirely; the rubric stanza is the sole authority.

### Fixture-set extension: triples

Each language gets `<lang>-{low,mid,high}`. The existing `<lang>-mid` fixtures survive unchanged; new `<lang>-low` and `<lang>-high` fixtures added per language.

```
plugins/lintguini/scorers/tests/fixtures/end-to-end/
├── python-low/                 # weak signals across all four scorers
│   ├── pyproject.toml          # [tool.ruff.lint] select = ["E", "F"] (2/8)
│   ├── .github/workflows/ci.yml # no lint invocation
│   ├── src/                    # 5 .py files, 60 # noqa markers
│   └── envelope.json           # locked, predicted composite=28
├── python-mid/                 # unchanged from 2b2 (predicted 86)
├── python-high/                # all four signals at the top
│   ├── pyproject.toml          # full ruff + ruff format
│   ├── .github/workflows/ci.yml # ruff check + ruff format --check
│   ├── src/                    # 5 .py files, zero markers
│   └── envelope.json           # locked, predicted composite=100
├── ruby-low/                   # 1 cop department, no autocorrect cops, 51 markers
├── ruby-mid/                   # unchanged from 2b2 (predicted 91 post-stanza)
├── ruby-high/                  # standard.yml + 0 markers + wired CI
├── typescript-low/             # 1 strict flag, no eslint/biome, 60 @ts-ignore
├── typescript-mid/             # unchanged from 2b2 (predicted 81 post-stanza)
└── typescript-high/            # full strict bundle + biome + eslint + 0 markers
```

Each `<lang>-{low,mid,high}/envelope.json` is captured by running `bin/build-envelope.sh` against the fixture and committing the output verbatim. These are the byte-equivalence anchors for invariant B.

The fixture set lives under `scorers/tests/fixtures/end-to-end/` (where the existing 2b2 mids already are), not under a separate `tests/fixtures/` tree. Mirrors the 2b2 layout decision; consolidating under one fixture root keeps the snapshots test simpler.

### `snapshots.test.sh`

Per-fixture regression test, mirroring `plugins/skillet/test-fixtures/snapshots/snapshots.test.sh`:

1. For each of the nine fixtures, run `bin/build-envelope.sh <fixture>` and triple-check the output diffs to zero against the fixture's `envelope.json`.
2. Assert `$schema_version == 2` on every envelope.
3. Assert `observations[] | length` matches the populated count for that fixture (4 for fully-signal-firing fixtures; lower for empty-scope-affected ones — none in 2b3's set, but the assertion catches regressions if a scorer regresses).
4. Assert observation IDs match the four-observation contract (`linter-strictness-ratio`, `formatter-configured-count`, `ci-lint-wired-ratio`, `lint-suppression-count`) in fixed order.
5. Pipe each envelope through `plugins/pronto/agents/parsers/scorers/observations-to-score.sh lint-posture` and assert the predicted composite from the calibration table.

`run-all.sh` picks up the new test automatically.

### Translator test extension

`plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh` extends with a `lint-posture` block:

- Add a stub `### `lint-posture` translation rules` stanza to the controlled `RUBRIC_FIXTURE` heredoc, byte-identical to the real rubric stanza.
- Add `expect_branch` cases hitting each band of each observation (band edges + interior + else, mirroring the existing `test-ratio-dim` / `test-count-dim` coverage).
- Add four-observation composite cases verifying the equal-share mean across the four lint-posture observations matches the calibration table predictions.

The stub-vs-real drift catch is the load-bearing assertion: if the rubric stanza moves out of sync with this stub copy, the test still passes (it's testing against its own stub) — but the snapshots test (which uses the real rubric.md) will fail, surfacing the drift. The two layers together catch:

- Stanza-shape regressions (translator unit test catches via stub).
- Stanza-vs-fixture drift (snapshots test catches via real rubric).
- Fixture-vs-stanza drift (same — snapshots test catches it because the locked envelope.json's predicted composite no longer matches what the translator emits under the moved bands).

### Eval harness verification

The full pronto eval harness (`plugins/pronto/tests/eval.sh`) drives `claude -p` against a worktree fixture pinned in `fixtures.json`. Lintguini's path is **fully mechanical** post-2b3 — orchestrator + translator with no model in the loop — so the *per-dimension* lint-posture stddev is structurally 0.0 across N runs. The eval harness's value for 2b3 is verifying:

- The end-to-end dispatch (pronto's audit orchestrator → discovery → `/lintguini:audit --json` → translator) actually finds and dispatches lintguini step-1.
- The composite stddev on the existing `mid` fixture stays ≤ 1.0 with lintguini active (no knock-on regression on claudit / skillet / commventional / avanti).
- The per-dimension `lint-posture` mean on the `mid` fixture matches the predicted value for whatever lint-posture profile that fixture exhibits.

For 2b3:
- **Snapshot tests** (mechanical, deterministic) carry the per-fixture variance bar — triple-run byte-equivalence on each of the nine fixtures, which is a stronger statement than N=10 on a mechanical path.
- **Eval harness on the existing `mid` worktree fixture** (`fixtures.json`) at N=10 carries the cross-sibling no-regression bar — composite stddev ≤ 1.0, grade-flip rate ≤ 5%, lint-posture per-dimension stddev ≤ 1.0 (structurally 0 for a mechanical path).
- **No per-fixture N=10 on the lintguini end-to-end fixtures.** The brief mentions this but it's redundant against the snapshot tests' byte-equivalence — model-driven N=10 measures variance from a mechanical pipeline that has no variance source. Documented as a deviation: snapshots-test triple-run replaces per-fixture N=10. If the cross-sibling eval surfaces unexpected variance attributable to lintguini (e.g. discovery flakiness), file a follow-up.

This is the deviation the brief invites — calling it out per the "if anything conflicts with 2a3, call out the deviation explicitly" guidance: 2a3's acceptance specifies `eval harness on low/mid/high (N=10 each)` per dimension. 2b3 keeps the mechanical-determinism bar (snapshots triple-run) for the per-fixture work and uses the existing eval harness only for cross-sibling regression on the pinned `mid` worktree.

## Implementation order

1. **`plugins/pronto/references/rubric.md`** — add the `lint-posture` translation rules stanza; flip the table row description and phase column; remove `lintguini` from the Phase-2+ list; rewrite the mechanical-vs-judgment row.
2. **`plugins/pronto/references/recommendations.json`** — flip the `lint-posture` row's four `null` fields and `plugin_status`.
3. **Pronto version bump** — `plugin.json`, `marketplace.json`, root README. v0.2.1 → v0.3.0 (minor — rubric stanza addition is a behavioural change to the scoring path).
4. **`plugins/lintguini/bin/build-envelope.sh`** — excise the transitional composite math; emit `composite_score: null`. The orchestrator's job collapses to "run the four scorers, jq-s their outputs, emit the v2 envelope" with no scoring.
5. **Lintguini version bump** — `plugin.json`, `marketplace.json`, root README. v0.3.0 → v0.4.0 (minor — sibling now consumes the rubric path; orchestrator behaviour changes).
6. **`plugins/lintguini/scorers/tests/fixtures/end-to-end/{python,ruby,typescript}-{low,high}/`** — populate the six new fixture directories. Each gets the predicted-input shape from the calibration table.
7. **`plugins/lintguini/scorers/tests/fixtures/end-to-end/<lang>-{low,mid,high}/envelope.json`** — capture the nine populated envelopes by running `bin/build-envelope.sh` against each fixture and committing the output verbatim. Locks the byte-equivalence anchor for invariant B.
8. **`plugins/lintguini/scorers/tests/snapshots.test.sh`** — per-fixture envelope diff + observation-ID set check + translator-applied composite assertion.
9. **`plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh`** — extend with a `lint-posture` stub stanza and band-coverage cases for each observation.
10. **`plugins/lintguini/scorers/tests/end-to-end.test.sh`** — adjust composite assertions: python-mid stays 86, ruby-mid moves 89→91, typescript-mid moves 82→81. (The transitional-math composites baked into the existing test get rewritten to match the rubric-derived composites.)
11. **`run-all.sh`** — pick up `snapshots.test.sh` (extend the test list).
12. **Eval harness** — `plugins/pronto/tests/eval.sh --fixture mid --n 10`. Acceptance per the verification section above.
13. **PR body** — update via `gh pr create` (or `gh pr edit` if pushed first). Emphasise: rubric path now drives all lint-posture scoring; transitional math retired; calibration table verified; eval harness clean.

## Acceptance

- `bin/build-envelope.sh` emits `composite_score: null` (no scoring inline). The transitional math anchor (`# Transitional composite math (REPLACED IN 2b3 by the rubric stanza)`) and its `COMPOSITE=$(jq -s ...)` block are gone.
- `plugins/pronto/references/rubric.md` carries the `### lint-posture translation rules` section with the four-observation stanza above; the table row reads `Shipped` (not `Phase 2+`); the Phase-2+ list mid-document drops `lintguini`; the mechanical-vs-judgment row is rewritten.
- `plugins/pronto/references/recommendations.json`'s `lint-posture` row reads `plugin_status: shipped`, all four previously-null fields populated.
- `pronto` bumps to v0.3.0 in `plugin.json` / `marketplace.json` / root README; `lintguini` bumps to v0.4.0 in the same three places. `./scripts/check-plugin-versions.sh` clean.
- `bin/build-envelope.sh` against each of the nine fixtures emits the predicted populated envelope, byte-for-byte matching `envelope.json` across three runs (triple-run determinism per fixture).
- Translator (`observations-to-score.sh lint-posture`) consumes each fixture's envelope and produces the predicted composite from the calibration table within ±1 (28 / 86 / 100 / 28 / 91 / 100 / 28 / 81 / 100 across low / mid / high × python / ruby / typescript).
- `observations-to-score.test.sh` passes — the existing test cases stay green (controlled-stub stanzas unchanged) and the new `lint-posture` block exercises every band edge.
- `snapshots.test.sh` passes for all nine fixtures.
- `end-to-end.test.sh` passes with the rewritten composite assertions (python-mid=86, ruby-mid=91, typescript-mid=81).
- Eval harness on `mid` (N=10): per-dimension `lint-posture` stddev ≤ 1.0 (structurally 0 for a mechanical path), composite stddev ≤ 1.0, grade-flip rate ≤ 5%. No regression on `claude-code-config`, `skills-quality`, `commit-hygiene` per their existing snapshot tests.
- No changes to `plugins/claudit/`, `plugins/skillet/`, `plugins/commventional/`, `plugins/towncrier/`, `plugins/avanti/`, or `plugins/inkwell/` (verified via `git diff main..` scope check).

## Three load-bearing invariants

A. **End-to-end determinism.** Same fixture filesystem → same envelope JSON bytes across three runs per fixture. The four scorers are verified deterministic individually under 2b2's tests; 2b3's `snapshots.test.sh` extends the verification across the full audit flow per language × profile combination.

B. **Calibration-table fidelity.** The hand-walked predicted composite table above must reproduce within ±1 under the translator path. Drift here means the rubric stanza is mis-tuned against the fixture inputs and the fix is in either the stanza bands or the fixture construction (whichever is wrong) — not in hiding the drift behind looser acceptance thresholds.

C. **No knock-on regression.** Adding a fully-shipped sibling shouldn't perturb the existing dimensions. The eval harness on `mid` still produces composite stddev ≤ 1.0 with all four legacy siblings + lintguini active; the existing snapshot tests for claudit, skillet, commventional all pass byte-equivalent. Run them all in a single sweep before declaring 2b3 done.

## Out of scope

- **Removal of the transitional `parse-lintguini` agent.** Filed as a follow-up after 2b3 verifies step-1 discovery in production for one minor version. (Mirrors 2a3's parse-inkwell handling.)
- **2a3 (inkwell contract compliance).** Separate PR, separate dimension. May land in parallel; if it lands first, expect a small rebase against the `rubric.md` table-row formatting and the Phase-2+ list. No semantic conflict — different translation-rules section, different recommendations.json row.
- **Within-dimension weight rebalancing.** Phase 2 starts with equal-quarter composition per the plan; rebalance only with harness evidence and only as a follow-up.
- **Per-fixture eval-harness N=10.** Replaced by snapshots-test triple-run for the mechanical-determinism bar (deviation from 2a3 — see "Eval harness verification" above for rationale). Cross-sibling regression on the pinned `mid` worktree carries forward.
- **Network-aware lint scoring** (e.g. fetching upstream rule baselines, validating against remote tool versions). Pure config-file inspection only, matching 2b2's invariant.
- **Migration of any other sibling to step-1 discovery.** Claudit, skillet, commventional all migrated under M1/M2/M3. Inkwell ships step-1-ready in 2a3. Lintguini ships step-1-ready in 2b3.

## References

- `project/plans/active/phase-2-pronto.md` — PR 2b 2b3 paragraph, acceptance bar.
- `project/tickets/closed/phase-2-2b1-lintguini-scaffold.md` — the scaffold this dimension's first ticket completed.
- `project/tickets/closed/phase-2-2b2-lintguini-scorers.md` — the scorers + orchestrator + lifted smoke this ticket calibrates against.
- `project/tickets/open/phase-2-2a3-inkwell-contract-fixtures.md` — the canonical 2a3 pattern this ticket mirrors. Deviations: triples for three languages instead of single-language low/mid/high; per-fixture eval-harness N=10 replaced by snapshots triple-run.
- `project/tickets/closed/phase-2-h3-wire-contract-schema-2.md` — wire-contract schema 2 + observations[] field this envelope emits against.
- `project/tickets/closed/phase-2-h4-observations-aware-scorer.md` — the translator + rubric path this stanza calibrates against.
- `project/tickets/closed/phase-2-passthrough-deprecation.md` — case-3 carve-out semantics lintguini's empty-observations[] path relies on.
- `project/tickets/closed/phase-2-m3-commventional-observations-emission.md` — the structural template (calibration verification table, rubric stanza shape, snapshots-test layout).
- `plugins/pronto/references/rubric.md` — the file this ticket edits to add the `lint-posture` translation rules.
- `plugins/pronto/references/recommendations.json` — the file this ticket edits to populate the `lint-posture` row.
- `plugins/pronto/references/sibling-audit-contract.md` — wire contract the populated envelope conforms to.
- `plugins/pronto/references/roll-your-own/lint-posture.md` — source of the per-language baselines and depth-signal framing.
- `plugins/pronto/agents/parsers/scorers/observations-to-score.sh` — the translator this stanza is consumed by.
- `plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh` — the test file extended with the `lint-posture` four-obs case.
- `plugins/skillet/test-fixtures/snapshots/snapshots.test.sh` — the snapshots test pattern this ticket adapts to lintguini's nine-fixture set.
- `plugins/lintguini/bin/build-envelope.sh` — the file this ticket excises the transitional composite math from.
