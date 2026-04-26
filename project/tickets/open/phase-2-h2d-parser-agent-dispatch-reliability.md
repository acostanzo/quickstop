---
id: h2d
plan: phase-2-pronto
status: open
updated: 2026-04-26
---

# H2d — Close the parser-agent dispatch reliability gap

## Scope

H2b-followup's N=20 on the `mid` fixture left a 90% top-line. Beneath
that headline, per-dimension forensics reveal that three of the four
parser-agent-dispatched siblings silently fail dispatch on a sizeable
fraction of runs and degrade to the presence-cap-50 fallback. The
composite envelope still validates (so the run "passes"), but the score
under it is the cap, not the deterministic scorer's output.

H2c (orchestrator preamble) is a 10% structural-instruction gap on the
emit boundary. H2d is a 33–61% dispatch gap on the parser boundary —
larger in magnitude, broader in blast radius, and the directly
load-bearing reliability concern for **all** Phase 2 sibling work.

## The measurement

From `/tmp/h2b-followup-n20-real-results.json` (N=18 successful runs,
post-`b84ff2f`):

| Dimension | Parser | Successful score | At cap (50) | Dispatch success rate |
|-----------|--------|------------------|-------------|-----------------------|
| `project-record` | parse-avanti | 100 (×18) | 0/18 | **100%** |
| `skills-quality` | parse-skillet | 97 (×12) | 6/18 | **67%** |
| `claude-code-config` | parse-claudit | 96 (×7) | 11/18 | **39%** |
| `commit-hygiene` | parse-commventional | 82 (×8) | 10/18 | **44%** |

Five dimensions don't go through parser dispatch and have stddev=0
(four orchestrator-internal scorers, plus `agents-md` / `lint-posture`
which scored 0 because the fixture lacks AGENTS.md and a linter).

## The failure shape

From run-1's `sibling_integration_notes` (representative of the
non-pass-through runs):

```
claudit: parse-claudit parser returned invalid output (prose, not JSON);
  degraded claude-code-config to .claude/ presence fallback; capped at 50.
skillet: parse-skillet parser returned no output; degraded skills-quality
  to presence fallback; capped at 50.
commventional: parse-commventional parser returned no output; degraded
  commit-hygiene to presence fallback; capped at 50.
```

Two distinct sub-shapes:

1. **Prose around the script output** — the parser agent ran the
   scorer but framed its return with explanatory text, violating the
   byte-identical-output contract.
2. **Empty return** — the parser agent returned nothing, suggesting
   either an early refusal or a tool-call shape that didn't surface
   stdout to the orchestrator.

The orchestrator's defensive degradation handles both correctly (Phase
4.1's `On invalid return, degrade to the presence fallback and append a
note to sibling_integration_notes`). That's why the runs still pass
shape validation. The problem is that "pass" hides the score collapse.

## Why parse-avanti escapes this

parse-avanti, parse-claudit, parse-commventional, parse-skillet all
share the same refusal-heavy frontmatter structure (67–77 lines each;
diff is descriptive prose only). Empirically, parse-avanti dispatches
100% successfully and the others 33–67%. The structural difference is
not in the agent files themselves.

Hypotheses to test:

1. **Scorer script differences.** Does score-avanti.sh produce a more
   compact, more obviously-JSON output than the other three? Compare
   stdout byte counts and shapes.
2. **Frontmatter strength.** Is there a subtle ordering or wording in
   parse-avanti's refusal language that the others don't replicate?
   Lift the strongest version and apply to all four.
3. **Invocation context.** parse-avanti is invoked from a freshly-
   restructured Phase 4 sub-path (post-`b84ff2f`), the others from
   the older "Other dimensions" decision tree. The orchestrator may
   construct the parser invocation differently in each path.
4. **Tool-call reasoning load.** The parser agents are dispatched
   serially by the same orchestrator; later dispatches may inherit
   accumulated context that nudges them off the deterministic path.

## Candidate levers

Both shift closure outside the parser-agent's own instruction-following:

1. **Bash-level wrapper between Task return and orchestrator capture.**
   Same shape as H2c's lever 1: a deterministic post-processor that
   strips non-JSON prefix/suffix and validates the dimension contract
   before handing the result to the orchestrator. Implementation lives
   in the audit skill, not in the parser-agent prose.

2. **Direct shell dispatch instead of Task-tool dispatch.** The
   parser-agent layer exists because the slash-command path leaked
   pronto's stdout (closed by H2b lever 3 for avanti). For these three
   siblings, where there is no slash command and the underlying scorer
   is already deterministic, the audit skill could invoke the scorer
   script directly via Bash and skip the LLM-controlled parser-agent
   step entirely. The agent file remains as a fallback registration
   in `recommendations.json`, but the hot path is shell.

(2) is the cleaner architectural shape if it works — it removes an
LLM layer from the score path entirely. (1) is the defensive lower-risk
incremental fix.

## Acceptance

`./plugins/pronto/tests/eval.sh --n 20 --fixture mid --model sonnet`
returns dispatch success ≥ 95% per parser-dispatched dimension (i.e.
each of `claude-code-config`, `commit-hygiene`, `skills-quality`,
`project-record` returns its deterministic score on ≥19/20 runs, with
fewer than one fall-through to presence-cap-50 each). Composite stddev
collapses correspondingly.

## Why this matters for Phase 2

The Phase 2 sibling rollout (2a-inkwell, 2b-lintguini, 2c-towncrier)
adds three more parser-dispatched siblings on the same architectural
shape. If parser dispatch succeeds 33–67% of the time, those siblings
will land with the same silent-cap behaviour, and pronto's composite
will become increasingly noisy as more siblings are added. H2d closes
the boundary before that compounding lands.

## Out of scope

- The H2c orchestrator-preamble residual (separate ticket; the
  emission-boundary instruction-following gap, not the dispatch-
  boundary one).

- The five dimensions with stddev=0 in this measurement
  (`code-documentation`, `event-emission`, `agents-md`,
  `lint-posture`, `project-record`). They're stable; this ticket is
  about the noisy three.

- The R1-secondary score-avanti.sh hygiene findings (pulse cadence,
  jq float multiply, leading-zero strip) — file separately when a
  fixture exercises them.

## References

- `project/plans/active/phase-2-pronto.md` — Phase 2 sibling rollout
- `project/tickets/closed/phase-2-h2a-diagnose-failure-mode.md` —
  the H2a writeup that named the orchestrator-side prose-contamination
  bucket; H2d names the parser-side dispatch-failure bucket
- `project/tickets/open/phase-2-h2c-orchestrator-preamble-emission.md`
  — the sibling ticket on the emit-boundary residual
- N=18-pass artefacts at `/tmp/h2b-followup-n20-real/` on batdev
  (preserved for forensic review). `run-1.normalized.json` is
  representative of the cap-50 shape; `run-7.normalized.json` shows
  a successful claudit dispatch (96)
- PR #56 — H2b-followup lever 3 (parse-avanti migration), the
  reference implementation that this ticket extends to the other
  three parsers
