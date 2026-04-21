---
id: 001
status: accepted
superseded_by: null
updated: 2026-04-21
---

# ADR 001 — Pronto is a meta-orchestrator, not a self-contained template

## Context

Pronto began life in `acostanzo/pronto` as a **self-contained template plugin** — the vision was a single plugin that dropped a prescriptive set of files (AGENTS.md, CLAUDE.md scaffolding, project/ layout, lint configs, observability setup, commit hook wiring, etc.) into any consumer repo, then scored the repo against its own bundled rubric.

Four PRs landed on that design. The problem was structural: **every concern pronto tried to own was already owned by a sibling plugin in the quickstop ecosystem.**

- Claude Code config health → `claudit` already audits this, with a published 6-category rubric and a knowledge cache.
- Skills quality → `skillet` already audits `SKILL.md` files with a 6-category rubric.
- Commit + review hygiene → `commventional` already enforces conventional commits, conventional comments, and engineering ownership.
- Release notes → `towncrier` owns this.

Every time pronto added a dimension, the same pattern recurred: either reimplement a sibling's logic (double maintenance, inevitable drift), or embed the sibling's output (tight coupling, breaks when the sibling ships). Both paths made pronto a slower-moving copy of faster-moving siblings.

A second problem: the "bundled template" model assumed pronto knew the right answer for every dimension. But the right answer depends on the repo. A Go monorepo wants different lint configs than a TypeScript service; a firmware project doesn't need Playwright MCP at all. Shipping opinions baked into a template forced consumers into binary choices: accept pronto's opinion wholesale, or walk away from the plugin.

## Decision

**Pronto is the meta-orchestrator of Claude-Code-readiness. It owns the rubric, not the depth.**

Concretely:

1. **Pronto audits a repo against a rubric of readiness dimensions** (Claude Code config, skills, commit hygiene, docs, lint posture, observability, AGENTS.md, project records).
2. **For each dimension, pronto delegates depth scoring to the recommended sibling plugin** — `claudit` for config, `skillet` for skills, `commventional` for commits, etc.
3. **When a sibling is missing, pronto falls back to a coarse kernel presence check** (does the artifact exist?) and caps that dimension's score at 50 to prevent the perverse incentive where an empty scaffold outscores a honestly-audited one.
4. **Pronto owns a minimal kernel**: AGENTS.md scaffolding, `project/` container presence, `.pronto/` tool state. Everything else delegates.
5. **Pronto is a plugin in `acostanzo/quickstop`, not a separate repo.** Rebuilt from scratch in quickstop; the prior commits in `acostanzo/pronto` remain as a paper trail via PR #1.

The rubric is the product. The orchestration is the product. The bundled opinions are not the product.

## Consequences

### Positive

- **Single source of truth per dimension.** Each sibling owns its domain; pronto just names the domain and weights it in the rubric. No drift between pronto's "here's what good config looks like" and claudit's same opinion.
- **Consumers install siblings piecemeal.** A repo that cares about skills but not about observability installs skillet and ignores autopompa (when it ships) — the rubric still runs, the unscored dimension just reports "not configured."
- **Rubric is tunable.** The weights are in `references/rubric.md` as a table. Rebalancing after real data accumulates is a data change, not a code change.
- **Kernel is small.** Pronto's own surface — kernel presence, rubric registry, recommendation registry, orchestrator — fits in one plugin directory and is legible end-to-end in under 15 minutes.
- **Dogfooding is honest.** quickstop's `project/` folder IS the convention pronto establishes. Every ticket, ADR, and pulse entry goes through the same discipline any consumer would follow.

### Negative / accepted tradeoffs

- **Pronto is useless without at least one sibling.** A repo with only pronto installed sees all dimensions report "not configured — recommended: X." This is intentional — pronto is a coach, not a toolbox — but it does mean pronto's first-run experience is bootstrapping advice, not immediate scorecard depth.
- **The wire contract is upstream work.** Phase 1 ships parser-agent glue because claudit/skillet/commventional haven't yet adopted `plugin.json` pronto-audit declarations or `--json` flags. Retrofitting each sibling is tracked in those plugins' own roadmaps, not pronto's. Until the retrofit lands, pronto's dimension scoring has a Phase-1-only indirection layer.
- **"Not yet shipped" siblings show up as presence-cap permanently until they ship.** `inkwell`, `lintguini`, `autopompa` are Phase 2+. Their dimensions will sit at 50-cap (or 0) until those plugins arrive. This is a known-incomplete state that reflects reality rather than masking it.

### Neutral

- **Cross-repo aggregation stays out of pronto.** A consumer-orchestrator can stitch multiple repos' `/pronto:audit --json` outputs into an org-level dashboard; that integration concern is the consumer's, not pronto's.
- **The kernel grows slowly.** Pronto's kernel (AGENTS.md, project/, .pronto/, presence checks) is the only surface that WILL grow with pronto's own code. Everything dimension-specific grows in the sibling that owns that dimension.

## Alternatives considered

### A. Keep the self-contained template model

Rejected. Every dimension pronto tried to own was already owned by a sibling. The tax of maintaining two copies of "what good config looks like" was paid on every release of either plugin.

### B. Absorb the siblings into pronto

Rejected. Claudit and skillet are already shipped, have their own release cadences, their own users, and their own roadmaps. Subsuming them would erase value. Pronto gains from orchestrating them, not replacing them.

### C. A standalone `pronto` repo rather than a quickstop plugin

Rejected. Pronto is conceptually inseparable from its siblings — the rubric delegation only works when all relevant plugins ship from the same marketplace. A standalone `pronto` repo would require users to install pronto from one source and its dependencies from another, splintering the install flow.

### D. A CI-only audit with no in-repo installation

Rejected as Phase 1 scope. A CI integration might land later (e.g., GitHub Actions wrapper), but the primary surface is interactive — `/pronto:audit` in a developer's Claude Code session. That's where readiness decisions actually get made.

## Links

- Phase 1 plan: `project/plans/active/phase-1-pronto.md`.
- Related sibling plans: `project/plans/active/phase-1-avanti.md` (Phase 1b — SDLC work layer; the "Project record" rubric dimension depth-auditor).
- Prior home of pronto (closed without merging): `acostanzo/pronto` PR #1.
