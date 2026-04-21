---
phase: 1
status: planning
tickets: [t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, a1, a2, a3]
updated: 2026-04-21
---

# Pronto Phase 1 — Kernel + Rubric + Audit Orchestrator

## The pivot in one paragraph

Pronto is the **meta-orchestrator** of Claude-Code-readiness. It audits a repo against a rubric of readiness dimensions, scores it, and for each dimension either (a) runs the recommended sibling plugin's audit and folds the score in, or (b) reports "not configured" with an install-or-walkthrough recommendation. Pronto doesn't re-implement what siblings do — claudit audits Claude Code config, skillet audits skills, commventional audits commit hygiene, etc. Pronto owns the rubric, the orchestration, a minimal kernel (AGENTS.md scaffold, `pronto/` vault structure), and a recommendation registry.

Pronto lives at `acostanzo/quickstop/plugins/pronto/`. It is a plugin, not a separate repo.

## Disposition of existing work

Before anything lands in quickstop:

1. **Close PR #1 on `acostanzo/pronto` without merging.** The four commits remain as reference via the PR thread.
2. **Archive `acostanzo/pronto`.** Gentler than deletion; preserves the paper trail; signals "no longer the home."
3. **Rebuild from scratch in quickstop.** Prior commits no longer map cleanly — scope has changed (self-hosting repo → plugin, bundled template → delegation to siblings). `git subtree` preserves would bring dead weight. Clean rebuild is faster and tells the right story in quickstop's log.

## The model

### Constellation

| Plugin | Status | Domain | Rubric dimension it owns |
|---|---|---|---|
| `pronto` | to build | Auditor + coach + kernel | Orchestration + kernel dimensions |
| `claudit` | exists | Claude Code config health | MCP, permissions, CLAUDE.md quality, context efficiency, over-engineering |
| `skillet` | exists | Skills | Skill quality + structure |
| `commventional` | exists | Commits + reviews | Commit/review hygiene |
| `towncrier` | exists | Release notes | — (ecosystem-adjacent; not in Phase 1 rubric) |
| `inkwell` (new) | Phase 2+ | Code documentation | Doc coverage + drift |
| `lintguini` (new) | Phase 2+ | Linters + formatters + language rules | Lint posture |
| `autopompa` (new) | Phase 2+ | Event emission / observability | Observability emit |

### Kernel surface (what pronto always owns)

- **AGENTS.md scaffolding** — presence + minimum-viable structure. Quality audit delegates to claudit.
- **`pronto/` vault structure** — `plans/{draft,active,done}`, `tickets/{open,closed}`, `adrs/`, `state.json`, `pulse.md`. Pronto's own memory.
- **Basic repo hygiene presence checks** — README, LICENSE, `.gitignore`, `.claude/`. Binary presence only; depth delegates.
- **The rubric itself** — registry of dimensions, weights, and which sibling plugin audits each.
- **Orchestration skills** — `/pronto:audit`, `/pronto:init`, `/pronto:improve`, `/pronto:status`.
- **Recommendation registry** — dimension → recommended sibling plugin + install command.
- **"Roll your own" references** — for each dimension, a doc describing pronto's recommended manual setup if the sibling isn't installed.

### Sibling-audit wire contract

**Current state:** sibling plugins (claudit, skillet, commventional) emit human-readable reports. None ships a `--json` flag or structured output schema today. The wire contract below is the **target state** pronto builds toward.

**Phase 1 reality:** pronto ships per-sibling **parsers** at `plugins/pronto/agents/parsers/<sibling>.md` — each parser is a narrow agent that takes the sibling's human-readable output and extracts the shared JSON shape. Glue until the sibling adopts the contract upstream. As siblings retrofit `plugin.json` declarations in their own plugins' work, pronto auto-discovers and bypasses the parser.

**Target declaration in `plugin.json`:**
```json
{
  "name": "claudit",
  "version": "2.6.0",
  "pronto": {
    "audits": [
      {
        "dimension": "claude-code-config",
        "command": "/claudit:audit --json",
        "weight_hint": 0.20
      }
    ]
  }
}
```

**Target output schema** (stdout JSON from the audit command, once siblings adopt):
```json
{
  "plugin": "claudit",
  "dimension": "claude-code-config",
  "categories": [
    { "name": "CLAUDE.md Quality", "weight": 0.20, "score": 85, "findings": [...] },
    { "name": "MCP Configuration", "weight": 0.15, "score": 70, "findings": [...] }
  ],
  "composite_score": 78,
  "letter_grade": "B",
  "recommendations": [...]
}
```

**Scoring semantics:** graded 0-100 per category, composite weighted to 0-100, letter-grade bands per claudit: A+ (95-100), A (90-94), B (75-89), C (60-74), D (40-59), F (0-39).

**Discovery:** pronto ships with a default registry of known siblings, their current audit commands, and their parsers. The `plugin.json` declaration is the forward path — as siblings adopt the contract, pronto auto-discovers and skips the parser. Retrofit of existing siblings (claudit, skillet, commventional) to declare the contract is tracked in *their* plugins' work, not pronto Phase 1.

### Readiness rubric

