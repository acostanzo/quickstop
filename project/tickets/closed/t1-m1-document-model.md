---
id: t1
plan: inkwell-expansion
status: closed
updated: 2026-05-05
---

# t1 — M1: document model, voice, and parse-inkwell removal

## Context

Implements milestone M1 of the inkwell expansion plan: lay the foundation. Land the four Diátaxis templates, publish the document model and Documentation voice sections in inkwell's README, and clear the deck by deleting the deprecated `parse-inkwell` transitional agent and any references to it. This is the prerequisite for every subsequent skill — `/inkwell:doc` (T2) scaffolds from these templates, `/inkwell:audit`'s conditional scorers (T5) detect inkwell-shaped repos by the frontmatter this milestone introduces, and `/inkwell:tidy` (T4) checks template compliance against this model.

Plan section implemented: "Documentation voice", "Document model", and "What gets deleted" in `project/plans/active/inkwell-expansion.md`.

## Acceptance criteria

- `plugins/inkwell/templates/concept.md`, `how-to.md`, `reference.md`, and `tutorial.md` all exist.
- Each template carries valid YAML frontmatter with the required fields (`title`, `updated`, `template`) plus optional `tags`. No `audience:` field. No `code_refs:` field.
- Each template's body is a Diátaxis-shaped skeleton with suggested sections — soft template, not rigid format-policing.
- Inkwell's README contains a "Document model" section that specifies: `docs/` at repo root (configurable later for monorepos), Markdown + YAML frontmatter, the frontmatter shape above, body shape (H1 title → body → terminal `## Related` block), and that README itself is separate from the inkwell-doc model and is graded by the existing `score-readme-quality.sh`.
- Inkwell's README contains a "Documentation voice" section that publishes the priority order (LLM > engineers > product team) and the five voice rules (structured-and-scannable, concrete, self-contained, no visual-layout reliance, plain-spoken) verbatim from the plan.
- `plugins/inkwell/agents/parse-inkwell.md` is deleted.
- The matching parser entry in `plugins/pronto/references/recommendations.json` is removed (verify the entry exists before pulling; if absent, document the absence in the commit body and skip).
- All references to `parse-inkwell` are removed from inkwell's README and pronto's docs.
- `grep -r 'parse-inkwell' plugins/` returns zero hits in shipped plugin files.
- `recommendations.json` parses as valid JSON after the edit.
- The parse-inkwell removal is its own atomic conventional commit, separate from the templates/README commits, landing early in the M1 sequence.

## Notes

The README delta in M1 is scoped to the document-model and voice sections plus the parse-inkwell strip — the full README rewrite is deliberately deferred until after M2 lands, when there's a real writer's surface to describe. See "Out of scope" in the plan.

## Links

- Plan: `project/plans/active/inkwell-expansion.md`
