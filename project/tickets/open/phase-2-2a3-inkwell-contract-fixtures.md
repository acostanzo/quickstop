---
id: 2a3
plan: phase-2-pronto
status: open
updated: 2026-04-28
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
  populating `install_command`, `audit_command`, and `parser_agent`
  for the `code-documentation` row — flipping discovery from
  step-2 (parser agent) to step-1 (canonical `:audit` skill).
- An update to `rubric.md`'s `code-documentation` row (line 14 +
  the dimension-level notes) reflecting that the dimension is now
  parser-driven via inkwell rather than presence-cap-only.

## Architecture

### Audit envelope assembly

`plugins/inkwell/skills/audit/SKILL.md` is updated to drive the
four scorers and slot their JSON outputs into a single envelope:

```bash
README_OBS=$(scorers/score-readme-quality.sh "$REPO_ROOT" 2>/dev/null || echo "")
DOCS_OBS=$(scorers/score-docs-coverage.sh "$REPO_ROOT" 2>/dev/null || echo "")
STALE_OBS=$(scorers/score-doc-staleness.sh "$REPO_ROOT" 2>/dev/null || echo "")
LINKS_OBS=$(scorers/score-link-health.sh "$REPO_ROOT" 2>/dev/null || echo "")

OBSERVATIONS=$(jq -n \
  --argjson r "${README_OBS:-null}" \
  --argjson d "${DOCS_OBS:-null}" \
  --argjson s "${STALE_OBS:-null}" \
  --argjson l "${LINKS_OBS:-null}" \
  '[$r, $d, $s, $l] | map(select(. != null))')

jq -n --argjson obs "$OBSERVATIONS" '{
  "$schema_version": 2,
  plugin: "inkwell",
  dimension: "code-documentation",
  categories: [],
  observations: $obs,
  composite_score: null,
  recommendations: []
}'
```

Observations are kept as a filtered array — null entries from
omitted scorers (tool absent, no scope) are dropped before
assembly, so the envelope's `observations[]` only carries
populated entries. Empty array is permitted and triggers the
translator's case-3 carve-out (passthrough back to the kernel
presence check), preserving the "no scope" semantic.

`composite_score: null` defers all scoring to the rubric path.
H4's translator computes the score from `observations[]` against
the new stanza below.

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
  "parser_agent": "parse-inkwell",
  "roll_your_own_ref": "roll-your-own/code-documentation.md",
  "presence_check": "README.md at repo root with >=10 non-blank lines"
}
```

`plugin_status` flips from `phase-2-plus` to `shipped`. `parser_agent`
stays populated for one minor version as the documented step-2
fallback per ADR-005 §5; subsequent removal happens in a follow-up
once step-1 discovery is verified in production.

### `rubric.md` updates

- Line 14 (`code-documentation` row): the description column flips
  from `README exists and is non-empty` to a brief depth-signal
  summary (e.g. `README quality + docs coverage + staleness + link
  health`). The "phase" column flips `Phase 2+` → `Shipped`.
- Line 46 (Phase-2+ list): remove `inkwell` from the list of
  Phase 2+ siblings. (`lintguini` and `autopompa` stay until 2b/2c
  ship; or `autopompa` flips to `towncrier` per the 2c sweep.)
- Line 93 (presence-cap row for code-documentation): remove the
  "sibling `inkwell` not yet shipped" parenthetical and replace the
  row with a pointer to the new translation rules section ("see
  `code-documentation` translation rules below").
- Add a new `### code-documentation translation rules` section
  containing the rubric stanza above plus a hand-walked
  verification paragraph mirroring M3's pattern.

### Eval harness verification

After the rubric stanza + `recommendations.json` updates land, the
existing `mid` fixture in the eval harness runs N=10. Acceptance:

- `code-documentation` per-dimension stddev ≤ 1.0 over N=10.
- `code-documentation` per-dimension mean within the predicted
  band per the verification table above (mid → 81, ±0.5).
