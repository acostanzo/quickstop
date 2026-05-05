---
id: t2
plan: inkwell-expansion
status: open
updated: 2026-05-05
---

# t2 — M2: `/inkwell:doc` and `/inkwell:search` — the writer's daily surface

## Context

Implements milestone M2 of the inkwell expansion plan. Lands the writer's daily surface: `/inkwell:doc` for scaffolding/updating docs from templates, `/inkwell:search` for FTS5 retrieval over `docs/`. The supporting bash machinery (`inkwell-index.sh`, `inkwell-search.sh`, `inkwell-suggest-links.sh`) lives under `plugins/inkwell/bin/`. The skills are thin wrappers around the bash scripts so the search surface is also discoverable via slash command.

Plan section implemented: "Skill set" rows for `/inkwell:doc` and `/inkwell:search` in `project/plans/active/inkwell-expansion.md`.

## Acceptance criteria

- `plugins/inkwell/skills/doc/SKILL.md` exists. Behaviour:
  - `/inkwell:doc <topic>` against an existing matching doc updates the file and bumps `updated:` to today.
  - `/inkwell:doc <topic>` against a new topic scaffolds from the auto-picked template; `--template <name>` overrides the auto-pick.
  - `--from-code <path>` reads source and drafts an API-shaped (reference-template) doc.
  - The skill suggests `## Related` entries via the link suggester before writing.
- `plugins/inkwell/skills/search/SKILL.md` exists and is a thin wrapper over `bin/inkwell-search.sh`. Returns ranked hits with file paths and matching snippets.
- `plugins/inkwell/bin/inkwell-index.sh` builds and rebuilds the FTS5 index over `docs/`.
- `plugins/inkwell/bin/inkwell-search.sh` queries the FTS5 index and returns ranked hits.
- `plugins/inkwell/bin/inkwell-suggest-links.sh` powers the `## Related` suggester.
- The FTS5 index rebuilds **on write** — after `/inkwell:doc` produces or updates a file, the next `/inkwell:search` reflects the change without manual reindexing.
- `/inkwell:search <query>` against an empty `docs/` exits cleanly with a "no documents indexed" message rather than crashing.
- Both skills use the M1 templates and frontmatter shape; nothing in this ticket re-decides the document model.
- Vector search is **not** implemented — explicitly deferred to v2.

## Notes

The on-write index rebuild is the user-visible contract: writers don't run `/inkwell:index` between scaffolding and searching. If the rebuild is heavy enough that on-write becomes painful, an incremental-index path is a follow-up — but the v1 default is full rebuild for simplicity.

## Links

- Plan: `project/plans/active/inkwell-expansion.md`
