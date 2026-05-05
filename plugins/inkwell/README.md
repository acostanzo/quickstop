# Inkwell

Documentation toolkit for Claude Code. Inkwell owns a repo's `docs/` tree the way avanti owns its `project/` tree: write, search, query, and tidy are the daily surface; a Pronto-sibling audit for code-documentation depth ships alongside. Docs are written in a voice and shape an LLM can retrieve and reason over — that is the point of the system, not a flourish.

## Quick start

```bash
/plugin install inkwell@quickstop

/inkwell:doc authentication --template concept       # scaffold or update a doc
/inkwell:search "session token"                      # FTS5 over docs/
/inkwell:query "how does auth handle expired tokens?"  # RAG Q&A with citations + corroboration
```

## Skills

| Skill | Purpose |
|---|---|
| [`/inkwell:doc <topic>`](skills/doc/SKILL.md) | Scaffold a new doc from a Diátaxis template, or update an existing one and bump `updated:`. |
| [`/inkwell:search <query>`](skills/search/SKILL.md) | FTS5 search over `docs/`. Top-25 ranked hits with file paths and matching snippets. |
| [`/inkwell:query <question>`](skills/query/SKILL.md) | Retrieval-augmented Q&A. One-paragraph synthesis plus citations and per-claim code corroboration. |
| [`/inkwell:tidy`](skills/tidy/SKILL.md) | Surface (and optionally fix) doc-tree drift — duplicates, dead links, stale docs, template non-compliance, missing `## Related` blocks. |
| [`/inkwell:audit`](skills/audit/SKILL.md) | Pronto-sibling audit for code-documentation depth. Pure shell + grep + awk + jq, no LLM dispatch. |

## Documentation voice

Inkwell-managed documentation is written for, in priority order:

1. **The LLM.** Documentation must be retrievable and reasonable-over by an LLM. This is not a future-proofing flourish — it is the primary use case. Good documentation under inkwell answers an LLM's question correctly when chunked, reranked, and slotted into a RAG context window.
2. **Engineers.** A second human reader picking up the codebase six months from now should find decisions, rationale, and concrete pointers — not just descriptions.
3. **Product team.** Concept-first orientation when introducing systems; reference detail can sit deeper.

What this priority order implies for *how* docs are written:

- **Structured and scannable.** Headings carry meaning. Sections are semantically chunked (a section is one idea). No walls of prose.
- **Concrete.** File paths spelled out. Function names in code spans. Decision rationale named, not implied.
- **Self-contained.** A reader (human or LLM) should understand a doc without surrounding context. Don't lean on adjacent files for the point of this one.
- **No visual-layout reliance.** Don't say "see the diagram below" without naming what the diagram shows. LLMs and screen readers don't see diagrams.
- **Plain-spoken.** Engineering documentation is not marketing copy. State what is true.

This applies to every template; templates shape *what* is in the doc, voice shapes *how* it is written.

## Document model

**Location.** `docs/` at repo root. Configurable later for monorepos; v1 keeps it simple.

**Format.** Markdown with YAML frontmatter:

```yaml
---
title: Authentication                                # required
updated: 2026-05-05                                  # required, auto-bumped on /inkwell:doc
template: concept | how-to | reference | tutorial    # required
tags: [auth, security]                               # optional
---
```

**No `audience:` field.** Documentation voice (above) covers it — every doc is written for the same audience priority.

**No `code_refs:` field.** Code and docs evolve in parallel; an authoring-time reference list goes stale and erodes trust faster than no list at all. Code corroboration happens at inference time via subagent (see ADR-007), not via author-maintained metadata.

**Body shape.** H1 title → body → terminal `## Related` block (wikilinks or relative paths to sibling docs). Soft requirement, scored, not enforced.

**Templates.** Diátaxis four-quadrant: `concept`, `how-to`, `reference`, `tutorial`. Proven framework, ships unmodified. Soft templates — required frontmatter, suggested sections, no rigid format-policing. Live under [`templates/`](templates/).

