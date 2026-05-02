---
id: 2c3
plan: phase-2-pronto
status: closed
updated: 2026-05-02
---

# 2c3 — Towncrier contract compliance + locked fixtures

## Scope

2c1 ships the empty-envelope `:audit` scaffold and sweeps the
autopompa references. 2c2 ships four deterministic scorers under
`plugins/towncrier/scorers/`. 2c3 connects them: the orchestrator
script `plugins/towncrier/bin/build-envelope.sh` runs each scorer,
slots the resulting observations into the wire-contract envelope,
and emits a populated v2 payload. The `:audit` skill collapses to
a thin dispatcher. Pronto's translator (H4) consumes the envelope
and applies the new `event-emission` rubric stanza; the score
lands on the constellation report.

This is the ticket where the path lights up end-to-end. It also
ships the calibration artefacts:

- The `event-emission` rubric stanza in
  `plugins/pronto/references/rubric.md`, calibrated against the
  fixture set 2c3 introduces.
- A `low/mid/high` fixture set under
  `plugins/towncrier/tests/fixtures/`, mirroring the inkwell-2a3
  shape of locked envelopes per fixture. The `low` fixture is
  constructed to satisfy the plan-doc's required bait-and-switch
  case (kernel-level structured-logging grep matches pass while
  the structured-logging ratio scorer returns < 0.5).
- Updates to `plugins/pronto/references/recommendations.json`
  populating `install_command` and `audit_command` for the
  `event-emission` row, flipping `plugin_status` from
  `phase-2-plus` to `shipped`. `parser_agent` stays `null` — see
  Discovery posture below.
- Updates to `rubric.md`'s `event-emission` row description and
  status columns + the mechanical-vs-judgment row, mirroring the
  post-2a3 / post-2b3 shape.
- Pronto and towncrier version bumps per the marketplace
  versioning convention.

## Architecture

### Audit envelope assembly