- Composite score stddev unchanged (≤ 1.0).
- Grade-flip rate ≤ 5% over N=10.

Per-fixture N=10 also runs for `low` and `high` to verify the
calibration table empirically.

## Implementation order

1. **`plugins/inkwell/tests/fixtures/{low,mid,high}/`** — populate
   the three fixture directories. Each gets a tailored README,
   `docs/` tree, and `src/` tree with controlled inputs producing
   the predicted observation values.
2. **`plugins/inkwell/skills/audit/SKILL.md`** — replace the
   2a1 empty-envelope emission with the four-scorer dispatch and
   filtered-array assembly per the architecture section above.
3. **`plugins/pronto/references/rubric.md`** — add the
   `code-documentation` translation rules stanza; update the
   table row and the Phase-2+ list per the bullets above.
4. **`plugins/pronto/references/recommendations.json`** — populate
   the four `null` fields in the `code-documentation` row.
5. **`plugins/inkwell/tests/fixtures/{low,mid,high}/envelope.json`** —
   capture the three populated envelopes by running
   `/inkwell:audit --json` against each fixture and committing
   the output verbatim. These are the byte-equivalence anchors
   for invariant B.
6. **`plugins/inkwell/tests/fixtures/snapshots.test.sh`** —
   per-fixture envelope diff against the locked `envelope.json`
   plus per-observation evidence-shape assertions.
7. **`plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh`** —
   add a fixture-scoped case for the four-observation
   `code-documentation` shape so the harness flags drift if the
   stanza or fixtures move out of sync.
8. **Eval harness on `mid`** — N=10. Acceptance per the table
   above.

## Acceptance

- `/inkwell:audit --json` against each of the three fixtures emits
  the predicted populated envelope, byte-for-byte matching
  `envelope.json` across three runs.
- Translator (`observations-to-score.sh`) consumes each fixture's
  envelope and produces the predicted dimension score (low → 45,
  mid → 81, high → 100) within ±1.
- Eval harness on `mid` (N=10): per-dimension `code-documentation`
  stddev ≤ 1.0, mean within ±0.5 of 81; composite stddev ≤ 1.0;
  grade-flip rate ≤ 5%.
- Eval harness on `low` (N=10): per-dimension stddev ≤ 1.0, mean
  within ±0.5 of 45.
- Eval harness on `high` (N=10): per-dimension stddev ≤ 1.0, mean
  within ±0.5 of 100. (Tighter floor since 100 is at the band cap.)
- `recommendations.json`'s `code-documentation` row reads
  `plugin_status: shipped`, all four previously-null fields
  populated.
- `rubric.md` carries the new translation rules section and the
  table-row + Phase-2+-list updates.
- The `code-documentation` row no longer falls through to the
  presence-cap behaviour (50 capped from kernel check); it lands
  the rubric-derived score on every audit.
- No regression on the other three rubric dimensions —
  `claude-code-config`, `skills-quality`, `commit-hygiene` scores
  unchanged on the existing snapshot fixtures (claudit, skillet,
  commventional all still pass their `snapshots.test.sh`).
- No changes to `plugins/claudit/`, `plugins/skillet/`,
  `plugins/commventional/`, `plugins/towncrier/`, or other
  unrelated paths in the diff (verified via `git diff main..` scope
  check).

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
  for one minor version.
- **Lintguini (PR 2b)** — separate PR, separate dimension; lands
  parallel with 2c after 2a closes.
- **Towncrier `:audit` extension (PR 2c)** — separate PR, separate
  dimension.
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
  skillet, commventional all migrated under M1/M2/M3. Inkwell ships
  step-1-ready from day one.

## References

- `project/plans/active/phase-2-pronto.md` — PR 2a 2a3 paragraph,
  acceptance bar.
- `project/tickets/open/phase-2-2a1-inkwell-scaffold.md` — scaffold
  this ticket completes.
- `project/tickets/open/phase-2-2a2-inkwell-scorers.md` — scorers
  this ticket wires in.
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
