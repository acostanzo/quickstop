---
phase: 2
status: done
tickets: [t1, t2, t3, t4, t5]
updated: 2026-05-05
---

# Inkwell expansion — from auditor to documentation system

## The role in one paragraph

Expand the `inkwell` plugin from a Pronto-sibling auditor into a full documentation toolkit — write, search, query, tidy — while keeping the existing audit surface intact. Inkwell becomes to `docs/` what avanti is to `project/`: the plugin that owns the contents, in the voice and shape an LLM can retrieve and reason over. Five PR-sized milestones land the new skill set, the document model, the inference-time corroboration layer, and three conditional audit scorers. Scope boundary: v1 is repo-root `docs/` only, no monorepo support, no authoring-time `code_refs:` frontmatter, no audit-side LLM dispatch.

## The model

### Documentation voice

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

### Document model

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

**No `code_refs:` field.** Code and docs evolve in parallel; an authoring-time reference list goes stale and erodes trust faster than no list at all. Code corroboration happens at inference time via subagent (see "Inference-time corroboration"), not via author-maintained metadata.

**Body shape.** H1 title → body → terminal `## Related` block (wikilinks or relative paths to sibling docs). Same discipline as the vault's `## Related` rule — soft requirement, scored, not enforced.

**Templates.** Diátaxis four-quadrant: `concept`, `how-to`, `reference`, `tutorial`. Proven framework, ships unmodified. Soft templates — required frontmatter, suggested sections, no rigid format-policing.

**README is separate.** It's the repo's front door, not an inkwell-doc. Graded by the existing `score-readme-quality.sh` and untouched by the new model.

### Skill set

| Skill | Purpose |
|---|---|
| `/inkwell:audit` | Existing. Surface unchanged. Stays deterministic — pure shell + grep + awk + jq, no subagent dispatch. Gains conditional scorers (see "Audit additions"). |
| `/inkwell:doc <topic>` | Write or update. If topic matches an existing doc → update + bump `updated:`. If new → scaffold from `--template <name>` (or auto-pick). Optional `--from-code <path>` reads source and drafts API-shaped docs. Suggests `## Related` entries via the link suggester. |
| `/inkwell:search <query>` | FTS5 over `docs/`. Bash script + on-write index rebuild, skill is a thin wrapper for discoverability. Vector search is a v2 upgrade. |
| `/inkwell:query <question>` | Retrieval-augmented Q&A. Pulls top-N chunks → answers from them → returns answer with citations (doc path + heading anchor) and corroboration annotations. Answer-shaping lives here — every answer has the same presentation contract: claim, supporting chunks, source links, corroboration status. |
| `/inkwell:tidy` | Read-only by default; `--apply` for mechanical fixes. Finds duplicates (title + content-overlap heuristic), dead links, stale docs (git mtime drift), template non-compliance, missing `## Related`. Semantic rewrites require `--apply-semantic` and emit diffs for human review. |

### Inference-time code corroboration

Corroboration is a **`/inkwell:query`-only feature.** The audit stays deterministic; corroboration's latency and non-determinism are acceptable in the answer-shaping path but not in a fast scorer.

**How it works.** When `/inkwell:query` assembles an answer:

1. Pull top-N doc chunks (RAG).
2. **Extract claims** from the chunks — three tiers:
   - **Tier 1 — cheap, deterministic.** Inline code spans (`functionName`, `path/to/file.ts`). Verify symbols/files exist via grep / `ast-grep`.
   - **Tier 2 — LLM-judged.** Behavioural assertions ("when X, returns Y", "the default is Z"). Dispatch a subagent to read the relevant code and return a confidence verdict.
   - **Tier 3 — untouchable.** Conceptual statements, design rationale, narrative. Annotated "could not corroborate" with no penalty — these are exactly the things docs *should* carry that code can't express.
3. **Annotate the answer.** Each cited claim carries a corroboration tag: `verified`, `drift detected (see file.ts:N)`, or `could not corroborate`. The answer surfaces the tag prominently — the user knows which parts of the answer the code backs.

**Subagent dispatch.** One `Explore`-class subagent per claim batch (Tier 2). Bounded; parallelisable across independent claims. Failure mode: if the subagent is unreachable or times out, the answer still ships with `could not corroborate` — corroboration never blocks the response.

**No author burden.** The doc author writes prose. The system extracts and verifies. If the doc says "validateSession is called from the auth middleware," the system finds out whether that's true at query time, every time. Authors don't maintain reference lists.