The envelope assembly lives in a dedicated orchestrator script
`plugins/towncrier/bin/build-envelope.sh` (mirroring inkwell's 2a3
and lintguini's 2b3 pattern). The script runs the four scorers in
fixed order, slurps their non-empty stdouts into the envelope's
`observations[]` array, and emits the v2 envelope on stdout.

```bash
for scorer in \
  score-structured-logging-ratio.sh \
  score-metrics-presence.sh \
  score-trace-propagation.sh \
  score-event-schema-consistency.sh
do
  out="$("$SCORERS_DIR/$scorer" "$REPO_ROOT")"
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out" >> "$OBS_FILE"
  fi
done

jq -s '{
  "$schema_version": 2,
  plugin: "towncrier",
  dimension: "event-emission",
  categories: [],
  observations: .,
  composite_score: null,
  recommendations: []
}' "$OBS_FILE"
```

`plugins/towncrier/skills/audit/SKILL.md` becomes a thin dispatcher
that invokes the orchestrator and emits its stdout verbatim:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/build-envelope.sh" "<REPO_ROOT>"
```

The model's job collapses to "run this script, paste its output" —
no rendering, no interpretation, no scoring math. Mirrors inkwell
2a3 and lintguini 2b3 exactly.

Observations are filtered by the empty-stdout guard — scorers that
empty-scope (no language detected, no metrics infra, no handlers
detected, no emission sites) emit nothing and are omitted from
`observations[]` rather than appearing as null entries. Empty array
is permitted and triggers the translator's case-3 carve-out
(passthrough back to the kernel presence check), preserving the
"no scope" semantic.

`composite_score: null` defers all scoring to the rubric path.
H4's translator computes the score from `observations[]` against
the new stanza below. Mirror of the inkwell 2a3 / lintguini 2b3
posture: the orchestrator stops doing scoring math entirely; the
rubric stanza is the sole authority. This also means there's no
transitional composite to retire (lintguini 2b3 had to retire its
2b2 transitional math; towncrier 2c2 stayed on the 2a2 pattern of
deferring SKILL.md envelope-wiring entirely, so the orchestrator
ships clean from day one).

Extracting the envelope assembly into a script (rather than
inlining the bash in SKILL.md) is what makes the snapshots test
mechanical — the test invokes `bin/build-envelope.sh` directly
rather than driving the model. See "Variance harness shape" below.

### `event-emission` rubric stanza

```json
{
  "observations": [
    {
      "id": "structured-logging-ratio",
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
      "id": "metrics-instrumentation-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 10, "score": 100 },
        { "gte": 3,  "score": 85  },
        { "gte": 1,  "score": 70  },
        { "else": 50 }
      ]
    },
    {
      "id": "trace-propagation-ratio",
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
      "id": "event-schema-consistency-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 0.95, "score": 100 },
        { "gte": 0.80, "score": 85  },
        { "gte": 0.60, "score": 70  },
        { "gte": 0.30, "score": 50  },
        { "else": 30 }
      ]
    }
  ],
  "default_rule": "passthrough"
}
```

**Anchors:**

- `structured-logging-ratio` mirrors lintguini's
  `linter-strictness-ratio` shape and inkwell's
  `readme-arrival-coverage` shape — five-band ladder bottoming out
  at 30. The `gte 0.40 → 50` floor puts a half-structured codebase
  at presence-only territory; below 0.40 the codebase is
  free-form-dominant and lands at 30. The `gte 1.00 → 100` peak
  rewards an all-structured emission surface.
- `metrics-instrumentation-count` is anchored against
  `score-metrics-presence.sh`'s observation shape: the scorer emits
  an observation **only if** the language has at least a metrics
  library imported (`configured: 1`) or call sites detected. The
  `else 50` band catches the "library imported but zero sites"
  case (configured=1, metrics_sites=0) — half-credit for having the
  infra without using it. `gte 1 → 70` is the just-instrumented
  floor; `gte 3 → 85` is "instruments more than the obvious";
  `gte 10 → 100` is "metrics-mature codebase". If neither library
  nor sites detected, the scorer empty-scopes upstream and the
  observation never reaches the rubric — the composite divisor
  drops to 3 rather than scoring 0.
- `trace-propagation-ratio` mirrors the structured-logging ladder
  shape — same five-band ramp. A repo with one handler-shaped file
  fully instrumented = 1.00 → 100; a repo with half its handlers
  carrying trace context = 0.50 → 50 (presence-cap territory). The
  scorer's empty-scope rule (no handler-shaped files detected →
  observation omitted) means CLI tools and library packages aren't
  faulted for lacking trace propagation they wouldn't sensibly carry.
- `event-schema-consistency-ratio` uses a slightly different ladder
  (`gte 0.95` instead of `gte 1.00`) recognising that "every
  emission carries a domain anchor" is a steeper bar than
  "every emission is structured" — a few free-form structured
  emits are a normal gradient, not a binary failure mode. Anchored
  against `score-event-schema-consistency.sh`'s heuristic
  (well-shaped events / total events).

`default_rule: passthrough` — empty `observations[]` falls through
to the envelope's `composite_score` (`null`) and then to
presence-cap, preserving the case-3 carve-out semantic the
orchestrator depends on for empty-scope fixtures.

### Calibration verification table

The fixture set is **single-language python low/mid/high**, mirroring
inkwell 2a3's three-fixture shape rather than lintguini 2b3's
nine-fixture (three-language × three-profile) shape. Three reasons:

1. The plan-doc's required acceptance is "fixture set includes at
   least one bait case" — minimum bar is satisfiable with a single
   language's profile triplet, with the bait baked into `low`.
2. Python is the right primary because all four depth signals
   (structured logging via structlog/loguru, metrics via
   prometheus_client, trace propagation via OTel python SDK, event
   schemas) are well-conventioned in python and `roll-your-own/event-emission.md`
   uses python in the worked examples.
3. If 2c3 implementation discovers calibration is python-incomplete
   (e.g. trace propagation differs enough between python and
   typescript handler shapes to need separate tuning), surface it
   then and extend the fixture set within 2c3's scope. Don't pre-bake
   a multi-language fixture set without harness evidence the single
   language is insufficient.

The table is hand-walked from the band shapes above against the
predicted observation values for each fixture. Fixtures will be
constructed to match the predicted inputs.

| Fixture     | Struct ratio | Metrics count | Trace ratio | Schema ratio | Bands hit         | Composite | Letter |
|---          |---           |---            |---          |---           |---                |---        |---     |
| python-low  | 0.20 (bait)  | 0 (cfg=1)     | 0.00        | 0.20         | 30, 50, 30, 30    | **35**    | F      |
| python-mid  | 0.83         | 5             | 0.67        | 0.80         | 85, 85, 70, 85    | **81**    | B      |
| python-high | 1.00         | 12            | 1.00        | 0.95         | 100, 100, 100, 100| **100**   | A+     |

The `python-low` fixture is the **bait-and-switch case the plan-doc
requires**: the kernel's presence-check grep matches `pino` /
`structlog` / `opentelemetry` / `metric` keywords (because the
fixture imports the libraries), but the structured-logging ratio
scorer returns 0.20 because the actual emission sites are mostly
free-form `print()`. That's the structurally interesting case
2c3 must handle — surface-level presence checks shouldn't silently
inflate the composite when the actual emission shape is poor. With
the rubric stanza in place, `python-low` lands at 35 (F) rather
than the 50-capped (D) the kernel would assign.

### Fixture set: `plugins/towncrier/tests/fixtures/`

```
plugins/towncrier/tests/fixtures/
├── README.md                  # describes the three-fixture set
├── python-low/                # bait-and-switch + low everything
│   ├── pyproject.toml         # imports structlog, prometheus_client, opentelemetry
│   ├── src/                   # 5 .py files, mostly print(); 2 structlog uses, 8 print uses
│   ├── handlers/              # 3 handler-shaped files, 0 with trace context
│   └── envelope.json          # locked, predicted composite=35
├── python-mid/                # mixed-quality
│   ├── pyproject.toml         # full structured-logging + OTel + prometheus
│   ├── src/                   # 6 structlog uses, 1 print; 5 metrics call sites; 8 well-shaped, 2 freeform
│   ├── handlers/              # 3 handler-shaped files, 2 with trace context
│   └── envelope.json          # locked, predicted composite=81
├── python-high/               # exemplar
│   ├── pyproject.toml         # full instrumentation
│   ├── src/                   # all structlog, 12 metrics sites, 19 well-shaped events
│   ├── handlers/              # 3 handler-shaped files, 3 with trace context
│   └── envelope.json          # locked, predicted composite=100
└── snapshots.test.sh          # invariant B regression
```

Per-fixture verification is captured at fixture-build time by
running `bin/build-envelope.sh` against each fixture and committing
the populated envelope verbatim as `envelope.json`. These are the
byte-equivalence anchors for invariant B.

### `recommendations.json` updates

The `event-emission` row flips from stub to populated, mirroring
inkwell 2a3 and lintguini 2b3:

```json
{
  "dimension": "event-emission",
  "dimension_label": "Event emission",
  "recommended_plugin": "towncrier",
  "plugin_status": "shipped",
  "install_command": "/plugin install towncrier@quickstop",
  "audit_command": "/towncrier:audit --json",
  "parser_agent": null,
  "roll_your_own_ref": "roll-your-own/event-emission.md",
  "presence_check": "Observability instrumentation grep matches"
}
```

`plugin_status` flips from `phase-2-plus` to `shipped`.
`recommended_plugin` already reads `towncrier` (set by 2c1's
sweep). `install_command` and `audit_command` populate. `parser_agent`
stays `null` — see Discovery posture below.

### Discovery posture

The `parser_agent` field is left **null** rather than pointing at
`parsers/towncrier`. Three reasons (mirror of the lintguini 2b3
posture documented in commit `f90cc5e`, also adopted by inkwell
2a3):

1. **Sub-path A wins.** Pronto's audit orchestrator
   (`plugins/pronto/skills/audit/SKILL.md` Phase 3 step 3) checks
   `plugin.json`'s `pronto.audits[]` declaration first; if present,
   it dispatches via slash command (`/towncrier:audit --json`) and
   **never consults `parser_agent`**. Towncrier declares
   `pronto.audits[]` natively from 2c1, so Sub-path A is the only
   dispatch path that fires today. A populated `parser_agent` would
   be dead code — the parser-agent path (Sub-path B / Phase 4.1)
   only triggers when Sub-path A is unavailable.
2. **Phase 4.1's invocation pattern doesn't fit new-pattern
   siblings.** The literal Bash dispatch
   (`${CLAUDE_PLUGIN_ROOT}/agents/parsers/scorers/score-<sibling>.sh`)
   resolves under pronto's tree, not the sibling's. Legacy siblings
   (claudit, skillet, commventional, avanti) have their scorer
   scripts bundled in pronto's tree because the M1/M2/M3 migration
   ported them in. New-pattern siblings (lintguini, inkwell,
   towncrier) own their orchestrator in their own plugin tree
   (`plugins/towncrier/bin/build-envelope.sh`) — a Phase 4.1
   dispatch would require either a cross-plugin script-path hop
   (`${CLAUDE_PLUGIN_ROOT}/../towncrier/bin/build-envelope.sh`,
   brittle under installed-plugin layouts) or duplicating the
   orchestrator in pronto's tree (architecturally wrong — pronto
   stays the rubric/orchestration authority, the sibling owns its
   scoring logic per ADR-006).
3. **ADR-005 §5 frames step-2 as a fallback, not a requirement.**
   Siblings that declare `pronto.audits[]` natively don't need
   step-2 to satisfy the discovery contract. The contract is
   honoured by step-1 alone.

The trade-off: if `/towncrier:audit --json` ever fails to dispatch
(sibling not installed, version-handshake out-of-range, runtime
error), the dimension degrades to presence-cap (50 capped from
kernel grep) instead of falling back to a parser-agent path. That's
the same posture every new-pattern sibling has — lintguini adopted
it in 2b3, inkwell in 2a3. Step-2 fallback for new-pattern siblings
is a future-ticket concern, not 2c3's. If we add it later, the
shape will be a proper cross-plugin discovery mechanism that
ADR-005 §5 currently doesn't specify.

**No transitional parser agent file exists to remove.** Inkwell 2a3
and lintguini 2b3 each had a `plugins/<plugin>/agents/parse-<plugin>.md`
stub from their respective scaffold tickets, deferred for follow-up
removal once step-1 dispatch was verified in production. 2c1 skipped
that file entirely (per its File tree section), so 2c3 has no
follow-up to file. The posture is cleaner — one fewer cleanup
ticket downstream.

### `rubric.md` updates

- **`event-emission` row** (table at the top of rubric.md, line 16
  pre-2c3): description column flips from `Observability
  instrumentation detected (e.g. OpenTelemetry config, event-bus
  references, structured logging setup)` to a depth-signal summary
  (e.g. `Structured logging ratio + metrics instrumentation +
  trace propagation + event schema consistency`). Status column
  flips `Phase 2+` → `Shipped`.
- **Phase-2+ list paragraph** (line 46 pre-2c3): drop the
  reference to `towncrier's :audit extension` (added by 2c1's
  sweep). After 2c3 lands, the paragraph reads "`avanti` is Phase
  1b" only — `inkwell` and `lintguini` are already shipped, and
  `towncrier`'s `:audit` extension joins them.
