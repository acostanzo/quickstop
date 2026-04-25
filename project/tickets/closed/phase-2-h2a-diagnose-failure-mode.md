---
id: h2a
plan: phase-2-pronto
status: closed
updated: 2026-04-25
---

# H2a — Diagnose orchestrator JSON-emission failure mode

## Scope

The phase-2-pronto plan flagged orchestrator JSON-emission reliability
as the gating hardening item before three more siblings dispatch through
the same code path. Phase 1.5 PR 3b recorded **1/10 baseline → 3/10
post-T5** non-JSON failures (per `phase-1-5-a2-harness-proof.md`) and
explicitly deferred the diagnosis. H2a closes that gap: instrument
failing invocations, classify them, and name the dominant failure mode
with supporting evidence.

H2a-instrumentation (PR #51, merged 2026-04-25 at `b5bd436`) shipped the
eval-harness changes needed to produce the diagnosis. This ticket closes
on the diagnosis itself — the measurement campaign that ran post-merge.

## Harness invocation

The instrumented harness at `plugins/pronto/tests/eval.sh` was run with
the model pinned and per-run artefacts preserved:

```bash
./plugins/pronto/tests/eval.sh \
    --n 25 --fixture mid --model sonnet \
    --preserve-runs /tmp/h2a-pilot-continue \
    --output /tmp/h2a-pilot-continue-results.json
```

A first batch with `--n 30` was launched earlier the same day under
identical arguments (preserved at `/tmp/h2a-pilot/`). Runs 21-30 of
that first batch hit a Claude CLI rate limit (`You've hit your limit ·
resets 8:20pm (UTC)`, exit 1, ~1-2s per run) and were excluded from the
organic dataset. Runs 1-20 of the first batch are clean and combine
with the full continuation N=25 for a final **N=45 organic invocations**
against the `mid` fixture (quickstop pinned at sha `7650b49`).

## Measurement

| Bucket | Count | % of failures | % of all runs |
|---|---:|---:|---:|
| `prose-contamination` | 16 | 76.2% | 35.6% |
| `refusal-or-empty` | 3 | 14.3% | 6.7% |
| `contract-violation` | 2 | 9.5% | 4.4% |
| **Total failures** | **21** | **100%** | **46.7%** |
| Successful invocations | 24 | — | 53.3% |

Failure rate landed at 21/45 (46.7%) — substantially higher than the
Phase 1.5 baseline window (10–30%) but resting on a much larger N. The
instrumented harness now has per-run stdout/stderr/meta.json preserved
for every failure, so this is the most reliable failure-rate figure
pronto has had.

Successful runs took median **341s** (min 266, max 624). Failed runs
took median **224s** (min 136, max 472) — failures finish faster, which
is consistent with abort-mid-orchestration → premature emission.

## Dominant mode: `prose-contamination` (16/21, 76%)

Of the 16 prose-contamination failures, the recorded `json_at_offset=A-B`
sub-reasons split cleanly by the JSON span size into two sub-shapes with
*different root causes and different remediation paths*:

- **Sibling sub-audit echo (range ≈ 390 bytes): 11 of 16** — 52.4% of
  all failures, 68.8% of prose-contamination.
- **Preamble + full envelope (range ≈ 7000–8500 bytes): 5 of 16** —
  23.8% of all failures, 31.3% of prose-contamination.

### Sub-shape A — Sibling sub-audit echo (11/21)

The orchestrator emits the **avanti sub-audit's** JSON envelope as its
own final output, not its own composite envelope. The leak is verbatim:
avanti's own output preface bleeds through unchanged. Sample
(continuation/run-25, first ~500 bytes of stdout):

```
All categories clean. Emitting avanti:audit JSON:

{"plugin":"avanti","dimension":"project-record",
 "categories":[{"name":"Plan freshness","weight":0.30,"score":100,...}],
 "composite_score":100,"letter_grade":"A+","recommendations":[]}
```

The preamble names avanti by plugin name (`Emitting avanti:audit JSON:`)
— this is avanti's own emission language, not pronto's. What ships to
pronto's stdout is therefore the avanti sub-audit's entire emission
pipeline, prose preface and all. The shape is avanti's (`plugin`,
`dimension`, `letter_grade`), not pronto's composite shape
(`schema_version`, `repo`, `composite_score`, `dimensions[]`). All 11
echo-shape failures show this same pattern — sometimes the avanti JSON
verbatim, sometimes only avanti's preceding reasoning prose with the
JSON truncated by the parser at the obvious next-JSON-or-EOF boundary.