Draft weights — refinable. Total = 100.

| Dimension | Weight | Owned by | Kernel presence check |
|---|---|---|---|
| Claude Code config health | 25 | claudit | `.claude/` exists |
| Skills quality | 10 | skillet | ≥1 skill exists |
| Commit + review hygiene | 15 | commventional | Recent commits follow pattern |
| Code documentation | 15 | inkwell (Phase 2+) | README exists |
| Lint / format / language rules | 15 | lintguini (Phase 2+) | Lint config file exists |
| Event emission | 5 | autopompa (Phase 2+) | Optional — 0 weight until installed |
| AGENTS.md scaffold | 10 | pronto kernel | Non-empty AGENTS.md present |
| Pronto vault | 5 | pronto kernel | `pronto/` directory with expected structure |

### Scoring rules

- **Sibling installed, audit ran:** dimension contributes its actual 0-100 score, weighted by the rubric percentage.
- **Sibling absent, kernel presence check passes:** dimension score is **capped at 50** — "presence confirmed; depth not measured." Prevents the perverse incentive where an empty-scaffold repo scores higher than one with the auditor installed and honest findings. Installing the sibling can only move the score up toward reality.
- **Sibling absent, kernel presence check fails:** dimension scores 0.
- **Cap value (50) is a tuning knob.** Rebalanceable once real audits accumulate; Phase 1 ships at 50.
- Dimensions where the recommended sibling is Phase 2+ (inkwell, lintguini, autopompa) score under presence-cap rules until the sibling lands. When the sibling arrives, its audit replaces the presence check and contributes the depth score.

## Tickets

### T1 — Scaffold plugins/pronto/ via smith

