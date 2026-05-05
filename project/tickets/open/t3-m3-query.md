---
id: t3
plan: inkwell-expansion
status: open
updated: 2026-05-05
---

# t3 — M3: `/inkwell:query` with citation contract and answer-shaping

## Context

Implements milestone M3 of the inkwell expansion plan. Lands `/inkwell:query` — retrieval-augmented Q&A over the FTS5 index produced by M2, with a fixed answer-shaping contract: claim, supporting chunks, source links (doc path + heading anchor), corroboration status. The corroboration field is **present in the response from M3 onward** but **stubbed** as `not yet implemented` until M5 wires the subagent layer. Locking the contract at M3 lets M5 fill in the field without reshaping the surface.

Plan section implemented: "Skill set" row for `/inkwell:query` and the framing of the corroboration field in `project/plans/active/inkwell-expansion.md`.

## Acceptance criteria

- `plugins/inkwell/skills/query/SKILL.md` exists. `/inkwell:query "<question>"` pulls top-N chunks via the M2 FTS5 index, answers from them, and returns the answer in the contract shape below.
- The response contract includes, in order: a **claim** (the answer), the **supporting chunks** drawn from, **source links** as doc path + heading anchor, and a **`corroboration`** field.
- The `corroboration` field is present on every M3 response and reads `not yet implemented` (placeholder) for every cited claim. M5 populates the field for real; M3 must not invent its own corroboration logic.
- The contract surface — field names, ordering, citation format — is documented inline in `SKILL.md` so M5 can wire against it without re-deciding the shape.
- Citations resolve: the doc path points at a real file under `docs/`, the heading anchor matches a real heading in that file.
- `/inkwell:query` against an empty `docs/` returns a clean "no matching documentation" response, not a crash.
- The skill does not dispatch any subagent — Tier 2 corroboration is M5's scope. M3 is retrieval + answer-shaping only.

## Notes

The stubbed `corroboration: not yet implemented` value is intentional and load-bearing. Downstream consumers of `/inkwell:query` output (humans reading answers, future tooling) need the field's shape to be stable from M3 onward; locking the contract pre-implementation is what lets M5 ship without breaking anyone.

## Links

- Plan: `project/plans/active/inkwell-expansion.md`