- **Mechanical-vs-judgment table row for `event-emission`** (line
  95 pre-2c3): rewrite from
  `Deterministic presence check via skills/audit/presence-check.sh
  event-emission ${REPO_ROOT} → 50 capped (sibling towncrier's
  :audit extension not yet shipped).` to a pointer to the new
  translation rules section: `Sibling towncrier's /towncrier:audit
  --json emits a v2 wire-contract envelope with four observations
  consumed by the event-emission translation rules below.`. Match
  the row-rewrite shape used post-2a3 / post-2b3 for
  `code-documentation` and `lint-posture`.
- Add a new `### event-emission translation rules` section after
  the existing translation-rules sections. Stanza JSON above plus
  a hand-walked verification paragraph mirroring 2a3 / 2b3's
  shape. Document the metrics-count "configured-but-unused → 50"
  band-edge anchor explicitly so a reader doesn't trip on the
  hybrid count semantics.

### Variance harness shape

Towncrier's audit path is **fully mechanical** post-2c3 —
orchestrator (`bin/build-envelope.sh`) + four deterministic shell
scorers + the translator, with no model in the loop — so the
per-dimension `event-emission` stddev is structurally 0.0 across
N runs. Per-fixture N=10 against this pipeline measures variance
from a source that has none, so the mechanical-determinism bar is
carried by triple-run byte-equivalence in the snapshots test rather
than an N=10 eval-harness run per fixture.

