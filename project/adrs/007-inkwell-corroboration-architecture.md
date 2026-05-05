---
id: 007
status: accepted
superseded_by: null
updated: 2026-05-05
---

# ADR 007 — Code corroboration is inference-time and lives in `/inkwell:query` only

## Context

Documentation and code evolve in parallel. Authoring-time references — most obviously a `code_refs:` frontmatter field, but any author-maintained registry has the same shape — go stale, and stale references erode trust faster than no references at all. Documentation is only useful if it is reliable; once readers learn that a doc's "see also" links don't match the code they describe, the doc itself is treated as suspect.

Inkwell's expansion plan introduces a documentation toolkit (`/inkwell:doc`, `/inkwell:search`, `/inkwell:query`, `/inkwell:tidy`) on top of the existing audit. The question is *where* code corroboration belongs — verifying that what a doc claims about the code is actually true. Two natural homes exist: in the audit's deterministic scorers, or in `/inkwell:query`'s answer-shaping path. The decision constrains the response contract for queries from M3 onward and shapes the M5 implementation; it must be settled before the surface lands.

The constraint that frames the choice: corroboration must verify what the doc *actually claims*, in the moment a query happens — not against a list the author last touched months ago.

## Decision

**Code corroboration runs as subagent dispatch inside `/inkwell:query`'s answer-shaping path.** The audit (`/inkwell:audit`) stays deterministic — pure shell + grep + awk + jq, no LLM calls in scorers. The corroboration layer is layered into `/inkwell:query` only.

Corroboration runs in three tiers:

1. **Tier 1 — deterministic name-resolution.** Inline code spans (`functionName`, `path/to/file.ts`) are verified by grep / `ast-grep` for symbol/file existence. Cheap, fast, no LLM.
2. **Tier 2 — LLM-judged behavioural verification.** Behavioural assertions ("when X, returns Y", "the default is Z") are dispatched to an `Explore`-class subagent that reads the relevant code and returns a confidence verdict. Bounded; parallelisable across independent claims.
3. **Tier 3 — annotated "could not corroborate."** Conceptual statements, design rationale, and narrative are tagged with no penalty — these are exactly the things docs *should* carry that code can't express.

Each cited claim in a `/inkwell:query` response carries a corroboration tag: `verified`, `drift detected (see file.ts:N)`, or `could not corroborate`. The corroboration field is part of the query response contract from M3 onward (stubbed as `not yet implemented`) and locked at M5 when the dispatcher wires up.

## Consequences

### Positive

- **No author burden.** Authors write prose; the system extracts and verifies. There is no reference list to maintain, no frontmatter field to keep current.
- **Always against current code.** Corroboration ties verification to *what the prose claims*, in the moment the user is asking. A stale doc surfaces as drift the moment someone queries it — there is no decoupled list that can rot independently.
- **Audit stays fast and reproducible.** No LLM in the scoring path means `/inkwell:audit` remains deterministic, parallelisable, and CI-friendly. Today's audit semantics are preserved; the conditional scorers added in M5 are pure shell.
- **Failure modes degrade gracefully.** If a Tier-2 subagent is unreachable or times out, `/inkwell:query` still ships the answer with `could not corroborate` for the affected claims. Corroboration never blocks the response.

### Negative

- **Corroboration latency lands in the query path.** Every `/inkwell:query` answer pays the cost of dispatching subagents for any Tier-2 claims it cites. Long behavioural-claim batches will be visibly slower than name-resolution-only answers.
- **Subagent dispatch is non-deterministic.** Two queries against the same doc-state and code-state can return different verdicts on Tier-2 claims if the subagent makes different calls or returns differently-worded confidence verdicts.
- **Tier-2 verdicts can be wrong.** The subagent is reading code under time pressure; it can return false positives ("verified" on a claim that's actually drifted) or false negatives ("drift detected" on code it failed to find). The `verified`/`drift detected`/`could not corroborate` triad is presented as a tag, not a guarantee.

### Neutral

- **The corroboration field becomes part of the query response contract.** From M3 onward the field is present, stubbed; at M5 it is populated for real. The shape is locked at M3 so M5 cannot accidentally reshape it; downstream tooling that consumes `/inkwell:query` output can rely on the field's existence from day one.
- **Corroboration tooling is invisible to non-query callers.** `/inkwell:audit`, `/inkwell:doc`, `/inkwell:search`, `/inkwell:tidy` know nothing about it. The dispatcher (`bin/inkwell-corroborate.sh`) is a `/inkwell:query`-internal capability.

## Alternatives considered

### Subagent-in-audit-scorers

Run the same Tier-1/Tier-2 corroboration logic as a scorer inside `/inkwell:audit` — a `score-corroboration.sh` that dispatches subagents to verify claims across the docs tree and produces a corroboration percentage. Rejected. The audit must be fast and reproducible: it runs in CI, in pre-commit gates, and as a sibling-aggregated dimension in pronto. Per-claim subagent dispatch makes audit runs slow, non-deterministic between runs, and dependent on the subagent layer being available — none of which are tolerable in a fast scorer. Pushing LLM verdicts into the audit also breaks the audit's "pure shell + grep + awk + jq" contract, which is why other scorers are easy to reason about and easy to dogfood.

### `code_refs:` frontmatter with a corroboration scorer

Have authors maintain a `code_refs:` array in each doc's frontmatter (`code_refs: [path/to/file.ts:functionName, ...]`) and a deterministic scorer that verifies the listed refs still resolve. Rejected. Authoring-time references go stale because they're decoupled from the prose around them — an author can update the prose without remembering to update the ref list, and vice versa. The reliability cost (a doc with current prose and a stale ref list looks more wrong than one with no list at all) outweighs the implementation simplicity. The deeper problem: this verifies what the *list* claims, not what the *prose* claims; the latter is the actual question.

## Links

- Plan: `project/plans/active/inkwell-expansion.md` (see "Inference-time code corroboration" and "Audit additions — conditional scorers")
- ADR-006: `project/adrs/006-plugin-responsibility-boundary.md` — capabilities-vs-automation framing; corroboration is a capability surface, not a trigger surface.
