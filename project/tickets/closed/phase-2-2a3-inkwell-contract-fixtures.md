---
id: 2a3
plan: phase-2-pronto
status: closed
updated: 2026-05-02
---

# 2a3 — Inkwell contract compliance + fixtures

## Scope

2a1 ships the empty-envelope scaffold. 2a2 ships four deterministic
scorers under `plugins/inkwell/scorers/`. 2a3 connects them: the
`:audit` skill invokes each scorer, slots the resulting observations
into the wire-contract envelope, and emits a populated v2 payload.
Pronto's translator (H4) consumes the envelope and applies the
new `code-documentation` rubric stanza; the score lands on the
constellation report.

This is the ticket where the path lights up end-to-end. It also
ships the calibration artefacts:

- The `code-documentation` rubric stanza in
  `plugins/pronto/references/rubric.md`, calibrated against the
  three-fixture set 2a3 introduces.
- A `low/mid/high` fixture set under
  `plugins/inkwell/tests/fixtures/`, mirroring the M3-shaped
  pattern of locked envelopes per fixture.
- Updates to `plugins/pronto/references/recommendations.json`
  populating `install_command` and `audit_command` for the
  `code-documentation` row, flipping `plugin_status` from
  `phase-2-plus` to `shipped`. `parser_agent` stays `null` for
  new-pattern-sibling reasons documented in the "Discovery
  posture" subsection below — discovery is step-1 only via the
  canonical `:audit` skill.
- An update to `rubric.md`'s `code-documentation` row (line 14 +
  the dimension-level notes) reflecting that the dimension is now
  parser-driven via inkwell rather than presence-cap-only.

## Architecture

### Audit envelope assembly