This deviates from the original 2c3 plan-line (which called for
"per-dimension stddev ≤ 1.0 and grade-flip rate ≤ 5% over N=10 on
the fixture set") and mirrors the deviation 2b3 adopted for
lintguini and 2a3 adopted for inkwell. See 2b3's "Eval harness
verification" section and 2a3's "Variance harness shape" section
for the precedent.

For 2c3:

- **Snapshots test** (`plugins/towncrier/tests/fixtures/snapshots.test.sh`)
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
  `event-emission` per-dimension stddev ≤ 1.0 (structurally 0 for
  a mechanical path). No regression on `claude-code-config`,
  `skills-quality`, `commit-hygiene`, `code-documentation`,
  `lint-posture`.
- **No per-fixture N=10 on the towncrier python-low/mid/high
  fixtures.** Snapshots-test triple-run replaces it.

**Caveat on the deviation's universal applicability.** This
deviation holds *only* because all four 2c2 scorers stay
mechanical. If during 2c2 implementation any scorer is found to
genuinely need LLM judgment (the
`score-event-schema-consistency.sh` heuristic is the most
plausible candidate — domain-anchor identification is fuzzier than
the other three signals), that scorer's calibration would need
per-fixture N=10. The snapshot test's byte-equivalence assertion
would catch the variance as a test failure; the calibration would
then have to land via the eval harness against the noisy signal.
2c2's acceptance bar requires all four scorers be mechanical, so
this caveat is theoretical at 2c3 PR time — but if 2c2 ships with
a judgment-shaped scorer, the deviation does not hold for that
scorer's calibration and 2c3 must add per-fixture N=10 for it
specifically.

## Implementation order

1. **`plugins/pronto/references/rubric.md`** — add the
   `event-emission` translation rules stanza; flip the table row
   description and status column; remove the `towncrier's :audit
   extension` reference from the Phase-2+ list paragraph; rewrite
   the mechanical-vs-judgment row.
2. **`plugins/pronto/references/recommendations.json`** — populate
   `install_command`, `audit_command`, flip `plugin_status` to
   `shipped`. `parser_agent` stays `null` (see Discovery posture).
3. **Pronto version bump** — `plugin.json`, `marketplace.json`,
   root README. Minor bump (rubric stanza addition is a behavioural
   change to the scoring path). Implementation determines the
   value from the version-check convention; mirrors the pronto
   bump 2a3 (v0.3.0 → v0.4.0) and 2b3 (v0.2.1 → v0.3.0) shipped
   under. Don't pin the value in this ticket — read the convention.
4. **`plugins/towncrier/bin/build-envelope.sh`** — new orchestrator
   script per the architecture section above. The orchestrator
   runs the four scorers in fixed order and slurps non-empty
   stdouts into the envelope's `observations[]` array;
   `composite_score` is `null`.
5. **`plugins/towncrier/skills/audit/SKILL.md`** — replace the
   2c1 empty-envelope emission with a thin dispatcher that invokes
   the orchestrator and emits its stdout verbatim.
6. **Towncrier version bump** — `plugin.json`, `marketplace.json`,
   root README. Minor bump (sibling now consumes the rubric path;
   orchestrator behaviour changes from empty-envelope to populated).
   Implementation determines the value from the version-check
   convention.
7. **`plugins/towncrier/tests/fixtures/{python-low,python-mid,python-high}/`** —
   populate the three fixture directories. Each gets a tailored
   `pyproject.toml`, `src/` tree, and `handlers/` tree with
   controlled inputs producing the predicted observation values
   from the calibration table.
8. **`plugins/towncrier/tests/fixtures/<fixture>/envelope.json`** —
   capture the three populated envelopes by running
   `bin/build-envelope.sh` against each fixture and committing the
   output verbatim. Locks the byte-equivalence anchor for invariant
   B.
9. **`plugins/towncrier/tests/fixtures/snapshots.test.sh`** —
   per-fixture envelope diff against the locked `envelope.json`,
   plus the `$schema_version`, observation-ID set, and
   translator-applied composite assertions. Mirror inkwell's
   snapshots.test.sh.
10. **`plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh`** —
    extend with a stub `event-emission` translation rules stanza
    (byte-identical to the real rubric.md stanza) and band-coverage
    cases for each of the four observations plus composite cases
    for `python-low`/`python-mid`/`python-high`. Includes explicit
    band-edge cases for the `metrics-instrumentation-count`
    hybrid (`else 50` for configured-but-zero-sites, `gte 1 → 70`
    for just-instrumented).
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
- Translator (`observations-to-score.sh event-emission`) consumes
  each fixture's envelope and produces the predicted dimension
  score (python-low → 35, python-mid → 81, python-high → 100)
  within ±1.
- The `python-low` fixture exercises the bait-and-switch case: the
  kernel-level `event-emission` presence check (greps for
  `opentelemetry`, `OTEL_`, `tracer`, `metric`, `event_bus`,
  `eventbus`, `emit(`, `structlog`, `pino`, `winston`, `logrus`)
  matches against the fixture's `pyproject.toml` and source
  imports, but the populated rubric stanza scores it at 35 (F).
  Surface-level presence does not silently inflate the composite.
- `observations-to-score.test.sh` passes — existing test cases
  stay green and the new `event-emission` block exercises every
  band edge (including the metrics-count `else 50` band) plus the
  three composite cases.
- `snapshots.test.sh` passes for all three fixtures.
- `pronto` and `towncrier` both bump versions in
  `plugin.json` / `marketplace.json` / root README per the
  marketplace versioning convention; `./scripts/check-plugin-versions.sh`
  exits 0.
- `recommendations.json`'s `event-emission` row reads
  `plugin_status: shipped`, with `install_command` and
  `audit_command` populated; `parser_agent` stays `null` per the
  Discovery posture rationale.
- `rubric.md` carries the new `### event-emission translation
  rules` section and the table-row + Phase-2+-list updates.
- The `event-emission` row no longer falls through to the
  presence-cap behaviour (50 capped from kernel check); it lands
  the rubric-derived score on every audit.
- Eval harness on `mid` (N=10): per-dimension `event-emission`
  stddev ≤ 1.0 (structurally 0 for a mechanical path), composite
  stddev ≤ 1.0, grade-flip rate ≤ 5%. No regression on
  `claude-code-config`, `skills-quality`, `commit-hygiene`,
  `code-documentation`, `lint-posture` per their existing snapshot
  tests.
- No regression on the other rubric dimensions — claudit, skillet,
  commventional, inkwell, lintguini all still pass their
  `snapshots.test.sh`.
- No changes to `plugins/claudit/`, `plugins/skillet/`,
  `plugins/commventional/`, `plugins/inkwell/`, `plugins/lintguini/`,
  or `plugins/avanti/` (verified via
  `git diff main..2c3-towncrier-contract-fixtures -- 'plugins/!(towncrier)/'`
  showing only `plugins/pronto/` paths).

## Three load-bearing invariants

A. **End-to-end determinism.** Same fixture filesystem → same
envelope JSON bytes across three runs per fixture. The four scorers
are verified deterministic individually under 2c2's tests; 2c3's
`snapshots.test.sh` extends the verification across the full audit
flow per fixture profile. Triple-run byte-equivalence is the
acceptance bar; per-fixture N=10 is replaced by it (see Variance
harness shape).

B. **Calibration-table fidelity.** The hand-walked predicted score
table above must reproduce within ±1 under the translator path.
Drift here means the rubric stanza is mis-tuned against the fixture
inputs and the fix is in either the stanza bands or the fixture
construction (whichever is wrong) — not in hiding the drift behind
looser acceptance thresholds. Verified by translator unit-test
extension covering every band edge per observation.

C. **No knock-on regression.** Adding a fully-shipped sibling
shouldn't perturb the existing dimensions. The eval harness on
`mid` still produces composite stddev ≤ 1.0 with all four legacy
siblings + inkwell + lintguini + towncrier active; the existing
snapshot tests for claudit, skillet, commventional, inkwell, and
lintguini all pass byte-equivalent. Run them all in a single CI
sweep before declaring 2c3 done.

## Out of scope

- **Removal of any transitional parser agent.** None was shipped
  by 2c1 (per its File tree section), so there's nothing to retire.
  Mirrors lintguini 2b3's posture, modulo the file-existed-and-was-
  filed-as-follow-up wrinkle 2a3 / 2b3 each carry. Towncrier
  shipping post-precedent skips that step entirely.
- **Per-fixture eval-harness N=10.** Replaced by snapshots-test
  triple-run for the mechanical-determinism bar (deviation from
  the original 2c3 plan-line — see "Variance harness shape" above
  for rationale). 2a3 and 2b3 set the precedent. Cross-sibling
  regression on the pinned `mid` worktree carries forward.
- **Multi-language fixture extension.** 2c3 ships single-language
  python low/mid/high. Extension to typescript, go, rust, or
  javascript is filed as follow-up if calibration shows python is
  insufficient. Mirrors lintguini's posture in reverse — lintguini
  shipped three languages because per-language strictness baselines
  diverged enough to need separate calibration; towncrier's depth
  signals (structured logging, metrics, trace, schema consistency)
  share enough conceptual shape across languages that python's
  calibration is expected to cover the others without re-tuning.
- **Within-dimension weight rebalancing.** The plan calls for equal
  quarters as the starting position; once fixtures calibrate, 2c3
  may tune. If a signal is dominant or dead in practice, raise a
  follow-up — don't rebalance under the same ticket without harness
  evidence.
- **PII-mask detection scorer.** `roll-your-own/event-emission.md`
  enumerates "sensitive data masked at emission" as a depth signal
  but mechanizing it deterministically is fixture-led work that
  hasn't been scoped (false-positive risk on legitimate field
  names like `email_template_id`). Out of scope for 2c3; revisit
  if calibration suggests the signal is missable.