**README is separate.** It's the repo's front door, not an inkwell-doc. Graded by the existing `score-readme-quality.sh` and untouched by the new model.

## /inkwell:doc — write or update

Scaffolds new docs from a Diátaxis template, or updates an existing one and bumps `updated:` to today. Slug derivation is deterministic (lowercase, non-alphanumerics → `-`); the first match under `docs/**/<slug>.md` wins. The FTS5 index refreshes on write so the doc is searchable immediately.

Common invocations:

```bash
/inkwell:doc authentication                              # auto-pick template from topic shape
/inkwell:doc rate-limiting --template how-to             # explicit template
/inkwell:doc validate-session --from-code src/auth.ts    # API-shaped draft seeded from source
```

Notable flags: `--template <concept|how-to|reference|tutorial>`, `--from-code <path>`. See [`skills/doc/SKILL.md`](skills/doc/SKILL.md) for the full surface.

New scaffolds land under the conventional Diátaxis subdirectory — `docs/concepts/`, `docs/howtos/`, `docs/reference/`, `docs/tutorials/` — and their `## Related` block ships with a `<!-- inkwell:related -->` comment placeholder that `/inkwell:tidy` treats as writer-acknowledged-empty (no `missing-related` finding on fresh docs).

## /inkwell:search — FTS5 over `docs/`

Thin wrapper over `bin/inkwell-search.sh`. The script invokes `bin/inkwell-index.sh` first, so the index is always current relative to the on-disk tree. FTS5 `porter unicode61` tokenizer; ranking is `bm25`; capped at 25 hits.

```bash
/inkwell:search "session token"
/inkwell:search "auth NEAR/3 retry"   # FTS5 syntax passes through
```

Each hit emits as `path:line  [tags]  …matching snippet…`. No hits → empty stdout, exit 0. See [`skills/search/SKILL.md`](skills/search/SKILL.md) for query syntax detail.

## /inkwell:query — RAG with citations and corroboration

Retrieval-augmented Q&A. Pulls top-5 chunks from FTS5, synthesises a one-paragraph answer from those chunks only, and emits a fixed-shape response: `**Answer.**` paragraph, `Sources:` block, `Corroboration:` block. Citations are `path#anchor` — clickable on GitHub. The synthesis paragraph is the only LLM-shaped part of the path; retrieval, anchor resolution, citation formatting, and corroboration come from `bin/inkwell-query-retrieve.sh` deterministically.

```bash
/inkwell:query "how does auth handle expired tokens?"
```

The **corroboration field** is what makes this load-bearing. Every cited claim carries one of three verdicts:

- **Tier 1 — `verified` / `drift detected`.** Deterministic name-resolution. Inline code spans (`functionName`, `path/to/file.ts`) are checked via grep; existing symbols verify, missing symbols flag drift with a `file.ts:N` pointer.
- **Tier 2 — LLM-judged.** Behavioural assertions ("when X, returns Y", "the default is Z"). An `Explore`-class subagent reads the relevant code and returns a confidence verdict.
- **Tier 3 — `could not corroborate`.** Conceptual statements, design rationale, narrative — exactly the things docs *should* carry that code can't express. Annotated, no penalty.

Subagent dispatch is bounded and parallelisable; if it's unreachable or times out, the answer still ships with `could not corroborate` rather than failing. The architectural rationale and the audit-vs-query split are recorded in [`project/adrs/007-inkwell-corroboration-architecture.md`](../../project/adrs/007-inkwell-corroboration-architecture.md). See [`skills/query/SKILL.md`](skills/query/SKILL.md) for the locked response contract.

## /inkwell:tidy — drift finder

Read-only by default. Surfaces duplicates (title + content-overlap heuristic), dead links, stale docs (git mtime drift past threshold), template non-compliance, and missing `## Related` blocks. One finding per stdout line, sorted by path then rule for determinism. Clean tree → exit 0, empty stdout.

| Mode | What it does | Writes? |
|---|---|---|
| (default) | Read-only finding pass | No |
| `--apply` | Mechanical fixes (link rewrites, `updated:` bumps, archive moves, near-identical dedup) | Yes (working tree) |
| `--apply-semantic` | Emit unified diffs for semantic rewrites | No |

