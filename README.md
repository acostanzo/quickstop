# Quickstop

Plugins that enhance Claude Code workflows. Each one solves a specific problem. Install whatever solves yours; nothing depends on anything else.

## Plugins

| Plugin | Problem solved |
|---|---|
| [claudit](plugins/claudit) | Audit and optimise your Claude Code config. Caches current Claude Code ecosystem knowledge for any subsequent agent task. |
| [avanti](plugins/avanti) | SDLC in markdown — plans, tickets, ADRs, pulse — no Jira required. |
| [commventional](plugins/commventional) | Consistent commit voice, review style, engineering ownership. |
| [inkwell](plugins/inkwell) | Documentation toolkit Claude can write to and query. |
| [towncrier](plugins/towncrier) | Hook into Claude Code events for observability and downstream automation. |

## Install

Add quickstop as a plugin marketplace, then install whichever plugins you want:

```bash
/plugin marketplace add acostanzo/quickstop
/plugin install claudit@quickstop
/plugin install avanti@quickstop
/plugin install commventional@quickstop
/plugin install inkwell@quickstop
/plugin install towncrier@quickstop
```

Or install from a local clone:

```bash
git clone https://github.com/acostanzo/quickstop.git
claude --plugin-dir /path/to/quickstop/plugins/<plugin>
```

## Per-plugin details

### Claudit (v2.6.0)

Audit and optimize your Claude Code configuration. Caches current Claude Code ecosystem knowledge so any subsequent agent task — building a skill, configuring an MCP, authoring CLAUDE.md, debugging hooks — can read it via `/claudit:knowledge` instead of re-fetching docs.

- Recursive CLAUDE.md discovery: root, subdirectory, `.claude/rules/`, `CLAUDE.local.md`, and `@import` references
- Automatic scope detection — comprehensive audit inside a git repo, global-only outside
- Research-first: subagents fetch official Anthropic docs before analysis; over-engineering detection is the highest-weighted scoring category
- Decision memory annotates recommendations with past context (team-shared, committable)
- Optional PR delivery with educational inline comments
- Knowledge cache at `~/.cache/claudit/` with version-based + 7-day TTL invalidation, exposed to any agent task via `/claudit:knowledge [domain|all]`

**Commands:** `/claudit`, `/claudit:knowledge`, `/claudit:refresh`, `/claudit:status`

### Avanti (v0.1.5)

SDLC in markdown — authors and maintains the records under `project/` (plans, tickets, ADRs, pulse journal) and drives each record through its lifecycle.

- Three lifecycles: plans (`draft → active → done`), tickets (`open → closed`), ADRs (`proposed → accepted → superseded`)
- Folder-as-primary — the folder a record sits in is its authoritative state; frontmatter `status:` mirrors for machine-readability
- Plan-scoped tickets — every ticket belongs to a plan; no standalone tickets
- Per-day pulse files (`project/pulse/YYYY-MM-DD.md`) — append-only, merge-friendly
- Templates ship portable; skills auto-create destination subdirectories on demand

**Commands:** `/avanti:plan`, `/avanti:ticket`, `/avanti:adr`, `/avanti:promote`, `/avanti:pulse`, `/avanti:status`

### Commventional (v2.1.0)

Enforce conventional commits, conventional comments, and engineering ownership for commits, PRs, and code reviews.

