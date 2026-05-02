# Quickstop

A Claude Code plugin marketplace.

## Plugins


### Commventional (v1.1.0)

Enforce conventional commits, conventional comments, and engineering ownership for commits, PRs, and code reviews.

- Passive auto-invocation — activates on commit, PR, and review context without explicit commands
- Sub-agent architecture: commit-crafter for diffs, review-formatter for feedback
- Three conventions: conventional commits, conventional comments, engineering ownership
- Reference specs bundled for consistent enforcement

**Auto-invokes on:** commits, pull requests, code reviews

### Claudit (v2.6.0)

Audit and optimize Claude Code configurations with dynamic best-practice research.

- Research-first architecture: subagents fetch official Anthropic docs before analysis
- **Knowledge cache**: research results cached at `~/.cache/claudit/` with version-based + 7-day TTL invalidation
- **Knowledge skill**: `/claudit:knowledge` exposes cached research to other plugins — auto-refreshes stale domains
- **Decision memory**: stores audit decisions so future runs annotate recommendations with past context (team-shared, committable)
- Over-engineering detection as highest-weighted scoring category
- 6-category health scoring with interactive fix selection
- Persistent memory on research agents for faster subsequent runs
- Cross-tool synergy: cached knowledge speeds up skillet, smith, and hone

**Commands:** `/claudit` — run audit, `/claudit:refresh` — refresh cache, `/claudit:status` — show cache state, `/claudit:knowledge` — retrieve cached research

### Skillet (v0.2.1)

Build, audit, and improve Claude Code skills with research-first architecture and opinionated structure.

- Research-first: fetches latest Anthropic skill/agent docs before every action
- **Claudit cache integration**: uses claudit's cached ecosystem knowledge when available, falls back to own research
- Three workflows: build from scratch, audit existing, improve from findings
- Opinionated directory template enforcement for consistent skill structure
- 6-category scoring rubric specific to skill quality

**Commands:** `/skillet:build <name>`, `/skillet:audit <path>`, `/skillet:improve <path>`

### Towncrier (v0.3.0)

Emit a structured JSON event for every Claude Code hook to a configurable transport.

- Registers all 26 documented hook events; each one is wrapped in a uniform envelope (`id`, `ts`, `type`, `host`, `session_id`, `pid`, `cwd`, `data`)
- Pluggable transport — `file:` (default), `fifo:`, or `http://` — via `~/.towncrier/config.json` or `TOWNCRIER_TRANSPORT` env var
- Hard 2s timeout per emit with automatic fallback to the default file — Claude hooks never hang and events are never lost
- Strictly observational: pass-through `PermissionRequest`, no stdout interference, no behavior changes
- `skip_events` config filter for muting noisy events without uninstalling
- Producer only in v0.1.0 — write your own consumer against the documented envelope

**Default output:** `~/.towncrier/events.jsonl` — `tail -F` and `jq` to start

### Pronto (v0.5.0)

Meta-orchestrator for Claude-Code-readiness — audits a repo against a rubric of readiness dimensions and delegates depth scoring to sibling plugins.

- Rubric-driven: scores Claude Code config, skills, commit hygiene, docs, lint posture, observability, AGENTS.md, and project records
- Delegation over re-implementation: folds `claudit`, `skillet`, `commventional` audit output into a composite scorecard via a shared wire contract
- Kernel scaffolds the minimum (AGENTS.md, `project/` container, `.pronto/` tool state) and flags sibling-covered dimensions as "not configured" when a recommended plugin is missing
- Roll-your-own references for every dimension — recommendations are registered, not required
- Machine-parseable `--json` output alongside the human-readable markdown scorecard

**Commands:** `/pronto:init`, `/pronto:audit`, `/pronto:status`, `/pronto:improve`
### Avanti (v0.1.3)

The SDLC work layer — authors and maintains the records under `project/` (plans, tickets, ADRs, pulse journal) and drives each record through its lifecycle.

- Three lifecycles: plans (draft → active → done), tickets (open → in-progress → closed), ADRs (proposed → accepted → superseded)
- Folder-as-primary — the folder a file lives in is the authoritative state; frontmatter `status:` mirrors for machine-readability
- Plan-scoped tickets — every ticket belongs to a plan; no standalone tickets
- Per-day pulse files (`project/pulse/YYYY-MM-DD.md`) — append-only, merge-friendly
- Declares pronto's `project-record` audit dimension natively via `plugin.json` — emits wire-contract JSON under `--json`
- Templates ship portable; `/avanti:plan`, `/avanti:ticket`, `/avanti:adr` copy and fill into consumer repos

**Commands:** `/avanti:plan`, `/avanti:ticket`, `/avanti:adr`, `/avanti:promote`, `/avanti:pulse`, `/avanti:status`, `/avanti:audit`

### Lintguini (v0.4.0)

Audits lint-posture for Claude Code consumer repos: linter config strictness, formatter presence, CI lint enforcement, and rule-suppression count.