The envelope assembly is extracted into a dedicated orchestrator
script `plugins/inkwell/bin/build-envelope.sh` (mirroring
lintguini's 2b1/2b2/2b3 pattern). The script runs the four
scorers in fixed order, slurps their non-empty stdouts into the
envelope's `observations[]` array, and emits the v2 envelope on
stdout.

```bash
for scorer in \
  score-readme-quality.sh \
  score-docs-coverage.sh \
  score-doc-staleness.sh \
  score-link-health.sh
do
  out="$("$SCORERS_DIR/$scorer" "$REPO_ROOT")"
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out" >> "$OBS_FILE"
  fi
done

jq -s '{
  "$schema_version": 2,
  plugin: "inkwell",
  dimension: "code-documentation",
  categories: [],
  observations: .,
  composite_score: null,
  recommendations: []
}' "$OBS_FILE"
```

`plugins/inkwell/skills/audit/SKILL.md` becomes a thin dispatcher
that invokes the orchestrator and emits its stdout verbatim:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/build-envelope.sh" "<REPO_ROOT>"
```

Observations are filtered by the empty-stdout guard — scorers
that empty-scope (tool absent, no scope) emit nothing and are
omitted from `observations[]` rather than appearing as null
entries. Empty array is permitted and triggers the translator's
case-3 carve-out (passthrough back to the kernel presence check),
preserving the "no scope" semantic.

`composite_score: null` defers all scoring to the rubric path.
H4's translator computes the score from `observations[]` against
the new stanza below. Mirror of the lintguini 2b3 posture: the
orchestrator stops doing scoring math entirely; the rubric stanza
is the sole authority.

Extracting the envelope assembly into a script (rather than
inlining the bash in SKILL.md) is what makes the snapshots test
mechanical — the test invokes `bin/build-envelope.sh` directly
rather than driving the model. See "Variance harness shape"
below.

### `code-documentation` rubric stanza

```json
{
  "observations": [
    {
      "id": "readme-arrival-coverage",
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
      "id": "docs-coverage-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 0.95, "score": 100 },
        { "gte": 0.80, "score": 85  },
        { "gte": 0.60, "score": 70  },
        { "gte": 0.30, "score": 50  },
        { "else": 30 }
      ]
    },
    {
      "id": "docs-staleness-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 30, "score": 30 },
        { "gte": 10, "score": 60 },
        { "gte": 3,  "score": 85 },
        { "else": 100 }
      ]
    },
    {
      "id": "broken-internal-links-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 5, "score": 30 },
        { "gte": 2, "score": 60 },
        { "gte": 1, "score": 85 },
        { "else": 100 }
      ]
    }
  ],
  "default_rule": "passthrough"
}
```

**Anchors:**

- `readme-arrival-coverage` mirrors `roll-your-own/code-documentation.md`'s
  five-question floor. The `gte 1.00 → 100` band rewards the
  fully-arrived README; the `gte 0.40 → 50` band caps a
  half-answered README at presence-only territory; below 0.40 the
  README is treated as missing-in-spirit and lands at 30.
- `docs-coverage-ratio` anchors at `interrogate`'s 80% gate
  default: `gte 0.80 → 85` puts the dominant Python convention at
  the high end of the rubric without claiming perfection. `gte 0.95`
  earns the 100 only when the project is meticulously documented.
- `docs-staleness-count` is the novel signal. Bands chosen for
  fixture-led calibration: a single-digit count of stale files is
  forgivable (gte 3 → 85), double digits is concerning (gte 10
  → 60), triple digits is a documentation-rotted repo (gte 30
  → 30). Expect band edges to shift after fixture calibration —
  treat these as v1 estimates.
- `broken-internal-links-count` mirrors the staleness shape: any
  broken link is a problem (gte 1 → 85) but isolated; multiple
  broken links is a maintenance signal (gte 2 → 60); five-plus is
  a rotted-tree signal (gte 5 → 30). lychee's typical false-positive
  rate against well-formed repos is near-zero, so band tightness
  is justified.

### Fixture set: `plugins/inkwell/tests/fixtures/`

```
plugins/inkwell/tests/fixtures/
├── README.md                   # describes the three-fixture set
├── low/                        # documentation-rotted repo
│   ├── README.md               # 12 lines, 1 arrival question, marketing-shaped
│   ├── docs/                   # 1 file, last touched 2 years ago
│   ├── src/                    # 30 .py files, 2 with docstrings
│   └── envelope.json           # locked pre-2a3 envelope
├── mid/                        # mixed-quality
│   ├── README.md               # 60 lines, 4/5 arrival questions
│   ├── docs/                   # 5 files, mixed ages
│   ├── src/                    # 25 .py files, 18 with docstrings
│   └── envelope.json
├── high/                       # exemplar
│   ├── README.md               # 40 lines, 5/5 arrival questions
│   ├── docs/                   # 8 files, all current
│   ├── src/                    # 20 .py files, 19 with docstrings
│   └── envelope.json
└── snapshots.test.sh           # invariant B regression
```

Per-fixture verification table (predicted, locked at fixture-build
time):

| Fixture | README cov | Docs cov | Stale | Broken | Bands hit | Mean | Letter |
|---|---|---|---|---|---|---|---|
| low  | 0.20 | 0.067 | 18 | 4 | 30, 30, 60, 60   | 45 | F |
| mid  | 0.80 | 0.720 | 6  | 1 | 85, 70, 85, 85   | 81 | B |
| high | 1.00 | 0.950 | 0  | 0 | 100, 100, 100, 100 | 100 | A+ |

The table is hand-walked from the band shapes above. Fixture
construction matches the predicted inputs. Eval-harness verification
(N=10 per fixture) confirms the prediction within the stddev
tolerance below.

### `recommendations.json` updates

The `code-documentation` row flips from stub to populated:

```json
{
  "dimension": "code-documentation",
  "dimension_label": "Code documentation",
  "recommended_plugin": "inkwell",
  "plugin_status": "shipped",
  "install_command": "/plugin install inkwell@quickstop",
  "audit_command": "/inkwell:audit --json",
  "parser_agent": null,
  "roll_your_own_ref": "roll-your-own/code-documentation.md",
  "presence_check": "README.md at repo root with >=10 non-blank lines"
}
```

`plugin_status` flips from `phase-2-plus` to `shipped`.
`parser_agent` is set to `null` — see "Discovery posture" below
for the rationale. The transitional `parse-inkwell` agent shipped
in 2a1 lives under `plugins/inkwell/agents/parse-inkwell.md`;
that's a sibling-side file, separate from the (non-existent)
pronto-side `plugins/pronto/agents/parsers/inkwell.md` that a
populated `parser_agent` would point at. The sibling-side file's
removal is filed as a follow-up.

### Discovery posture

The `parser_agent` field is left **null** rather than pointing at
`parsers/inkwell`. Three reasons (mirror of the lintguini 2b3
posture documented in commit `f90cc5e`):

1. **Sub-path A wins.** Pronto's audit orchestrator
   (`plugins/pronto/skills/audit/SKILL.md` Phase 3 step 3) checks
   `plugin.json`'s `pronto.audits[]` declaration first; if
   present, it dispatches via slash command (`/inkwell:audit
   --json`) and **never consults `parser_agent`**. Inkwell
   declares `pronto.audits[]` natively from 2a1, so Sub-path A is
   the only dispatch path that fires today. A populated
   `parser_agent` would be dead code — the parser-agent path
   (Sub-path B / Phase 4.1) only triggers when Sub-path A is
   unavailable.
2. **Phase 4.1's invocation pattern doesn't fit new-pattern
   siblings.** The literal Bash dispatch
   (`${CLAUDE_PLUGIN_ROOT}/agents/parsers/scorers/score-<sibling>.sh`)
   resolves under pronto's tree, not the sibling's. Legacy
   siblings (claudit, skillet, commventional, avanti) have their
   scorer scripts bundled in pronto's tree because the M1/M2/M3
   migration ported them in. New-pattern siblings (lintguini,
   inkwell, towncrier) own their orchestrator in their own plugin
   tree (`plugins/inkwell/bin/build-envelope.sh`) — a Phase 4.1
   dispatch would require either a cross-plugin script-path hop
   (`${CLAUDE_PLUGIN_ROOT}/../inkwell/bin/build-envelope.sh`,
   brittle under installed-plugin layouts) or duplicating the
   orchestrator in pronto's tree (architecturally wrong — pronto
   stays the rubric/orchestration authority, the sibling owns its
   scoring logic per ADR-006).
3. **ADR-005 §5 frames step-2 as a fallback, not a requirement.**
   Siblings that declare `pronto.audits[]` natively don't need
   step-2 to satisfy the discovery contract. The contract is
   honoured by step-1 alone.

The trade-off: if `/inkwell:audit --json` ever fails to dispatch
(sibling not installed, version-handshake out-of-range, runtime
error), the dimension degrades to presence-cap (50 capped from
kernel check) instead of falling back to a parser-agent path.
That's the same posture every new-pattern sibling has — lintguini
adopted it in 2b3. Step-2 fallback for new-pattern siblings is a
future-ticket concern, not 2a3's.

### `rubric.md` updates

- **`code-documentation` row** (table at the top of rubric.md):
  description column flips from `README exists and is non-empty`
  to a brief depth-signal summary (e.g. `README arrival coverage
  + docs coverage + staleness + link health`). The "Status"
  column flips `Phase 2+` → `Shipped`.
- **Phase-2+ list mid-document**: remove `inkwell` from the list
  of Phase 2+ siblings. (`autopompa` stays until 2c ships, or
  flips to `towncrier` per the 2c sweep.)
- **Mechanical-vs-judgment table row for `code-documentation`**:
  rewrite the existing presence-cap-only row to a pointer to the
  new translation rules section, mirroring the post-2b3 shape
  used for `lint-posture`: "Sibling inkwell's `/inkwell:audit
  --json` emits a v2 wire-contract envelope with four
  observations consumed by the `code-documentation` translation
  rules below."
- Add a new `### code-documentation translation rules` section
  after the existing translation-rules sections. Stanza JSON
  above plus a hand-walked verification paragraph mirroring 2b3's
  shape.