The `--apply` / `--apply-semantic` split is load-bearing: mechanical changes have a single correct answer and are silent; semantic operations always come with a diff so they're reviewed, not trusted. See [`skills/tidy/SKILL.md`](skills/tidy/SKILL.md).

## /inkwell:audit — Pronto sibling

Inkwell ships as a Pronto sibling for the **`code-documentation`** dimension (weight 15 in the readiness rubric). The audit stays deterministic — pure shell + grep + awk + jq, no LLM dispatch in scorers — and runs orthogonally to the writer surface.

### Standalone invocation

```bash
/inkwell:audit --json
```

Emits a v2 wire-contract JSON envelope to stdout. The `observations[]` field carries entries pronto's rubric translates into a dimension score; `composite_score` is `null` because the rubric path is the sole authority on dimension scoring.

### Scorers

`bin/build-envelope.sh` dispatches the scorers in fixed order and slurps their non-empty stdouts into `observations[]`. Tool-absent branches degrade gracefully — missing `interrogate` / `lychee` / `revive` / `cargo doc` omit the observation rather than fail the audit.

Always-on scorers:

- `score-readme-quality.sh` — counts answered arrival questions in `README.md`.
- `score-docs-coverage.sh` — per-language tool dispatch (`interrogate` / `eslint-jsdoc` / `revive` / `cargo doc`) for public-API docstring coverage.
- `score-doc-staleness.sh` — `git log` mtimes for source files vs the latest docs touch.
- `score-link-health.sh` — `lychee --offline` over `README.md` and `docs/`.

Conditional scorers (gated on the presence of inkwell-frontmatter on any `docs/**/*.md` — emit empty-scope on non-inkwell consumers, preserving today's audit semantics):

- `score-template-compliance.sh` — % of inkwell-marked docs with valid `template:` frontmatter and required sections.
- `score-backlink-coverage.sh` — % of inkwell-marked docs that terminate with a non-empty `## Related` block.
- `score-duplicate-density.sh` — title + content-overlap pairs, near-duplicate count.

### Pronto handshake

`plugin.json` declares `compatible_pronto: ">=0.3.0"`. Pronto checks this at dispatch time — if the installed pronto is outside the declared range, pronto skips the sibling audit and scores the dimension by presence only.

## Architecture

- **Skills.** Five SKILL.md files under [`skills/`](skills/) — `doc`, `search`, `query`, `tidy`, `audit`.
- **Bin scripts.** Workhorses under [`bin/`](bin/) — `build-envelope.sh` (audit orchestrator), `inkwell-index.sh` (FTS5 rebuild), `inkwell-search.sh`, `inkwell-suggest-links.sh`, `inkwell-query-retrieve.sh`, `inkwell-corroborate.sh`, `inkwell-tidy.sh`.
- **Templates.** Four Diátaxis templates under [`templates/`](templates/) — `concept.md`, `how-to.md`, `reference.md`, `tutorial.md`. Soft templates: required frontmatter, suggested sections.
- **FTS5 index.** `docs/.inkwell.fts5.db` (gitignored), rebuilt on-write by `inkwell-index.sh`.
- **Thresholds.** Tunables (e.g. staleness day cutoff) in [`references/thresholds.json`](references/thresholds.json).
- **Conditional audit scorers.** Three scorers under [`scorers/`](scorers/) gate on inkwell-frontmatter presence and emit empty-scope otherwise.

The plugin ships no commands, no agents, no hooks, no MCP servers. ADR-006 §2 (no silent mutation of consumer artefacts) and §3 (vacuously satisfied: inkwell ships no hooks) hold across the surface; consumers compose automation against this plugin's capabilities per ADR-006 §6.

## Installation

### From marketplace

```bash
/plugin install inkwell@quickstop
```

### From source

```bash
claude --plugin-dir /path/to/quickstop/plugins/inkwell
```

## License

MIT. See [LICENSE](LICENSE).