- Auto-invoking `commventional` skill activates on commit, PR, and review context without explicit commands
- Sub-agent architecture: `commit-crafter` for diffs, `review-formatter` for feedback
- Three conventions: conventional commits, conventional comments, engineering ownership
- Three consumer-invoked skills for engineering-ownership wiring: `:strip-trailers` (capability), `:strip-pr-body` (one-shot PR cleanup), `:install-trailer-stripper` (writes Claude Code or git-hook wirings into the consumer's surface on demand)
- Reviews post as a single GitHub review submission with grouped inline comments at `path:line` — `review-formatter` emits a locked JSON contract; `bin/commventional-post-review.sh` is the deterministic poster
- ADR-006 conformant — no plugin-installed Claude Code hooks; trigger surface belongs to the consumer

**Auto-invokes on:** commits, pull requests, code reviews

### Inkwell (v0.4.1)

Documentation toolkit for Claude Code. Inkwell owns a repo's `docs/` tree the way avanti owns its `project/` tree: write, search, query, and tidy are the daily surface.

- Four skills: `/inkwell:doc` (Diátaxis-template scaffold/update), `/inkwell:search` (FTS5 over `docs/`), `/inkwell:query` (RAG Q&A with citations and corroboration), `/inkwell:tidy` (drift-finder)
- Diátaxis four-quadrant templates ship under `templates/` — `concept`, `how-to`, `reference`, `tutorial`
- FTS5 index at `docs/.inkwell.fts5.db` (gitignored), rebuilt on-write by `bin/inkwell-index.sh`
- Inference-time code corroboration — Tier 1 deterministic name-resolution, Tier 2 LLM-judged behavioural verification, Tier 3 annotated-only — architecture in ADR-007

**Commands:** `/inkwell:doc`, `/inkwell:search`, `/inkwell:query`, `/inkwell:tidy`

### Towncrier (v0.4.1)

Emit a structured JSON event for every Claude Code hook to a configurable transport. Pure observability — strictly pass-through, never alters Claude's behavior.

- Registers all 26 documented hook events; each one is wrapped in a uniform envelope (`id`, `ts`, `type`, `host`, `session_id`, `pid`, `cwd`, `data`)
- Pluggable transport — `file:` (default), `fifo:`, or `http://` — via `~/.towncrier/config.json` or `TOWNCRIER_TRANSPORT` env var
- Hard 2s timeout per emit with automatic fallback to the default file — Claude hooks never hang and events are never silently dropped
- Strictly observational: pass-through `PermissionRequest`, no stdout interference, no behavior changes
- `skip_events` config filter for muting noisy events without uninstalling
- Producer only — write your own consumer against the documented envelope

**Default output:** `~/.towncrier/events.jsonl` — `tail -F` and `jq` to start

## Using Claudit's Knowledge Cache

Claudit's knowledge cache is general-purpose. Once it's been populated (any `/claudit` or `/claudit:refresh` invocation does this), any agent task that needs current Claude Code ecosystem knowledge can read it via `/claudit:knowledge` instead of re-fetching docs.

| Domain | Covers |
|---|---|
| `ecosystem` | MCP servers, plugins, hooks, skills, sub-agents |
| `core-config` | Settings, permissions, CLAUDE.md, memory system |
| `optimization` | Performance patterns, over-engineering detection |

In a skill or agent prompt, invoke `/claudit:knowledge ecosystem` (or whichever domain you need) and use the output as expert context. The skill checks freshness and auto-refreshes stale domains transparently. If claudit is not installed, fall back to your own research.

```
=== CLAUDIT KNOWLEDGE: ecosystem ===
[cached research content]
=== END CLAUDIT KNOWLEDGE ===

Knowledge source: cache (fresh, fetched 2026-03-22) | Domains: ecosystem
```

Manual refresh: `/claudit:refresh [domain|all]`. Status: `/claudit:status`.

## Dev Tools

Repo-level skills for plugin authors (not distributable plugins — these live in `.claude/`):

| Command | Purpose |
|---------|---------|
| `/smith <name>` | Scaffold a new plugin with correct structure and conventions |
| `/hone <name>` | Audit an existing plugin's quality (8-category scoring with interactive fixes) |

Both tools dispatch research agents to fetch the latest Anthropic plugin docs before operating, ensuring scaffolds and audits reflect the current spec.

## Documentation

See the [Claude Code plugin documentation](https://docs.anthropic.com/en/docs/claude-code/plugins) for plugin authoring and marketplace details.

## License

MIT
