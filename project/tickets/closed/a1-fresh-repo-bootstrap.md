---
id: a1
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# A1 — Fresh-repo bootstrap + audit

## Scope of this record

A-bars were re-run against a real fixture — not just hand-computed. What remains
deferred: the live `/pronto:init` AskUserQuestion flow and the in-session parser
subagent dispatch. Everything below was executed, and the run surfaced a defect
fixed in this same commit.

## Procedure (executed)

1. `FIXTURE=$(mktemp -d -t pronto-a1-XXXXX) && cd $FIXTURE && git init -q` — resolved to `/tmp/pronto-a1-lA8NA`.
2. Scaffolded per `skills/init/SKILL.md`: empty repo triggers the all-`write`
   collision path. Each template source copied to the matching target:
   `AGENTS.md`, `project/README.md` + `plans/tickets/adrs/pulse/.gitkeep`,
   `.claude/README.md`, `.pronto/state.json`. `.gitignore` did not exist, so
   the full template content was written verbatim (Phase 3.5 "else" branch).
3. Ran the `skills/kernel-check/SKILL.md` Phase 1 Bash scan, timed under zsh.
4. Ran the orchestrator's Phase 4 decision tree + Phase 5 aggregation as a
   Python transcription of the SKILL text, against the real fixture state.

## Defect found + fix (this commit)

**Root cause.** `skills/kernel-check/SKILL.md` Phase 1 used `for path in ...` as
the file-iteration loop variable. In zsh, `path` is tied to `PATH` as a
scalar/array dual — assigning inside the loop clobbers `PATH`, after which
`wc` is no longer on the search path and every line count returns `0`.

**Evidence.** Under zsh:

```
$ zsh -c 'for path in AGENTS.md; do echo "lines=$(wc -l < /tmp/.../AGENTS.md)"; done'
zsh: command not found: wc
lines=
```

Same block with `for f in ...` returns `lines=36`. Under bash the bug is
latent (bash does not link `path` to `PATH`).

**Impact on A1's scorecard pre-fix.** `AGENTS.md scaffold` would score 0
(reported as 0 lines < 5 threshold) → `agents-md` dimension (kernel-owned)
drops from 100 to 0 → composite falls from 25/F to 15/F.

**Fix.** Rename the loop variable `path` → `f` (and `dir` → `d`) in
`skills/kernel-check/SKILL.md` Phase 1, with an inline comment warning
future editors about the four tied names (`path`, `manpath`, `cdpath`, `fpath`).

## Results (post-fix, executed under zsh)

**Kernel scan output** (exact):

```
EXISTS:AGENTS.md:36
MISSING:README.md  MISSING:README  MISSING:README.rst
MISSING:LICENSE  MISSING:LICENSE.md  MISSING:LICENSE.txt  MISSING:COPYING
EXISTS:.gitignore:6
DIR_EXISTS:.claude  DIR_EXISTS:.pronto
DIR_EXISTS:project  DIR_EXISTS:project/plans  DIR_EXISTS:project/tickets
DIR_EXISTS:project/adrs  DIR_EXISTS:project/pulse
STATE_JSON:present
```

**Kernel category scores**: `AGENTS.md scaffold=100`, `Project record container=100`,
`Tool-state=100`, `.claude/ presence=100`, `README=0`, `LICENSE=0`, `.gitignore=100`.
Kernel composite: 0.20·100 + 0.20·100 + 0.05·100 + 0.15·100 + 0.15·0 + 0.10·0 + 0.15·100 = **75 → B**.

**Full audit (executed, Python transcription of audit/SKILL.md Phase 4+5 against A1 fixture with zero siblings installed):**

```
slug                    wt   sc  source                 note
claude-code-config      25   50  kernel-presence-cap    presence-cap (weight 25) — recommended: claudit
skills-quality          10    0  presence-fail          not configured (weight 10) — recommended: skillet
commit-hygiene          15    0  presence-fail          not configured (weight 15) — recommended: commventional
code-documentation      15    0  presence-fail          not configured (weight 15) — recommended: inkwell (Phase 2+)
lint-posture            15    0  presence-fail          not configured (weight 15) — recommended: lintguini (Phase 2+)
event-emission           5    0  presence-fail          not configured (weight 5)  — recommended: autopompa (Phase 2+)
agents-md               10  100  kernel-owned           kernel-owned (weight 10)
project-record           5   50  kernel-presence-cap    presence-cap (weight 5)  — recommended: avanti (Phase 1b)

Sum of weighted_contribution: 25.00
composite_score = 25   grade = F   (Critical)
```

**Timing**: kernel scan 7 ms; full Phase 4/5 execution 3 ms including filesystem
globs, an empty-repo `git log`, the event-emission `rglob`, and the aggregation
arithmetic. **Budget 5000 ms — actual < 10 ms.** Massive headroom.

## Pass criteria check

- ✓ Scorecard renders in <5s (executed: 10 ms end-to-end on the A1 fixture).
- ✓ Every dimension has a score OR a "not configured" reason (8/8 dimensions
  scored with `source` in `{sibling, kernel-presence-cap, presence-fail, kernel-owned}`).
- ✓ No tracebacks. The empty-repo `git log` exits non-zero with a stderr
  warning; presence check returns 0 gracefully. No crashes, no nil deref.

## Deferred to live environment

- `/pronto:init` AskUserQuestion flow (Phase 5 sibling-install proposals) —
  requires live operator input.
- Actual parser-agent dispatch and subagent result capture — requires live
  Claude Code session with plugin loaded. A2 covers the arithmetic layer
  against real parser-shaped fixture JSON; the subagent-dispatch layer is
  deferred.