### Variance harness shape

Inkwell's audit path is **fully mechanical** post-2a3 — orchestrator
(`bin/build-envelope.sh`) + four deterministic shell scorers + the
translator, with no model in the loop — so the per-dimension
`code-documentation` stddev is structurally 0.0 across N runs.
Per-fixture N=10 against this pipeline measures variance from a
source that has none, so the mechanical-determinism bar is
carried by triple-run byte-equivalence in the snapshots test
rather than an N=10 eval-harness run per fixture.

This deviates from the original 2a3 brief (which called for
eval-harness N=10 on `low`/`mid`/`high`) and mirrors the
deviation 2b3 took for the same reason. See 2b3's "Eval harness
verification" section for the precedent.

For 2a3:
- **Snapshots test** (`plugins/inkwell/tests/fixtures/snapshots.test.sh`)
  carries the per-fixture variance bar — triple-run byte-equivalence
  on each of the three fixtures, which is a stronger statement
  than N=10 on a mechanical path.
- **Translator unit-test extension**
  (`plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh`)
  carries the calibration-table fidelity bar — band-edge coverage
  per observation plus the four-observation composite cases
  reproducing the predicted scores from the calibration table.
- **Eval harness on the existing `mid` worktree fixture**
  (`fixtures.json`) at N=10 carries the cross-sibling no-regression
  bar — composite stddev ≤ 1.0, grade-flip rate ≤ 5%,
  `code-documentation` per-dimension stddev ≤ 1.0 (structurally
  0 for a mechanical path). No regression on `claude-code-config`,
  `skills-quality`, `commit-hygiene`, `lint-posture`.
