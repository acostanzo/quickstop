---
id: h2c
plan: phase-2-pronto
status: open
updated: 2026-04-26
---

# H2c — Close the orchestrator preamble-emission residual

## Scope

H2b closed the avanti slash-command sub-audit echo (the dominant H2a
failure mode) by routing `project-record` through parser-agent dispatch
(PR #55 levers 1+2 SKILL.md edits + PR #56 lever 3 dispatch swap). The
N=20 measurement on the `mid` fixture hit **18/20 success (90%)** — one
passing run short of the H2b plan's `≥ 95%` acceptance bar.

Both residual failures are the same shape, distinct from anything
lever 3 could close. H2c names that shape and tracks the remediation.

## The residual mode

A correctly-formed composite envelope preceded by ~50–75 bytes of
orchestrator narration:

```
State persisted. Emitting composite envelope.

{"schema_version":1,"repo":"...","composite_score":45,...}
```

Both H2b-followup N=20 failures (run 3 offset 47–6463, run 17 offset
75–4703) are this shape. The composite envelope itself passes shape
validation (`schema_version` present, `dimensions[]` populated,
`composite_score` integer). The contract-violating bytes are entirely
the orchestrator's own narration *before* the JSON.

## Why H2b's lever 2 didn't close it

H2b lever 2 (PR #55, commit `d735dc0`) hoisted the structural rule from
a buried Hard-rules bullet to the Phase 6 section opening:

> first byte on stdout is `{` from that envelope, last byte is `}` from
> that envelope, nothing precedes either, no preamble, no trailing
> narrative.

The hoist attenuated the rate but did not eliminate it. The orchestrator
follows the rule most of the time and ignores it on a stable minority
of runs. This is an **instruction-following ceiling** — a structural
limit on the orchestrator's adherence to a Phase 6 self-check that
can't be closed from inside SKILL.md prose alone.

The N=20 from PR #56 measured this directly: lever 3 eliminated avanti-
shape failures (0/20 vs H2a's 11/30 ~37%), and the residual rate
(2/20 ~10%) is purely this preamble class.

## Candidate levers

Both shift the closure work outside the orchestrator's instruction-
following surface:

1. **Phase 6 hard guard (bash-level).** A deterministic shell
   post-processor between the orchestrator's emit step and pronto's
   stdout: strips leading whitespace and any non-JSON prefix, validates
   the result is a single JSON object with the composite-envelope
   discriminators (`schema_version` and `dimensions[]`), refuses-and-
   retries otherwise. Implementation lives in pronto's audit skill,
   not in SKILL.md prose.

2. **Composite envelope assembly via tool, not free-form emit.** The
   orchestrator builds per-dimension state inline, then a final
   `compose_composite.sh` script reads the state and emits the JSON
   envelope to stdout. The orchestrator's own stdout is reserved for
   that script's output only — there is no LLM-controlled emit step
   to leak narration through.

(2) is the cleaner architectural shape; (1) is the lower-risk
incremental fix. Both should be evaluated against the same N=20 bar.

## Acceptance

`./plugins/pronto/tests/eval.sh --n 20 --fixture mid --model sonnet`
returns **≥19/20 (95%)** with zero `prose-contamination` failures of
the preamble shape. Combined with H2b-followup's 0/20 avanti-shape
failures, this clears the Phase 2 H2 hardening bar end-to-end.

## Out of scope

- The three deferred R1 secondary findings on `score-avanti.sh`:
  pulse-cadence absent-dir scoring (currently 100, R1 argued for 0
  to match avanti's "exists but empty → 0" rubric intent), jq float
  multiply (deterministic in practice but technically violates the
  no-floating-point determinism spec), `${sup_id##0}` leading-zero
  strip (rarely triggers). These are scorer hygiene, separate from
  the orchestrator preamble bug. File as a follow-on if/when they
  start mattering against a fixture that exercises them.

- The composite stddev observation from H2b-followup's first N=20:
  successful runs split between composite=61/grade=C and
  composite=40/45/50/grade=D, with the variance coming from
  `claude-code-config`, `skills-quality`, `commit-hygiene` (not
  `project-record`, which is now pinned at 100). Worth a separate
  investigation but unrelated to the orchestrator preamble bug.

## References

- `project/plans/active/phase-2-pronto.md` — H2b acceptance bar
  (`≥ 95% over N=20` on `mid` fixture)
- `project/tickets/closed/phase-2-h2a-diagnose-failure-mode.md` — the
  H2a writeup that named the prose-contamination bucket and split
  it into sub-shape A (avanti echo, closed by lever 3) and sub-shape
  B (preamble + envelope, this ticket)
- PR #55 — H2b levers 1+2 (Phase 4 isolation invariant, Phase 6 sentinel)
- PR #56 — H2b-followup lever 3 (avanti parser-agent migration), the
  N=20 that produced the 18/20 measurement this ticket cites
- N=20 run artefacts: `/tmp/h2b-followup-n20-real/` on batdev (preserved
  for forensic review)