**Why this matters.** Documentation is only useful if it's reliable. Authoring-time references go stale because they're decoupled from the prose around them. Inference-time corroboration ties verification to *what the prose actually claims*, in the moment the user is asking — so a stale doc surfaces as drift the moment someone queries it.

The architectural rationale and the audit-vs-query split are recorded in `project/adrs/007-inkwell-corroboration-architecture.md`.

### Audit additions — conditional scorers

Three new scorers, all gated on "did inkwell's doc model show up in this repo?" — detected by presence of frontmatter on any `docs/**/*.md`. If markers absent, scorers drop (empty-scope), preserving today's audit semantics for non-inkwell consumers.

- `score-template-compliance.sh` — % of inkwell-marked docs that have valid `template:` frontmatter and required sections.
- `score-backlink-coverage.sh` — % of inkwell-marked docs that terminate with a non-empty `## Related` block.
- `score-duplicate-density.sh` — title + content-overlap pairs, near-duplicate count.

**No corroboration scorer.** Corroboration is inference-time only. The audit measures things that don't need an LLM.

Existing scorers (`score-readme-quality.sh`, `score-docs-coverage.sh`, `score-doc-staleness.sh`, `score-link-health.sh`) are unchanged.

### What gets deleted

- `agents/parse-inkwell.md` — the deprecated transitional agent.
- The matching parser entry in `plugins/pronto/references/recommendations.json` (if one exists; verify before pulling).
- Any references to `parse-inkwell` in inkwell's README or pronto's docs.

This is its own atomic commit early in the M1 milestone — clears the deck before the new surface lands.

### Proposed file layout (post-M5)

```
plugins/inkwell/
├── .claude-plugin/plugin.json
├── README.md                          # rewritten after M2
├── LICENSE
├── skills/
│   ├── audit/SKILL.md                 # existing
│   ├── doc/SKILL.md                   # new (M2)
│   ├── search/SKILL.md                # new (M2)
│   ├── query/SKILL.md                 # new (M3)
│   └── tidy/SKILL.md                  # new (M4)
├── agents/                            # parse-inkwell.md DELETED in M1
├── bin/
│   ├── build-envelope.sh              # existing (audit orchestrator)
│   ├── inkwell-index.sh               # new (M2) — FTS5 rebuild
│   ├── inkwell-search.sh              # new (M2)
│   ├── inkwell-suggest-links.sh       # new (M2)
│   ├── inkwell-corroborate.sh         # new (M5) — subagent dispatcher
│   └── inkwell-tidy.sh                # new (M4)
├── scorers/
│   ├── _common.sh
│   ├── score-readme-quality.sh        # existing
│   ├── score-docs-coverage.sh         # existing
│   ├── score-doc-staleness.sh         # existing
│   ├── score-link-health.sh           # existing
│   ├── score-template-compliance.sh   # new (M5, conditional)
│   ├── score-backlink-coverage.sh     # new (M5, conditional)
│   └── score-duplicate-density.sh     # new (M5, conditional)
├── templates/                         # new (M1)
└── tests/
```

## Tickets

### T1 — Document model + voice + parse-inkwell removal

Land the foundation: the four Diátaxis templates under `plugins/inkwell/templates/` (`concept.md`, `how-to.md`, `reference.md`, `tutorial.md`), the document model spec in inkwell's README (location, frontmatter shape, body shape, no `audience:` / `code_refs:` fields), and the Documentation voice section published verbatim from the plan. In the same milestone (separate atomic commit), delete `plugins/inkwell/agents/parse-inkwell.md`, remove the matching entry from `plugins/pronto/references/recommendations.json` if one exists, and strip any `parse-inkwell` references from inkwell's README and pronto's docs. Clears the deck before the new surface lands.

**Acceptance:** all four templates exist with valid YAML frontmatter and the suggested-sections skeleton; README spec reads cleanly to a first-time author and matches the plan word-for-word on the locked decisions (no `audience:`, no `code_refs:`); `agents/parse-inkwell.md` is gone; grep for `parse-inkwell` across the repo returns zero hits in shipped plugin files; `recommendations.json` parses as valid JSON with the entry cleanly excised.

### T2 — `/inkwell:doc` and `/inkwell:search`