- **Migration of any other sibling to step-1 discovery.** Claudit,
  skillet, commventional all migrated under M1/M2/M3. Inkwell ships
  step-1-ready in 2a3. Lintguini ships step-1-ready in 2b3.
  Towncrier ships step-1-ready in 2c3.
- **Towncrier hook surface.** `bin/emit.sh` and `hooks/hooks.json`
  are unchanged through the entire 2c track. The audit skill is a
  parallel entry point that does not interact with the hook handler.
- **Network-aware lint / metrics / trace scoring.** Pure source-file
  inspection only, matching 2c2's invariant.

## References

- `project/plans/active/phase-2-pronto.md` — PR 2c 2c3 paragraph,
  acceptance bar, autopompa references enumeration (2c1 swept the
  references; 2c3 lights up the dispatch path).
- `project/tickets/open/phase-2-2c1-towncrier-audit-extension.md` —
  scaffold + autopompa references sweep this ticket completes.
- `project/tickets/open/phase-2-2c2-towncrier-scorers.md` —
  scorers this ticket wires in.
- `project/tickets/closed/phase-2-2a3-inkwell-contract-fixtures.md` —
  the canonical 2a3 pattern this ticket mirrors. Same three-fixture
  layout (single-language low/mid/high), same Discovery posture
  (`parser_agent: null`), same Variance harness shape (snapshots
  triple-run replacing per-fixture N=10).