- **No per-fixture N=10 on the inkwell low/mid/high fixtures.**
  Snapshots-test triple-run replaces it.

Caveat: this deviation is universal *only* because all four
inkwell scorers stay mechanical. If a future scorer dispatches to
an LLM (judgment-shaped) rather than to deterministic shell, that
scorer's calibration would need per-fixture N=10 — the snapshot
test's byte-equivalence assertion would catch the variance as a
test failure, but the calibration would have to land via the
eval harness against the noisy signal. None of the four 2a2
scorers are model-driven, so the deviation holds for 2a3.

## Implementation order

1. **`plugins/pronto/references/rubric.md`** — add the
   `code-documentation` translation rules stanza; flip the table
   row description and phase column; remove `inkwell` from the
   Phase-2+ list; rewrite the mechanical-vs-judgment row.
2. **`plugins/pronto/references/recommendations.json`** — populate
   `install_command`, `audit_command`, flip `plugin_status` to
   `shipped`. `parser_agent` stays `null` (see Discovery posture).
3. **Pronto version bump** — `plugin.json`, `marketplace.json`,
   root README. Minor bump (rubric stanza addition is a
   behavioural change to the scoring path).
4. **`plugins/inkwell/bin/build-envelope.sh`** — new orchestrator
   script per the architecture section above. The orchestrator
   runs the four scorers in fixed order and slurps non-empty
   stdouts into the envelope's `observations[]` array;
   `composite_score` is `null`.
5. **`plugins/inkwell/skills/audit/SKILL.md`** — replace the 2a1
   empty-envelope emission with a thin dispatcher that invokes
   the orchestrator and emits its stdout verbatim.
6. **Inkwell version bump** — `plugin.json`, `marketplace.json`,
   root README. Minor bump (sibling now consumes the rubric path;
   orchestrator behaviour changes from empty-envelope to
   populated).
7. **`plugins/inkwell/tests/fixtures/{low,mid,high}/`** — populate
   the three fixture directories. Each gets a tailored README,
   `docs/` tree, and `src/` tree with controlled inputs producing
   the predicted observation values.