The writer's daily surface. Skill `plugins/inkwell/skills/doc/SKILL.md` scaffolds new docs from `--template <name>` (or auto-picks based on topic shape), updates existing docs by bumping `updated:`, optionally drafts API-shaped docs from source via `--from-code <path>`, and suggests `## Related` entries. Skill `plugins/inkwell/skills/search/SKILL.md` is a thin wrapper over `bin/inkwell-search.sh`, which queries an FTS5 index over `docs/`. The index is rebuilt on-write by `bin/inkwell-index.sh`; `bin/inkwell-suggest-links.sh` powers the `## Related` suggester. Vector search is deferred to v2.

**Acceptance:** `/inkwell:doc <new-topic> --template how-to` produces `docs/<slug>.md` with valid frontmatter and the how-to skeleton; `/inkwell:doc <existing-topic>` updates the existing file and bumps `updated:` to today; `/inkwell:doc <topic> --from-code path/to/file.ts` produces a reference-shaped draft seeded from the source; `/inkwell:search <query>` returns ranked hits with file paths and matching snippets; the FTS5 index rebuilds automatically after a doc is written.

### T3 — `/inkwell:query` with citation contract and answer-shaping

Skill `plugins/inkwell/skills/query/SKILL.md` is retrieval-augmented Q&A with a fixed answer-shaping contract: claim, supporting chunks, source links (doc path + heading anchor), corroboration status. Pulls top-N chunks via the FTS5 index, answers from them, and returns the answer in the contract shape. The corroboration field is **present** in the response from M3 onward and **stubbed** as `not yet implemented` until M5 wires the subagent layer. The contract — field names, ordering, citation format — is locked at M3 so M5 can't accidentally reshape it.

**Acceptance:** `/inkwell:query "<question>"` returns an answer that names the chunks it drew from with doc-path-plus-anchor citations; the response contains a `corroboration` field with the placeholder value `not yet implemented`; the contract surface (claim, chunks, source links, corroboration) is documented inline in the SKILL.md so M5 can wire against it without re-deciding the shape; queries against an empty `docs/` produce a clean "no matching documentation" response, not a crash.

### T4 — `/inkwell:tidy`

Skill `plugins/inkwell/skills/tidy/SKILL.md` plus `bin/inkwell-tidy.sh`. Read-only by default — surfaces duplicates (title + content-overlap heuristic), dead links, stale docs (git mtime drift past the staleness threshold), template non-compliance, and missing `## Related` blocks. `--apply` performs the mechanical fixes (link rewriting, frontmatter `updated:` bumps, archiving, near-identical dedup). `--apply-semantic` is required for any semantic rewrite and emits a diff for human review rather than writing in place.

**Acceptance:** `/inkwell:tidy` against a docs tree with seeded issues lists each finding with the file path and the rule it violated; `/inkwell:tidy --apply` resolves the mechanical findings and leaves no semantic ones; `/inkwell:tidy --apply-semantic` produces diffs and does not write to the working tree; running `/inkwell:tidy` on a clean tree exits 0 with no findings.

### T5 — Subagent corroboration layer + conditional audit scorers

Wires the killer feature and lands the three conditional scorers. `bin/inkwell-corroborate.sh` is the subagent dispatcher: Tier 1 deterministic name-resolution via grep / `ast-grep` for inline code spans; Tier 2 dispatches an `Explore`-class subagent per claim batch for behavioural assertions and returns a confidence verdict; Tier 3 annotates "could not corroborate" with no penalty. The dispatcher is bounded, parallelisable, and degrades gracefully — if the subagent is unreachable or times out, `/inkwell:query` still ships its answer with `could not corroborate`. The corroboration response contract (locked at M3) is populated with real verdicts at this point. In the same milestone: three new conditional scorers (`score-template-compliance.sh`, `score-backlink-coverage.sh`, `score-duplicate-density.sh`) under `plugins/inkwell/scorers/`, each gated on the presence of inkwell-frontmatter on any `docs/**/*.md`. If markers are absent, scorers emit empty-scope and the audit behaves identically to today. The architectural rationale lives in `project/adrs/007-inkwell-corroboration-architecture.md`; the ticket implements it.

