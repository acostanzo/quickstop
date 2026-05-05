# Inkwell

Audits code-documentation depth for Claude Code consumer repos: README quality, docs coverage, staleness, and internal link health.

## Plugin surface

This plugin ships:
- Skills: `audit`
- Commands: none
- Agents: none
- Hooks: none
- Opinions: none

This plugin does not ship: cross-plugin automation, consumer config edits, or any
flow that silently mutates artefacts the consumer owns. Consumers compose automation
against this plugin's capabilities per ADR-006 §6.

## What this sibling audits

This plugin audits the **Code documentation** dimension of pronto's readiness rubric.

## Standalone invocation

```bash
/inkwell:audit --json
```

Emits a v2 wire-contract JSON envelope to stdout. The `observations[]` field
carries entries pronto's rubric translates into a dimension score.

## Pronto handshake

This plugin declares `compatible_pronto: ">=0.3.0"` in `plugin.json`.
Pronto checks this at dispatch time — if the installed pronto is outside the declared
range, pronto skips this sibling's audit and scores the dimension by presence only.

## Installation

### From marketplace

```bash
/plugin install inkwell@quickstop
```

### From source

```bash
claude --plugin-dir /path/to/quickstop/plugins/inkwell
```

## Architecture

1 skill (`audit`). No commands, no agents, no hooks, no MCP servers. The 2a1 scaffold emits an empty `observations[]` envelope; the four deterministic shell scorers (README quality, docs coverage, staleness, internal link health) and the rubric stanza land in 2a2/2a3.

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

## License

MIT. See [LICENSE](LICENSE).
