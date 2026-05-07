---
id: 009
status: accepted
superseded_by: null
updated: 2026-05-07
---

# ADR 009 — Marketplace simplification: drop pronto/skillet/lintguini, reframe as workflow-enhancement plugins

## Context

Quickstop's framing through ADRs 001–008 was *"a Claude-Code-readiness scorecard plus sibling plugins that bring repos up to standard."* Pronto sat at the centre as the composite scorer; sibling plugins (avanti, claudit, commventional, inkwell, lintguini, skillet, towncrier) each owned one rubric dimension and emitted a wire contract for pronto to aggregate. ADRs 004 and 005 codified the sibling-composition contract and the `:audit` skill conventions; ADR-008 pinned lintguini's templates as projections of pronto's lint-posture rubric.

In practice, the framing earned its complexity poorly. The composite score answered a question almost no individual user actually asks. The orchestration layer (wire contracts, version handshake, dispatch) added authoring friction for every sibling plugin and for any future contributor, without producing a primary user value that justified the cost. Two of the plugins drifted further from the original premise the longer they were maintained:

- **Skillet** captured a "what makes a well-shaped Claude Code skill" rubric and graded skills against it. The captured content was high-quality at point-of-capture but is the kind of thing whose ground truth moves with each Claude Code release. A pinned May 2026 view of skill conventions will not be the right view in November.
- **Lintguini** expanded from a sibling auditor into a full lint toolkit (`/lintguini:configure`, `/lintguini:lint`, `/lintguini:format`, `/lintguini:fix`) plus per-language config templates. Templates pin specific tool versions and rule sets in a domain that itself evolves quickly; an agent prompted to "set up linting against current best practices" produces fresher output than our templates can.

Three sibling plugins (inkwell, avanti, towncrier) carry an `:audit` skill that exists *only* to feed pronto's composite score. Each is dead weight without pronto.

Claudit is different in shape: its primary surface is its own audit-and-optimise of Claude Code configurations. Its research-cache infrastructure was advertised secondarily as "skillet/smith/hone consume this cache" — a framing that dies with skillet.

The strategic question this ADR answers: should the marketplace remain a constellation organised around a composite scorer, or should it become a collection of plugins each chosen on its own merits?

## Decision

**The marketplace is a set of plugins that enhance Claude Code workflows. Each one solves a specific, named problem; users install whatever solves theirs; nothing depends on anything else.**

Concrete actions:

1. **Drop pronto.** The composite scorer and its rubric/dispatch infrastructure retire.
2. **Drop skillet.** Skill-quality grading is not a problem worth a plugin given how fast the underlying conventions move.
3. **Drop lintguini.** Linter/formatter wrappers and pinned templates do not earn their plugin-shaped existence; agents calling current tools directly produce fresher results.
4. **Strip the `:audit` surface from inkwell, avanti, and towncrier.** With pronto gone, those skills have no consumer. The plugins keep their primary capabilities and lose only the pronto-facing artefacts.
5. **Reframe claudit.** The research cache is repositioned as a general-purpose Claude Code knowledge primer — pull down current ecosystem understanding once, an agent uses it for any subsequent task (build a skill, configure an MCP, write CLAUDE.md, anything). It is no longer advertised as a skillet/smith/hone feeder.

This imposes the following rules:

1. **No more cross-plugin grading or composite scoring.** The `lint-posture` / `claude-code-config` / `project-record` / `skills-quality` / `commit-hygiene` / `docs` dimension framework retires with pronto. Each surviving plugin owns its own value statement; there is no scorecard to optimise toward.
2. **No constellation framing in marketplace messaging.** Plugin READMEs and the root README lead with capability. The words "sibling," "rubric," "constellation," and "compatible_pronto" disappear from user-facing surfaces (they may persist in historical artefacts under `project/adrs/` and `project/plans/done/`).
3. **No salvaged static reference content from dropped plugins.** Lintguini's templates and skillet's rubric are not extracted to a `marketplace/references/` shelf. Pinning a snapshot of moving ground truth is the anti-pattern this ADR rejects; the agent-plus-current-docs path is strictly better.
4. **Audit surfaces stay only where the audit is consumer-facing.** `/claudit` audit stays — its primary value proposition is auditing the user's own Claude Code config. Inkwell/avanti/towncrier audit skills go — they were pronto-only artefacts.
5. **Claudit's cache is general-purpose.** Messaging is "pre-warm Claude's understanding of current Claude Code best practices for any subsequent agent task." Not skillet-feeder, not cross-plugin synergy advertising.

The final marketplace is five plugins:

| Plugin | Problem solved |
|---|---|
| **claudit** | Audit and optimise Claude Code configurations; cache current ecosystem knowledge for any subsequent agent task. |
| **avanti** | SDLC in markdown — plans, tickets, ADRs, pulse — no Jira required. |
| **commventional** | Consistent commit voice, review style, engineering ownership. |
| **inkwell** | Documentation toolkit — write, search, query (with code corroboration), tidy. |
| **towncrier** | Hook into Claude Code events for observability and downstream automation. |

## Consequences

### Positive

