---
id: t5
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# T5 — Kernel template content

## Context

`plugins/pronto/templates/` — the tree `/pronto:init` drops into a consumer repo. Source names are literal: hidden target paths (`.claude/`, `.pronto/`) live under hidden directories of the same name in `templates/`. Only `gitignore-additions.txt` is special-cased — it appends rather than overwrites.

Contents:

- `AGENTS.md` — agent-facing repo map + skeleton conventions block for the consumer to customize.
- `project/README.md` — explains `project/` layout, lifecycle state machines, frontmatter envelopes.
- `project/{plans,tickets,adrs,pulse}/.gitkeep` — placeholder files so git tracks the empty subdirs.
- `.claude/README.md` — seed doc explaining what belongs in `.claude/` (skills, agents, rules, settings, MEMORY.md) with scope notes.
- `.pronto/state.json` — seed tool state: `{schema_version: 1, last_audit: null, composite_score: null, composite_grade: null, dimensions: {}}`.
- `gitignore-additions.txt` — lines init appends to the target `.gitignore` (adds `.pronto/` and `.avanti/`). Uses comment headers so consumers can tell where the lines came from.
- `README.md` — the template manifest: rename map, portability promise, and per-path overwrite strategy (refuse / skip / append).

## Acceptance

- Every template file passes the author-string grep inside `plugins/pronto/templates/`: zero matches.
- `state.json` parses as valid JSON (verified).
- All markdown files are syntactically clean — no unterminated code fences, consistent headings.
- Rename map in `templates/README.md` documents every source → target path and its overwrite strategy, giving T6 (init skill) a precise contract to implement against.

## Decisions recorded

- **Literal dotfile names in template tree.** Using `.claude/` and `.pronto/` as literal source dirs inside `plugins/pronto/templates/` rather than a rename scheme like `dotclaude/`. Git handles these fine and the manifest in `templates/README.md` keeps the install path legible.
- **`gitignore-additions.txt` is appended, not replaced.** Consumers may already have a `.gitignore` — init merges rather than overwrites. The file is in `.txt` format (not a literal `.gitignore`) to signal "fragment" and to avoid confusing git when it sees a `.gitignore` inside the plugin source.
- **`.gitkeep` placeholders for empty dirs.** Consumers may delete them once real content lands. Using `.gitkeep` (convention) rather than `README.md` stubs — the empty subdirs are functional placeholders, not documentation targets.
- **AGENTS.md carries a repo-specific conventions block as a TODO comment.** Consumers edit in place. Default content is minimal — test-then-review discipline, don't-delegate-understanding — both portable practices, no organization-specific jargon.
- **project/README.md duplicates some of avanti's docs on purpose.** When avanti isn't installed, this README is the only place a consumer can look up the lifecycle conventions. If avanti ships and later extends the conventions, consumers upgrade both plugins in lockstep.