- `project/tickets/closed/phase-2-2b3-lintguini-contract-fixtures.md` —
  the precedent for the Discovery posture rationale and the
  Variance harness deviation. Commit `f90cc5e` carries the
  parser_agent: null rationale across 2b3 / 2a3 / 2c3.
- `project/tickets/closed/phase-2-h3-wire-contract-schema-2.md` —
  wire-contract schema 2 + observations[] field this envelope
  emits against.
- `project/tickets/closed/phase-2-h4-observations-aware-scorer.md` —
  the translator + rubric path this stanza calibrates against.
- `project/tickets/closed/phase-2-passthrough-deprecation.md` —
  case-3 carve-out semantics towncrier relies on for empty-scope
  short-circuit.
- `project/tickets/closed/phase-2-m3-commventional-observations-emission.md` —
  the structural template this ticket draws on for envelope
  shape, calibration verification table, and snapshots-test layout.
- `plugins/pronto/references/rubric.md` — file edited by this
  ticket to add the `event-emission` translation rules stanza
  and to rewrite the row + mechanical-vs-judgment description.
- `plugins/pronto/references/recommendations.json` — file edited
  by this ticket to populate the `event-emission` row.
- `plugins/pronto/references/sibling-audit-contract.md` — wire
  contract the populated envelope conforms to.
- `plugins/pronto/references/roll-your-own/event-emission.md` —
  source of the depth signals these scorers operationalize and
  the rubric stanza calibrates against.
- `plugins/pronto/agents/parsers/scorers/observations-to-score.sh` —
  the translator this stanza is consumed by.
- `plugins/pronto/agents/parsers/scorers/observations-to-score.test.sh` —
  test file extended with the `event-emission` four-obs stanza.
- `plugins/inkwell/bin/build-envelope.sh` — the orchestrator shape
  towncrier's `bin/build-envelope.sh` mirrors.
- `plugins/inkwell/tests/fixtures/snapshots.test.sh` — the snapshots
  test pattern towncrier's `snapshots.test.sh` mirrors.
- M1 PR #61, M2 PR (skillet), M3 PR — canonical patterns this
  ticket draws on for envelope shape, calibration verification,
  and fixture set layout.