- Pronto sibling — depth auditor for the `lint-posture` rubric dimension (weight 15)
- Wire-contract v2 envelope on `/lintguini:audit --json` — observations consumed by pronto's rubric translator
- Four deterministic shell scorers under `scorers/` — pure shell + grep + awk + jq, no language toolchain on PATH required
- Six first-class language paths: python (ruff / black / flake8), javascript (biome / eslint / prettier), typescript (tsconfig strict-bundle + `@typescript-eslint` + biome / eslint), rust (rustfmt / clippy via Cargo.toml), go (golangci-lint / gofmt), ruby (rubocop / standardrb)
- Multi-language `low/mid/high` calibration fixture set lands in 2b3
- Declares `compatible_pronto: ">=0.2.0"` per ADR-004 handshake

**Commands:** `/lintguini:audit`

### Inkwell (v0.3.0)

Audits code-documentation depth for Claude Code consumer repos: README quality, docs coverage, staleness, and internal link health.

- Pronto sibling — depth auditor for the `code-documentation` rubric dimension (weight 15)
- Four deterministic shell scorers under `scorers/` — `score-readme-quality.sh` (arrival-question coverage), `score-link-health.sh` (lychee `--offline` over README + docs/), `score-doc-staleness.sh` (git-log mtimes vs threshold), `score-docs-coverage.sh` (per-language tool dispatch — interrogate / eslint-jsdoc / revive / cargo doc)
- `bin/build-envelope.sh` orchestrator dispatches the four scorers in fixed order and slurps their non-empty stdouts into the v2 envelope's `observations[]` array
- Tool-absent branches degrade gracefully — missing interrogate / lychee / revive / cargo omit the observation rather than fail the audit
- Wire-contract v2 envelope on `/inkwell:audit --json` — observations consumed by pronto's `code-documentation` translation rules; `composite_score: null` defers all scoring to the rubric path
- Three-fixture calibration set under `tests/fixtures/{low,mid,high}/` with locked envelopes for byte-equivalence regression
- Declares `compatible_pronto: ">=0.3.0"` per ADR-004 handshake

**Commands:** `/inkwell:audit`

## Dev Tools

Repo-level skills for plugin authors (not distributable plugins — these live in `.claude/`):

| Command | Purpose |
|---------|---------|
| `/smith <name>` | Scaffold a new plugin with correct structure and conventions |
| `/hone <name>` | Audit an existing plugin's quality (8-category scoring with interactive fixes) |

Both tools dispatch research agents to fetch the latest Anthropic plugin docs before operating, ensuring scaffolds and audits reflect the current spec.

## Using Claudit's Knowledge Cache

If you're building a plugin or skill that needs Claude Code ecosystem knowledge (plugin specs, skill authoring, MCP, hooks), you can consume claudit's cached research instead of fetching docs yourself.

### Available Domains

| Domain | Content |
|--------|---------|
| `ecosystem` | Plugin system, skills, agents, hooks, MCP servers |
| `core-config` | Settings, permissions, CLAUDE.md, memory system |
| `optimization` | Performance patterns, over-engineering detection |

### Consumer Pattern

In your skill's research phase, invoke the knowledge skill and fall back to your own research if claudit isn't installed:

```markdown
### Step 1: Load Expert Context

Invoke `/claudit:knowledge ecosystem` to retrieve ecosystem knowledge.

**If the skill runs successfully** (outputs `=== CLAUDIT KNOWLEDGE: ecosystem ===` block):
- Use its output as Expert Context
- Also read your own domain-specific supplement for depth
- Skip research phase

**If the skill is not available** (claudit not installed — the invocation produces an error, is not recognized as a command, or produces no knowledge output):
- Fall back to your own research agents
```

The knowledge skill checks cache freshness and auto-refreshes stale domains transparently. Your plugin doesn't need to understand the cache protocol — just invoke and use the output.

Output is wrapped in delimiters for easy identification:

```
=== CLAUDIT KNOWLEDGE: ecosystem ===
[cached research content]
=== END CLAUDIT KNOWLEDGE ===

Knowledge source: cache (fresh, fetched 2026-03-22) | Domains: ecosystem
```

### Refreshing the Cache

Users can manually refresh with `/claudit:refresh [domain|all]` or check status with `/claudit:status`. The cache auto-refreshes on any `/claudit` or `/claudit:knowledge` invocation when stale.

## Installation

### From Marketplace

Add quickstop as a plugin marketplace, then install:

```bash
/plugin marketplace add acostanzo/quickstop
/plugin install claudit@quickstop
```

### From Source

```bash
git clone https://github.com/acostanzo/quickstop.git
claude --plugin-dir /path/to/quickstop/plugins/claudit
```

## Documentation

See the [Claude Code plugin documentation](https://docs.anthropic.com/en/docs/claude-code/plugins) for plugin authoring and marketplace details.

## License

MIT