Run `smith` in quickstop to generate `plugins/pronto/` with correct structure: `.claude-plugin/plugin.json`, `skills/`, `agents/`, `references/`, `README.md`. Version 0.1.0. Plugin.json declares the `pronto` extension block (empty for now — pronto's audits populate in later tickets).

**Acceptance:** `plugins/pronto/` exists; loads cleanly under `claude --plugin-dir plugins/pronto`; `/reload-plugins` surfaces no errors; `plugin.json` parses as valid JSON.

### T2 — Define readiness rubric + document wire contract

Write `plugins/pronto/references/rubric.md` — the canonical dimension list with weights, owners, and presence-check rules. Write `plugins/pronto/references/sibling-audit-contract.md` — the plugin.json declaration schema, target stdout JSON schema, letter-grade bands, and the Phase 1 parser pattern for siblings that haven't yet adopted the contract upstream.

**Acceptance:** rubric.md and sibling-audit-contract.md exist, both link from the plugin README, both validate as portable (no hostnames, no author-specific paths).

### T3 — Kernel presence checks

Skill: `plugins/pronto/skills/kernel-check/`. Implements non-delegable presence checks: AGENTS.md non-empty, `pronto/` vault structure valid, README/LICENSE/.gitignore/.claude present. Emits results in the sibling-audit output shape with `plugin: "pronto-kernel"`.

**Acceptance:** run against three fixtures (bare repo, pronto-init'd repo, fully populated repo) — each produces the expected score per category.

### T4 — `/pronto:audit` orchestrator + per-sibling parsers

Primary skill: `plugins/pronto/skills/audit/`. Reads rubric, walks the sibling registry (default + plugin.json discovered), shells to each sibling's audit command, extracts scores, aggregates into composite score + letter grade, emits markdown scorecard + optional `--json` output. If a sibling is registered but not installed: mark dimension as "not configured — recommended: X."

Ships per-sibling parsers at `plugins/pronto/agents/parsers/{claudit,skillet,commventional}.md` — narrow agents that take each sibling's human-readable output and emit the shared JSON shape. Parsers are glue until siblings adopt the `plugin.json` contract upstream.

**Acceptance:** runs end-to-end against a test repo with claudit+skillet+commventional installed, produces a composite scorecard naming each dimension, score, contributing plugin, and findings. Each parser tested independently against a canonical example of its sibling's output.

### T5 — Kernel template content

`plugins/pronto/templates/` — the minimal tree `/pronto:init` drops into a target repo:
- `AGENTS.md` scaffold (portable, no author references)
- `pronto/` vault skeleton (empty plans/tickets/adrs dirs, starter `state.json`, starter `pulse.md`)
- `.claude/` seed (empty dirs + placeholder README explaining what belongs there)
- `.gitignore` additions for pronto vault noise

**Acceptance:** all files portable, all frontmatter valid YAML, grep for author-specific strings returns zero matches.

### T6 — `/pronto:init` skill

Skill: `plugins/pronto/skills/init/`. Copies template content from `${CLAUDE_PLUGIN_ROOT}/templates/` into target repo. Detects existing files and refuses to overwrite without `--force`. For each recommended sibling plugin not already installed, proposes the install command (e.g., `/plugin install claudit@quickstop`) and invokes it in-conversation on user consent — pronto orchestrates the conversation rather than installing programmatically; Claude Code's normal install path runs with the user in the loop. Idempotent — safe to re-run.

**Acceptance:** run in empty dir produces full kernel; run again without `--force` is a no-op with clear output; run with `--force` overlays updates without destroying user edits outside template paths.

### T7 — `/pronto:status` skill

Skill: `plugins/pronto/skills/status/`. Reports: installed sibling plugins + versions, last audit score + date, dimensions below threshold, dimensions not configured. Reads state from `pronto/state.json`. Two-line summary + optional `--verbose` full dump.

**Acceptance:** run on pronto-init'd repo produces a coherent one-screen report; run on a repo with no pronto state reports "no audit run yet."

### T8 — `/pronto:improve` skill

Skill: `plugins/pronto/skills/improve/`. Reads last audit from `pronto/state.json`, walks lowest-scoring dimensions first, offers per dimension: "install recommended plugin X," "walk through rolling your own per `<ref>`," or "skip." Writes a journal entry to `pronto/pulse.md` noting what was chosen.

**Acceptance:** after `/pronto:audit` run, `/pronto:improve` surfaces the weakest dimension first and offers a coherent choice menu.

### T9 — Recommendation registry

Data file: `plugins/pronto/references/recommendations.json`. Maps dimension → recommended sibling plugin + install command + reference doc path. Loaded by T6 and T8.

**Acceptance:** file exists, schema-validated, every dimension in the rubric has a recommendation entry (even if the sibling is Phase 2+).

### T10 — "Roll your own" references

One markdown file per dimension in `plugins/pronto/references/roll-your-own/` — how to achieve that dimension's readiness without installing pronto's recommended sibling. Portable (no author-specific tools), actionable, under ~200 lines each.

**Acceptance:** every dimension has a roll-your-own doc; each doc links from the recommendation registry; each doc leaves the reader with a concrete first step.

### T11 — Audit report format

Markdown scorecard template (used by T4) plus JSON output shape (`--json` flag). The markdown report: composite grade up top, per-dimension breakdown, weakest-dimensions-first ordering, a "what's next" footer pointing to `/pronto:improve`.

**Acceptance:** produced reports are skimmable in under 30s and machine-parseable via `--json`.

### T12 — Research integration

Pronto's audit skill consumes claudit's cached research (`~/.cache/claudit/`) rather than fetching Anthropic docs fresh. Follow skillet's research-first pattern for dispatching research agents when cache is cold. Document the cache protocol in `references/research-integration.md`.

**Acceptance:** audit runs on a fresh machine with cold cache populate it; subsequent runs are cache-hits; invalidation is date-based per claudit's existing scheme.

## Acceptance bars

Every A-bar passes on a fresh machine with only quickstop installed.

### A1 — Fresh-repo bootstrap + audit

1. `cd $(mktemp -d) && git init`
2. `/pronto:init` — kernel lands, prompt accepted, recommended siblings installed
3. `/pronto:audit` — produces a composite scorecard
4. Verify: kernel presence dimensions pass, sibling-owned dimensions report depth scores from their audits, composite letter grade appears

**Pass:** scorecard renders in <5s, every dimension has a score or "not configured" reason, no tracebacks.

### A2 — Sibling audit aggregation

In a pre-populated test repo (with existing `.claude/`, skills, commit history):
1. Install claudit, skillet, commventional alongside pronto
2. `/pronto:audit`
3. Verify: composite score reflects weighted contributions from each sibling's own audit output; hand-compute the expected score and confirm match within ±2 points

**Pass:** aggregation math is correct, each sibling's audit runs exactly once, output JSON round-trips back through a JSON parser without loss.

### A3 — Graceful degradation

Same test repo as A2 but with zero siblings installed beyond pronto:
1. `/pronto:audit`
2. Verify: every dimension reports "not configured — recommended: X" with install command; kernel presence dimensions still score normally; composite score reflects that most dimensions are ungraded

**Pass:** no sibling-missing failure is a traceback; each non-configured dimension offers a clear next step.

## Out of scope (Phase 2+)

- Building `inkwell`, `lintguini`, or `autopompa`
- Retrofitting claudit/skillet/commventional with `plugin.json` audit declaration (tracked in those plugins' own work)
- Graded heuristics beyond what the siblings already provide
- Playwright MCP integration in the template
- `/pronto:worktree`, `/pronto:audit coverage`, `/pronto:learn`
- ADR promotion workflow
- CI integration
- Cross-project aggregation (that's a consumer-orchestrator concern, stays out of pronto entirely)

## Definition of done

- All T-tickets land with their own atomic conventional commits under `plugins/pronto/`.
- All A-bars pass on a fresh machine with only quickstop installed.
- `plugins/pronto/README.md` explains the model in under 200 words and links to the rubric + contract references.
- Comprehensive grep for author-specific strings (`anthony`, `batcomputer`, `batdev`, `batvault`, `alfred`, `grapple-gun`, `batctl`, `mind-palace`) returns zero matches in `plugins/pronto/`.
- Plugin loads cleanly under `claude --plugin-dir plugins/pronto` with no errors on `/reload-plugins`.
- One ADR lands: `plugins/pronto/adrs/001-meta-orchestrator-model.md` — records the pivot from self-contained template to meta-orchestrator.
