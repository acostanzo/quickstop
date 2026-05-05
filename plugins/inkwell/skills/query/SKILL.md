---
name: query
description: Retrieval-augmented Q&A over the repo's `docs/` tree. Returns a one-paragraph synthesis plus citations (doc path + heading anchor) and per-citation corroboration verdicts. Field shape and ordering are locked at M3; M5 populates the verdicts.
allowed-tools: Read, Bash, Glob
argument-hint: <question>
---

# Inkwell:query

Answer a writer's or LLM's question by pulling top-N chunks from the
FTS5 index over `docs/`, synthesising a one-paragraph answer from
those chunks, and returning the answer in a fixed shape — claim,
sources, corroboration. The synthesis is the only LLM-shaped part of
the path; everything else (retrieval, anchor resolution, citation
formatting, corroboration field) is produced deterministically by
`bin/inkwell-query-retrieve.sh`.

## Behaviour

### 1. Retrieve

Run the retrieval script with the user's question verbatim:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/inkwell-query-retrieve.sh" "<QUESTION>" "<REPO_ROOT>"
```

`<REPO_ROOT>` is the absolute path to the target repository, typically
the working directory when `/inkwell:query` was invoked. The script:

- Calls `bin/inkwell-search.sh` to get the top-5 FTS5 hits.
- For each hit, resolves the enclosing heading anchor by walking back
  to the nearest preceding `#`-rule heading (falling back to the doc's
  H1 if the match falls in YAML frontmatter).
- Slugifies the heading text per GitHub anchor rules (lowercase,
  non-alphanumerics → `-`, runs collapsed, leading/trailing `-`
  stripped) so the citation `path#anchor` is the link a reader can
  click.
- Extracts the section body from the heading line through the next
  heading of equal or higher rank, capped at 60 lines.
- Pipes the chunks block to `bin/inkwell-corroborate.sh`, which
  classifies each citation's claims into Tier 1 (deterministic
  name-resolution), Tier 2 (subagent-judged behavioural verification),
  or Tier 3 (annotated "could not corroborate"). The dispatcher's
  per-citation verdicts populate the **Corroboration** block.
- Renders the **Sources** block and the **Corroboration** block in
  the locked contract shape (see "Response contract" below).

### 2. Read and synthesise

The script's stdout is one combined block. Above the
`---END-OF-CHUNKS---` sentinel is the chunks payload — one section
per cited doc, each prefixed `### path#anchor`. Below the sentinel is
the rendered tail (Sources + Corroboration), which is appended to
the response unchanged.

Read the chunks. Synthesise **one paragraph** answering the user's
question, drawing only from those chunks. Be honest about scope:

- If the chunks answer the question directly, say so and cite which
  ones support which part of the claim.
- If the chunks only partially answer the question, name the gap.
- If the chunks don't actually answer the question, say so plainly.
  Do **not** invent facts the chunks do not contain.

The synthesis paragraph is the only non-deterministic part of the
response. Everything else — citations, snippets, corroboration —
comes from the script unchanged.

### 3. Emit the response

Concatenate, in this exact order:

1. `**Answer.** ` followed by the synthesised paragraph.
2. A blank line.
3. The **Sources:** block (verbatim, copied from the script output
   below the `---END-OF-CHUNKS---` sentinel).
4. A blank line.
5. The **Corroboration:** block (verbatim, copied from the script
   output) — one bullet per citation/claim with the dispatcher's
   verdict.

If the script's stdout is the literal `*No matching documentation
found.*` line, return that string as-is. The empty-`docs/` branch
and the no-FTS5-hits branch share this sentinel; do not retry, do
not fabricate citations.

## Response contract — locked at M3, populated at M5

This contract is **load-bearing**. The M3 stub and the M5 verdicts
share the same field name, ordering, and citation format —
downstream consumers of `/inkwell:query` output can rely on the
field's existence and position from M3 onward; M5 only changes the
*content* of the Corroboration block.

The response, in order:

| Field | Source | M3 behaviour | M5 behaviour |
|---|---|---|---|
| **Answer.** (one paragraph) | LLM synthesis from chunks | Synthesised | Unchanged |
| **Sources:** list, one per cited doc | `bin/inkwell-query-retrieve.sh` | `- [path#anchor](path#anchor) — <one-line snippet>` | Unchanged |
| **Corroboration:** block, one bullet per claim | `bin/inkwell-corroborate.sh` (via `inkwell-query-retrieve.sh`) | Single literal stub line `not yet implemented` | `- path#anchor — <verdict>` per claim — verdict ∈ `verified` / `drift detected (see …)` / `could not corroborate` |

The M5 Corroboration block looks like:

```
**Corroboration:**
- docs/auth/session.md#sessions — verified
- docs/auth/session.md#sessions — could not corroborate
- docs/concepts/auth.md#authentication — drift detected (see src/auth/login.ts: symbol 'foo' not found)
```

Multiple lines per citation are normal — Tier 1 emits one verdict
per inline code span; Tier 2 emits one verdict per behavioural
claim batch; Tier 3 emits a single fallback line for citations
with no code-shape signal.

If the dispatcher is unavailable, fails, or returns empty stdout,
`/inkwell:query` falls back to one `could not corroborate` bullet
per cited Source — the field is always populated, the shape is
always stable, the response always ships. Per ADR-007:
"corroboration never blocks the response."

The architectural rationale is in
`project/adrs/007-inkwell-corroboration-architecture.md`.

## Empty-scope contract

If `docs/` is missing, empty, or no hits resolve to a real heading,
the response is the single line:

```
*No matching documentation found.*
```

Exit cleanly. Never crash on a fresh repo.

## What this skill does not do

- **No vector search.** v1 is FTS5 only. Vector retrieval is deferred
  to v2.
- **No mutation of `docs/` or any consumer artefact.** ADR-006 §2
  holds: read-only retrieval surface. The corroboration dispatcher
  is also read-only against the consumer's source tree.
- **No inventing citations.** Every entry in **Sources:** comes from
  `inkwell-query-retrieve.sh`'s deterministic output. If the chunks
  don't answer the question, say so — do not fabricate sources to
  pad an answer.
- **No inventing verdicts.** Every entry in **Corroboration:** comes
  from `inkwell-corroborate.sh`'s deterministic / subagent-dispatched
  output. Do not synthesise verdicts in the answer paragraph.