**Why exclusively avanti.** Avanti is the only sibling in the current
constellation whose dispatch goes through the slash-command path:
`recommendations.json` declares `audit_command: /avanti:audit --json`
with `parser_agent: null`. Claudit, skillet, and commventional all
dispatch via parser-agent (Task subagent), which is the path Phase 1.5
PR 3b mechanized. The slash-command path apparently lets the
sub-audit's output bleed into the orchestrator's own stdout slot. The
parser-agent path (Task tool with explicit return-value capture)
doesn't show this failure mode in any of the 21 failures.

This is a wire-level isolation problem, not a content-level contract
problem. The orchestrator received a value from a sub-Claude and treated
that value as a candidate for its own emission slot.

### Sub-shape B — Preamble + full envelope (5/21)

The orchestrator completes the audit correctly and emits the **full**
composite envelope, but prefixes it with a one-sentence courtesy
preamble. Sample (continuation/run-23):

```
State persisted. Emitting the composite JSON now.

{"schema_version":1,"repo":"/tmp/pronto-eval-fixture-mid-720536",
 "timestamp":"2026-04-25T18:37:00Z","composite_score":61,...}
```

Despite SKILL.md Phase 6 explicitly stating *"No prose preamble
('Emitting the JSON composite...', 'Here is the output:')"* — the
preamble lands anyway. This is contract-violation by omission: the
sub-Claude reads the contract, agrees with it, then preludes the JSON
with exactly the kind of sentence the contract names as forbidden. Pure
instruction-following gap; the actual audit is fine.

## Other modes

### `refusal-or-empty` (3/21, 14%)

Two empty-stdout (sub-Claude returned with exit 0 but emitted nothing),
one `no-json` (refusal phrasing in stdout, no parseable JSON anywhere).
Could be context-length symptoms rather than contract-following gaps;
the meta.json evidence is preserved for follow-up.

### `contract-violation` (2/21, 10%)