**Acceptance:** `/inkwell:query` against a docs tree containing a deliberately broken inline code span (function name that doesn't exist) returns the answer with that span annotated `drift detected`; a doc with verifiable inline references returns `verified`; conceptual statements return `could not corroborate`; the three new scorers run and contribute to the inkwell composite when frontmatter markers are present, and emit empty-scope (no contribution, no warning) when absent; existing scorers' scores are unchanged on a non-inkwell consumer; subagent timeout produces `could not corroborate` rather than a query failure.

## Acceptance bars

Every A-bar passes on a fresh inkwell install in a repo with `docs/` populated by the test fixture.

### A1 — Templates produce frontmatter-compliant docs

1. Confirm all four Diátaxis templates exist under `plugins/inkwell/templates/` (`concept.md`, `how-to.md`, `reference.md`, `tutorial.md`).
2. For each template, scaffold a doc via `/inkwell:doc <topic> --template <name>`.
3. Verify the produced file's frontmatter against the document model schema: required `title`, `updated`, `template`; optional `tags`; absent `audience`, absent `code_refs`.

**Pass:** four templates exist; all four produce frontmatter-compliant docs that pass schema validation; no template emits `audience:` or `code_refs:` fields.

### A2 — Doc round-trip with FTS5 retrieval

1. `/inkwell:doc round-trip-fixture --template how-to` to scaffold a new doc.
2. Edit the file's body to include a unique sentinel phrase (e.g. `RT_FIXTURE_SENTINEL`).
3. `/inkwell:search RT_FIXTURE_SENTINEL`.

**Pass:** the search returns the round-trip-fixture doc as a hit, with the path and a snippet containing the sentinel; the FTS5 index rebuild that occurred between steps 2 and 3 was automatic, not user-triggered.

### A3 — Query returns citations and a corroboration field

1. `/inkwell:query "<question grounded in the round-trip-fixture doc>"`.
2. Inspect the response contract.

**Pass:** response contains a claim, supporting chunks, source links (doc path + heading anchor), and a `corroboration` field; pre-M5 the field reads `not yet implemented`; post-M5 the field is populated with `verified` / `drift detected` / `could not corroborate` per claim, and the locked contract shape is unchanged.

### A4 — Audit conditional scorers behave on both shapes

1. Run `/inkwell:audit` against the inkwell-marked test repo.
2. Run `/inkwell:audit` against a plain repo with no inkwell frontmatter on any `docs/**/*.md`.

**Pass:** in (1) the three new scorers (template-compliance, backlink-coverage, duplicate-density) run and contribute to the composite; in (2) the three new scorers emit empty-scope and the composite letter grade is identical to what today's audit produces. Existing scorers' contributions are unchanged across both runs.

### A5 — parse-inkwell removed end-to-end

1. `find plugins/inkwell/agents -type f` returns no `parse-inkwell.md`.
2. `grep -r 'parse-inkwell' plugins/` returns zero hits in shipped plugin files (excluding tests' historical fixtures, if any).
3. `plugins/pronto/references/recommendations.json` parses as valid JSON and contains no `parse-inkwell` entry.

**Pass:** all three checks return clean.

## Out of scope

- **`code_refs:` frontmatter.** Authoring-time references go stale; corroboration is inference-time only. Closed by ADR-007.
- **Audit-side corroboration.** The audit stays deterministic — pure shell + grep + awk + jq, no LLM dispatch in scorers. Corroboration runs in `/inkwell:query` only.
- **Monorepo support.** v1 is repo-root `docs/` only. Configurable doc roots are deferred to v2.
- **Behavioural corroboration sharpening (M6 stretch).** Sharper Tier-2 claim extraction, subagent prompt iteration, and parallel batching are stretch work that ships as its own plan if and when it lands. Not part of this plan.
- **README rewrite.** Held until after M2 lands — once the writer's daily surface is real, the README has something concrete to describe. The M1 README delta is scoped to the document-model and voice sections plus the parse-inkwell strip; the full rewrite is its own follow-up.
- **Vector search.** FTS5 is sufficient for v1; vector search is a v2 upgrade.
- **Author-maintained reference lists of any shape.** No frontmatter field, no per-doc registry, no sidecar JSON. The system extracts and verifies at query time.

## Definition of done

- All T-tickets land with their own atomic conventional commits under `plugins/inkwell/` (or `plugins/pronto/` for the recommendations.json strip).
- All A-bars pass on a fresh inkwell install in the test fixture repo.
- ADR-007 (`project/adrs/007-inkwell-corroboration-architecture.md`) is `accepted`.
- Inkwell's `plugin.json` `version` is bumped (per quickstop's marketplace rules in `CLAUDE.md`); `marketplace.json` and `README.md` are updated to match.
- Existing audit semantics on non-inkwell consumers are unchanged — verified by A4.
- The plan promotes from `plans/active/` to `plans/done/` via `/avanti:promote plan:inkwell-expansion` once every ticket is closed and every A-bar passes.