- **Each plugin reads as standalone-useful.** A user who needs SDLC scaffolding installs avanti; a user who wants commit hygiene installs commventional. There is no implicit "you should install the whole set" pressure.
- **Plain marketplace messaging.** Capability-first per-plugin descriptions. No vocabulary the user has to learn before they can decide whether a plugin helps them.
- **No more Goodhart's-law-shaped optimisation toward a composite grade.** Plugin authors design for the user's primary task, not for "how does this score on dimension X."
- **Lower authoring barrier.** Future plugin authors can ship without learning the pronto wire-contract, the `:audit` skill conventions, or the sibling version handshake.
- **Substantial code reduction.** Roughly three thousand lines of audit/scoring infrastructure leaves the tree across the eight plugins touched here.

### Negative

- **Today's lintguini 0.5.0 work is undone.** Five milestones and six PRs of expansion artefacts are removed. The lessons captured during that work persist as memory feedback; the artefacts themselves do not survive in-tree.
- **ADR-008 (lintguini rubric authority) is superseded** in the same commit that lands this ADR. ADR-008 set lintguini's templates as projections of pronto's lint-posture rubric; with both gone, the pinning relationship is moot.
- **Historical plans diverge from current state.** `project/plans/done/inkwell-expansion.md`, `project/plans/done/lintguini-expansion.md`, and the pronto phase plans describe substantial work whose artefacts are now partially or wholly removed. They stay as historical record; this ADR is the pointer to *why* parts of that work no longer exist on disk.
- **Loss of the composite-score insight.** A user who wanted "one number for how Claude-Code-ready is this repo" no longer gets it. We are explicitly choosing not to serve that user; a future plugin could revive the idea standalone if it earns its keep.

### Neutral

- **ADR-007 (inkwell corroboration architecture) still binds.** `/inkwell:query` and the corroboration dispatcher (`bin/inkwell-corroborate.sh`) stay; they were never audit-only. The "audit stays deterministic" stance from ADR-007 applied to inkwell's audit which is now gone, but the surrounding principle (capabilities can be agentic; deterministic surfaces should be deterministic) still informs `/inkwell:query` and `/inkwell:tidy`.
- **ADR-006 (plugin responsibility boundary) still binds.** The capabilities-vs-automation framing applies to every surviving surface.
- **ADRs 004 and 005 (sibling composition / skill conventions) become historical.** They describe a contract that no longer has implementations. They are not formally superseded — they describe what a sibling *would* be — but no plugin in the surviving set claims sibling shape. Future authors do not need to read them.

## Alternatives considered

### Keep pronto in reduced form (kernel only, no rubric)

Strip pronto's rubric and dispatch but keep `/pronto:init` as a scaffolder for AGENTS.md and the kernel files. The constellation framing dies but pronto persists as a thin scaffolding tool.

Rejected. Without the rubric and dispatch, pronto is a one-shot file-templater for AGENTS.md. That is not enough surface to justify a plugin — a user who wants AGENTS.md can ask their agent to draft one in less time than installing pronto takes. The kernel files were valuable as the contract pronto enforced; without enforcement they are an opinion the user can take or leave, and the plugin shape adds nothing over a documented opinion.

### Keep lintguini, drop only its audit

Strip `/lintguini:audit` and keep the configure/lint/format/fix surface. Lintguini becomes a non-sibling toolkit.

Rejected. Once the audit is gone, lintguini is thin wrappers around `ruff`, `biome`, `rustfmt`, `rubocop`, and `golangci-lint`. The agent can call those tools directly via Bash with up-to-date flags; the wrapper layer cannot keep pace with how fast those tools' conventions move. The wrapper is a maintenance liability that the underlying tools do not need.

### Salvage lintguini's templates as static reference docs

Move `plugins/lintguini/templates/` into a `marketplace/references/` shelf or into claudit's cache, so the captured strictness baselines remain available as a non-plugin reference.

Rejected. The templates pin specific rule sets and tool versions. They were already going stale during the expansion work; pinning them as references makes the staleness permanent. The agent-plus-current-tool-docs path is strictly better than a snapshot we have to keep current. A static reference does not keep itself current; we would be creating a maintenance commitment that the simplification ADR is explicitly trying to avoid.

### Salvage skillet's skill-quality rubric as a static reference

Move skillet's rubric into a non-plugin location for agents to consult when authoring skills.

Rejected. Same logic as lintguini's templates. Skill conventions evolve with each Claude Code release. A May 2026 rubric is a useful artefact at point-of-capture and a misleading one six months later. Claudit's research-cache pattern (fetch current docs on demand) is the right shape for this kind of content; a pinned rubric is the wrong shape.

### Keep the composite scorer but drop the siblings' audits

Keep pronto, lose the dimension siblings, and let pronto run all its analysis itself.

Rejected. The siblings' audits were the only thing pronto's score depended on; without them pronto has nothing to aggregate. A standalone pronto that ran every check itself would have to ship every analyser inline — at which point it is no longer a meta-orchestrator, it is a monolithic auditor whose value-per-line is even worse than the constellation's.

## Links

- ADR-001: meta-orchestrator model — describes the composite-scorer framing this ADR retires.
- ADR-004: sibling composition contract — describes the wire-contract surface this ADR retires.
- ADR-005: sibling skill conventions — describes the `:audit` skill conventions this ADR retires.
- ADR-006: plugin responsibility boundary — still binds.
- ADR-007: inkwell corroboration architecture — still binds; `/inkwell:query` and the corroboration dispatcher persist.
- ADR-008: lintguini rubric authority — **superseded by this ADR.**
- `project/plans/done/inkwell-expansion.md`, `project/plans/done/lintguini-expansion.md`, and the pronto phase plans — historical record; their artefacts are partially or wholly removed by this simplification.