Both ran to completion and emitted *valid* JSON, but the JSON's shape
was incomplete — `grade-missing,dimensions-empty`. The orchestrator
appears to have skipped Phase 5 aggregation entirely. The same
structural lever that would address sub-shape A's echo would likely
catch this too (both are "orchestrator emitted partial state as if it
were complete state").

## Pass criteria vs measurement

| Criterion (per phase-2-pronto plan §H2a) | Bar | Measured | Pass |
|---|---|---|---|
| Sample size | ≥ 20 failing invocations | 21 | ✓ |
| Dominant failure mode named | required | `prose-contamination` (76%) | ✓ |
| Supporting evidence | required | per-run stdout/stderr/meta.json preserved for all 45 runs | ✓ |

## Recommendation for H2b

The dominant mode is prose-contamination (16/21, 76%). Within it, the
sibling sub-audit echo sub-shape (11/21) outweighs the preamble
sub-shape (5/21) roughly 2:1 — but they are structurally different
bugs and H2b should address both, in priority order.

**Lever 1 — slash-command sub-audit isolation (highest-leverage; 11/21 directly, 13/21 with contract-violation catch).**

The avanti sub-audit's JSON is leaking to stdout because the
slash-command dispatch path doesn't wall off the sub-Claude's output
from the orchestrator's emission slot. SKILL.md Phase 4.1 (parser dispatch) is explicit; the slash-command
dispatch branch of Phase 4 is not.
Candidates for H2b:

- (a) **Tighten Phase 4** with an explicit invariant: when invoking
  `/<plugin>:audit --json`, the sub-audit's JSON is a **bound value**
  used in Phase 5 aggregation, never echoed to stdout. The orchestrator's
  first byte to stdout is `{` from its own composite envelope in Phase 6.
- (b) **Add a Phase 5/6 sentinel** that requires `composite_score` at the
  top level of the about-to-emit JSON; refuse to emit anything that
  matches the sub-audit shape (`plugin`, `dimension`, `letter_grade`) at
  the top level.
- (c) **Migrate avanti to a parser-agent** matching the
  claudit/skillet/commventional pattern. Parser-agent dispatch through
  the Task tool has explicit return-value capture and shows zero leaks
  across 45 runs. This is the most decisive fix, but it's avanti
  scope, not pronto scope; deferred unless (a) and (b) prove
  insufficient.

The same lever also catches the 2 `contract-violation` failures
(`grade-missing,dimensions-empty`) — both shipped partial composite
state where the sentinel would have caught the missing fields.

**Lever 2 — Phase 6 contract reinforcement (5/21).**

Despite the explicit Phase 6 prohibition, 5 runs prefixed the JSON
with a preamble. Candidates for H2b:

- (a) Move the prohibition to a more prominent position (currently in
  Phase 6 "Hard rules", buried after a markdown bullet list).
- (b) Add a worked counter-example showing a forbidden preamble
  immediately followed by the correct JSON-only output.
- (c) Rephrase in stronger imperative form ("Your first byte to stdout
  is `{`. Anything before it is a bug.").

Output-format flags (`--output-format json`, `outputStyle`,
`--json-schema`) are validation-and-protocol layers, not discipline
knobs — they do not address the underlying instruction-following gap
that drives both sub-shapes and were considered out of scope for the
H2b lever.

**Smaller targets after the main levers:**
- Refusal/empty (3/21) — investigate whether the sub-Claude is exiting
  the audit-skill SKILL.md context before completing; possibly a
  context-length symptom rather than a contract-following one.

H2b's acceptance bar from the plan is ≥ 95% success rate over N=20.
Today's 53.3% success rate (24/45) needs to climb to that bar. The
specific lever choices and sequencing above are H2b scope, not this
ticket.

## Artifacts preserved

- `/tmp/h2a-pilot/run-{1..20}.{stdout,stderr,meta.json}` — clean pilot
  partition (rate-limit-polluted runs 21-30 excluded from combined
  dataset but preserved for forensics).
- `/tmp/h2a-pilot/eval-results.json` — first batch aggregate.
- `/tmp/h2a-pilot-continue/run-{1..25}.{stdout,stderr,meta.json}` —
  continuation pilot.
- `/tmp/h2a-pilot-continue-results.json` — continuation aggregate.
- `/tmp/h2a-combined.jsonl` — combined N=45 organic dataset (one
  meta.json record per line, with `dir` field marking source batch).

Paths are machine-local on `batdev`. Numbers above are quoted from
`jq` queries against the per-run meta.json files; reproduce by
re-running the harness with `--preserve-runs <dir>`.

## Links

- Plan: `project/plans/active/phase-2-pronto.md` (PR H2 / H2a).
- Surface H2b will likely tighten:
  `plugins/pronto/skills/audit/SKILL.md` Phase 4 (sibling dispatch) and
  Phase 6 (emit rules).
- Phase 1.5 antecedent:
  `project/tickets/closed/phase-1-5-a2-harness-proof.md` (recorded the
  original 1/10–3/10 failure-rate figures this ticket re-measured at
  higher N).
- Instrumentation PR: acostanzo/quickstop#51 (merged 2026-04-25).
- Branch: `feat/h2a-diagnose-failure-mode`.