8. **`plugins/inkwell/tests/fixtures/{low,mid,high}/envelope.json`** —
   capture the three populated envelopes by running
   `bin/build-envelope.sh` against each fixture and committing
   the output verbatim. These are the byte-equivalence anchors
   for invariant B.
9. **`plugins/inkwell/tests/fixtures/snapshots.test.sh`** —
   per-fixture envelope diff against the locked `envelope.json`,
   plus the `$schema_version`, observation-ID set, and
   translator-applied composite assertions. Mirror lintguini's
   snapshots.test.sh.
10. **`plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh`** —
    extend with a stub `code-documentation` translation rules
    stanza (byte-identical to the real rubric.md stanza) and
    band-coverage cases for each of the four observations plus
    composite cases for `low`/`mid`/`high`.
11. **Eval harness on `mid`** — `plugins/pronto/tests/eval.sh
    --fixture mid --n 10`. Acceptance per the variance harness
    shape section.

## Acceptance

- `bin/build-envelope.sh` emits a v2 envelope with
  `composite_score: null` and observations slurped from the four
  scorers. SKILL.md is a thin dispatcher that emits the
  orchestrator's stdout verbatim.
- `bin/build-envelope.sh` against each of the three fixtures emits
  the predicted populated envelope, byte-for-byte matching
  `envelope.json` across three runs (triple-run determinism per
  fixture).
- Translator (`observations-to-score.sh code-documentation`)
  consumes each fixture's envelope and produces the predicted
  dimension score (low → 45, mid → 81, high → 100) within ±1.
- `observations-to-score.test.sh` passes — existing test cases
  stay green and the new `code-documentation` block exercises
  every band edge plus the three composite cases.
- `snapshots.test.sh` passes for all three fixtures.
- `pronto` and `inkwell` both bump versions in
  `plugin.json` / `marketplace.json` / root README;
  `./scripts/check-plugin-versions.sh` clean.
- `recommendations.json`'s `code-documentation` row reads
  `plugin_status: shipped`, with `install_command` and
  `audit_command` populated; `parser_agent` stays `null` per the
  Discovery posture rationale.
- `rubric.md` carries the new translation rules section and the
  table-row + Phase-2+-list updates.
- The `code-documentation` row no longer falls through to the
  presence-cap behaviour (50 capped from kernel check); it lands
  the rubric-derived score on every audit.
- Eval harness on `mid` (N=10): per-dimension `code-documentation`
  stddev ≤ 1.0 (structurally 0 for a mechanical path), composite
  stddev ≤ 1.0, grade-flip rate ≤ 5%. No regression on
  `claude-code-config`, `skills-quality`, `commit-hygiene`,
  `lint-posture` per their existing snapshot tests.
- No regression on the other rubric dimensions — claudit,
  skillet, commventional, lintguini all still pass their
  `snapshots.test.sh`.
- No changes to `plugins/claudit/`, `plugins/skillet/`,
  `plugins/commventional/`, `plugins/towncrier/`,
  `plugins/avanti/`, or `plugins/lintguini/` (verified via
  `git diff main..` scope check).

## Three load-bearing invariants

A. **End-to-end determinism.** Same fixture filesystem → same
envelope JSON bytes across N=10 runs. The four scorers are already
verified deterministic individually under 2a2's tests; 2a3's
`snapshots.test.sh` extends the verification across the full audit
flow.

B. **Calibration-table fidelity.** The hand-walked predicted score
table above must reproduce within ±0.5 mean and ≤1.0 stddev under
N=10 harness runs. Drift here means the rubric stanza is mis-tuned
against the fixture inputs and the fix is in either the stanza
bands or the fixture construction (whichever is wrong) — not in
hiding the drift behind looser acceptance thresholds.

