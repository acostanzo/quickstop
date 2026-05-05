---
name: doc
description: Scaffold a new doc under `docs/` from a Diátaxis template, or update an existing one and bump its `updated:` date. Suggests `## Related` candidates and refreshes the FTS5 index on write.
allowed-tools: Read, Write, Edit, Bash, Glob
argument-hint: <topic> [--template <name>] [--from-code <path>]
---

# Inkwell:doc

Write or update a doc under the repo's `docs/` tree. The skill is the
writer's primary scaffolding surface: it picks a Diátaxis template,
substitutes the topic into the headline placeholders, seeds a `## Related`
block from the link suggester, and refreshes the FTS5 index so the new
doc is immediately searchable via `/inkwell:search`.

## Inputs

- `<topic>` — required. Free-form topic title. Used both to derive the
  filename slug and to substitute the template's headline placeholders
  (`<Topic>`, `<Goal>`, `<Surface>`, `<What you'll learn>`).
- `--template <name>` — optional. One of `concept`, `how-to`,
  `reference`, `tutorial`. Overrides the auto-pick.
- `--from-code <path>` — optional. Source file to draft a
  reference-shaped doc from. Forces `--template reference` if no
  explicit template was given.

## Behaviour

### 1. Resolve target path

Call the resolver with the raw topic:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/inkwell-doc-resolve.sh" \
    "<topic>" "<REPO_ROOT>"
```

The resolver emits one of three outputs on a single line:

- `match <relative-path>` — exactly one existing doc matches by
  filename slug or by frontmatter `title:` (case-insensitive). Take
  the update path (§2a) against this file.
- `ambiguous <path1> <path2> ...` — two or more docs share a `title:`
  matching `<topic>` and no slug match exists. Surface the candidates
  to the user and stop; do **not** scaffold a third copy. The author
  resolves the ambiguity (e.g. by re-running with a more specific
  topic, or by editing one of the candidates manually first).
- `none` — no existing doc to update. Take the scaffold path (§2b).

The resolver checks slug first (the strongest signal — it's the
write-target the scaffold path would otherwise create) and falls
back to a `title:` scan so a topic like `Authentication` finds an
existing `docs/concepts/auth.md` rather than scaffolding a duplicate
at `docs/authentication.md`.

### 2a. Existing doc → update path

If the resolver returned `match <path>`:

1. `Read` the file.
2. `Edit` the `updated:` line in the frontmatter to today's date
   (UTC, `YYYY-MM-DD`). Today's date is available as the
   `{{ today }}` substitution in the conversation context, or
   compute via `Bash: date -u +%Y-%m-%d`.
3. Write nothing else. The body and other frontmatter are the
   author's, not yours — `/inkwell:doc` updates the `updated:` stamp,
   not the prose. Semantic rewrites belong to `/inkwell:tidy
   --apply-semantic` (T4).
4. Skip to §3 (index refresh).

### 2b. New doc → scaffold path

If the resolver returned `none`:

1. **Pick the template.** If `--template <name>` was supplied, use it.
   Otherwise auto-pick from the topic shape:
   - Starts with "How to " (case-insensitive) → `how-to`
   - Starts with "What is " → `concept`
   - Starts with "Get started" / "Build your first" / "Tutorial" → `tutorial`
   - Contains a `(` and `)` (function signature shape) or contains a
     path separator (`/` between non-space tokens, suggesting a file)
     → `reference`
   - Otherwise → `concept` (conservative default).
2. **`--from-code <path>` overrides the auto-pick to `reference`** (a
   doc generated from source code is reference-shaped by definition,
   unless the author explicitly asks for another template).
3. `Read` the chosen template at `${CLAUDE_PLUGIN_ROOT}/templates/<template>.md`.
4. **Substitute placeholders.** In the template body, replace:
   - `<Topic>` → the user's `<topic>` (concept/reference)
   - `<Goal>` → the user's `<topic>` (how-to)
   - `<Surface>` → the user's `<topic>` (reference)
   - `<What you'll learn>` → the user's `<topic>` (tutorial)
   - The `updated:` frontmatter value → today's date.
