---
name: query
description: Retrieval-augmented Q&A over the repo's `docs/` tree. Returns a one-paragraph synthesis plus citations (doc path + heading anchor) and a corroboration field. The corroboration field is stubbed at M3 and wired by M5; the response shape is locked from M3 onward.
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
- Renders the **Sources** block and the **Corroboration** stub line
  in the locked contract shape (see "Response contract" below).

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
5. The **Corroboration:** line (verbatim, copied from the script
   output).

If the script's stdout is the literal `*No matching documentation
found.*` line, return that string as-is. The empty-`docs/` branch
and the no-FTS5-hits branch share this sentinel; do not retry, do
not fabricate citations.

## Response contract — locked at M3

This contract is **load-bearing for M5**. The corroboration
dispatcher (T5) wires the `Corroboration:` field by reading this
SKILL.md alone, without re-deciding the shape. Do not reshape it.

The response, in order:

| Field | Source | M3 behaviour | M5 behaviour |
|---|---|---|---|
| **Answer.** (one paragraph) | LLM synthesis from chunks | Synthesised | Unchanged |
| **Sources:** list, one per cited doc | `bin/inkwell-query-retrieve.sh` | `- [path#anchor](path#anchor) — <one-line snippet>` | Unchanged |
| **Corroboration:** line | `bin/inkwell-query-retrieve.sh` | `not yet implemented` (literal stub) | Per-claim verdict — `verified` / `drift detected (see file.ts:N)` / `could not corroborate` |

The literal stub line emitted at M3 is:

```
**Corroboration:** `not yet implemented` (see ADR-007; M5 wires this)
```

When M5 lands, only the rendering of the **Corroboration:** field
changes — Answer and Sources stay shape-stable. Downstream consumers
of `/inkwell:query` output (humans, future tooling) can rely on the
field's existence and position from M3 onward.

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

- **No subagent dispatch.** Tier-1/Tier-2/Tier-3 corroboration is M5's
  scope; M3 is retrieval + answer-shaping only. The corroboration
  field is a literal stub at this milestone.
- **No claim extraction.** The synthesis is one paragraph drawn from
  chunks; per-claim verdicts wait for the M5 dispatcher.
- **No vector search.** v1 is FTS5 only. Vector retrieval is deferred
  to v2.
- **No mutation of `docs/` or any consumer artefact.** ADR-006 §2
  holds: read-only retrieval surface.
- **No inventing citations.** Every entry in **Sources:** comes from
  `inkwell-query-retrieve.sh`'s deterministic output. If the chunks
  don't answer the question, say so — do not fabricate sources to
  pad an answer.