C. **No knock-on regression.** Adding a fully-shipped sibling
shouldn't perturb the existing dimensions. The eval harness on
`mid` still produces composite stddev ≤ 1.0 with all three legacy
siblings + inkwell active; the existing snapshot tests for claudit,
skillet, commventional still pass byte-equivalent. Run them all in
a single CI sweep before declaring 2a3 done.

## Out of scope

- **Removal of the transitional `parse-inkwell` agent.** Filed as
  a follow-up after 2a3 verifies step-1 discovery in production
  for one minor version. Mirrors 2b3's parse-lintguini handling.
- **Lintguini (PR 2b)** — landed in 2b3 ahead of 2a3. The
  `lint-posture` translation rules section sits next to the
  `code-documentation` translation rules in `rubric.md`; no
  semantic conflict.
- **Towncrier `:audit` extension (PR 2c)** — separate PR, separate
  dimension.
- **Per-fixture eval-harness N=10.** Replaced by snapshots-test
  triple-run for the mechanical-determinism bar (deviation from
  the original 2a3 brief — see "Variance harness shape" above for
  rationale). 2b3 set the precedent. Cross-sibling regression on
  the pinned `mid` worktree carries forward.
- **Network-aware lychee mode.** External-link health is a future
  scorer extension; 2a2/2a3 stay `--offline`.
- **Within-dimension weight rebalancing.** The plan calls for
  equal quarters as the starting position; once fixtures
  calibrate, 2a3 may tune. If a signal is dominant or dead in
  practice, raise a follow-up — don't rebalance under the same
  ticket without harness evidence.
- **Per-language tool installation guidance.** `interrogate`,
  `lychee`, etc. — README mentions the dependencies but doesn't
  ship installers. Tool absence degrades gracefully per 2a2's
  invariant B.
- **Migration of any other sibling to step-1 discovery.** Claudit,
  skillet, commventional all migrated under M1/M2/M3. Lintguini
  ships step-1-ready in 2b3. Inkwell ships step-1-ready in 2a3.

## References

- `project/plans/active/phase-2-pronto.md` — PR 2a 2a3 paragraph,
  acceptance bar.
- `project/tickets/closed/phase-2-2a1-inkwell-scaffold.md` —
  scaffold this ticket completes.
- `project/tickets/closed/phase-2-2a2-inkwell-scorers.md` —
  scorers this ticket wires in.
- `project/tickets/closed/phase-2-2b3-lintguini-contract-fixtures.md` —
  the precedent ticket whose Discovery posture and Variance
  harness shape sections this ticket mirrors. Commit `f90cc5e`
  carries the parser_agent: null rationale.
- `project/tickets/closed/phase-2-h3-wire-contract-schema-2.md` —
  wire-contract schema 2 + observations[] field this envelope
  emits against.
- `project/tickets/closed/phase-2-h4-observations-aware-scorer.md` —
  the translator + rubric path this stanza calibrates against.
- `project/tickets/closed/phase-2-passthrough-deprecation.md` —
  case-3 carve-out semantics inkwell relies on for empty-scope
  short-circuit.
- `project/tickets/closed/phase-2-m3-commventional-observations-emission.md` —
  the structural template this ticket follows (calibration
  verification table, rubric stanza shape, fixture-set layout).
- `plugins/pronto/references/rubric.md` — the file this ticket
  edits to add the `code-documentation` translation rules.
- `plugins/pronto/references/recommendations.json` — the file this
  ticket edits to populate the `code-documentation` row.
- `plugins/pronto/references/sibling-audit-contract.md` — wire
  contract the populated envelope conforms to.
- `plugins/pronto/references/roll-your-own/code-documentation.md` —
  source of the README arrival questions and depth-signal framing.
- `plugins/pronto/agents/parsers/scorers/observations-to-score.sh` —
  the translator this stanza is consumed by.
- `plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh` —
  the test file extended with the `code-documentation` four-obs
  case.
- M1 PR #61, M2 PR (skillet), M3 PR — canonical patterns this
  ticket draws on for envelope shape, calibration verification,
  and fixture set layout.