5. **`--from-code` enrichment.** If `--from-code <path>` is given:
   - `Read` the source file.
   - For known languages, seed the `## Parameters` table with the
     exported function signatures (Python `def`, JS/TS `export
     function`, Go `func`). The reference template's table is four
     columns — `Name | Type | Default | Description` — so each row
     must be `| name | — | — | — | <one-line meaning> |` (5 pipes,
     4 cells). Populate type/default if you can extract them from
     source; otherwise leave the em-dash placeholders. Leave the
     meaning blank if you can't extract a docstring — the author
     fills it in.
   - Add a one-line `## Description` paragraph naming the source path
     so the doc is self-locating.
6. **`Write` the new file** at
   `<REPO_ROOT>/docs/<template-dir>/<slug>.md` with the substituted
   body and an empty `## Related` block (the heading followed by the
   placeholder). `<template-dir>` is the conventional Diátaxis
   directory name, mapped from the chosen template:

   | Template | Directory |
   |---|---|
   | `concept`   | `concepts/`   |
   | `how-to`    | `howtos/`     |
   | `reference` | `reference/`  |
   | `tutorial`  | `tutorials/`  |

   The template files are named singular (`concept.md`, `how-to.md`,
   `reference.md`, `tutorial.md`); the on-disk neighbourhoods are
   plural (`concepts/`, `howtos/`, `tutorials/`) where natural and
   un-hyphenated (`howtos`). The mapping above is the source of
   truth — keep both halves in sync.

   Run `mkdir -p <REPO_ROOT>/docs/<template-dir>` before the write so
   the destination directory exists. The file must exist on disk
   before the suggester runs because the suggester reads the
   target's frontmatter `tags:` to score peers — it refuses a
   non-existent target.

   The resolver (`inkwell-doc-resolve.sh`) scans `docs/**/*.md`
   recursively, so existing docs at any depth continue to be found
   on the update path; only the scaffold path picks the subdirectory.
7. **Suggest `## Related`.** Call the suggester against the
   now-existent path:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/bin/inkwell-suggest-links.sh" \
       "docs/<template-dir>/<slug>.md" "<REPO_ROOT>"
   ```
   The script returns either `path  score=...  rationale: ...` lines
   on stdout or `no automatic suggestion` on stderr.
8. **`Edit` the `## Related` block.** If the suggester emitted
   candidates, replace the dash placeholder with one bullet per
   candidate (`- [path](path)`). If the suggester emitted "no
   automatic suggestion", leave the dash placeholder in place.

### 3. Refresh the FTS5 index

Always run, regardless of update or create path:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/inkwell-index.sh" "<REPO_ROOT>"
```

The indexer is mtime-cached and idempotent — touching only the file
just written. The on-write index refresh is what makes
`/inkwell:search` reflect the new doc immediately, no manual reindex.

## Voice

The doc you write must match the inkwell voice (see plugin README §
"Documentation voice"):

- LLM-first, then engineers, then product team.
- Structured and scannable — headings are semantic, sections are one
  idea.
- Concrete — file paths spelled out, function names in code spans.
- Self-contained — a reader (human or LLM) shouldn't need adjacent
  files to follow this one.
- Plain-spoken — engineering documentation is not marketing copy.

The templates ship with `<!-- comment -->` guidance under each
section. **Delete those guidance comments before saving** — they're
authoring scaffolding, not output content.

## What this skill does not do

- Does not author the prose. The user is the author; the skill
  scaffolds, substitutes, and seeds.
- Does not enforce template compliance. Sections are soft scaffolding
  per the plan's "Document model" section. Compliance scoring is
  T5's `score-template-compliance.sh`, not this skill's concern.
- Does not corroborate code. That's `/inkwell:query` (T3) at inference
  time, per ADR-007.
- Does not modify files outside `docs/<slug>.md` and the gitignored
  index file. ADR-006 §2 holds: no silent mutation of consumer
  artefacts.
