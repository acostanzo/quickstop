# Pronto Readiness Rubric

The canonical list of readiness dimensions pronto audits, along with weights, owners, and kernel presence checks. This document is authoritative: `/pronto:audit` reads it directly.

## Dimensions

Total weight = 100. Weights are tunable but must sum to 100.

| Dimension | Slug | Weight | Owned by | Kernel presence check | Status |
|---|---|---|---|---|---|
| Claude Code config health | `claude-code-config` | 25 | `claudit` | `.claude/` exists | Shipped |
| Skills quality | `skills-quality` | 10 | `skillet` | ≥1 skill exists under `.claude/skills/` or a plugin's `skills/` | Shipped |
| Commit + review hygiene | `commit-hygiene` | 15 | `commventional` | Recent commits follow conventional-commit pattern | Shipped |
| Code documentation | `code-documentation` | 15 | `inkwell` | README exists and is non-empty | Phase 2+ |
| Lint / format / language rules | `lint-posture` | 15 | `lintguini` | Language-appropriate lint config file exists (e.g. `.eslintrc*`, `pyproject.toml` with `[tool.ruff]`, `rustfmt.toml`) | Phase 2+ |
| Event emission | `event-emission` | 5 | `autopompa` | Observability instrumentation detected (e.g. OpenTelemetry config, event-bus references, structured logging setup) | Phase 2+ |
| AGENTS.md scaffold | `agents-md` | 10 | `pronto` kernel | Non-empty `AGENTS.md` at repo root | Shipped (this plugin) |
| Project record | `project-record` | 5 | `avanti` | `project/` directory with expected subdirs (`plans/`, `tickets/`, `adrs/`, `pulse/`) | Phase 1b |

### Sum check

25 + 10 + 15 + 15 + 15 + 5 + 10 + 5 = **100** ✓

## Scoring rules

Every dimension produces a 0-100 score. The composite is the weight-weighted mean.

### Sibling installed, audit ran

Dimension contributes its actual 0-100 score from the sibling's audit, multiplied by the rubric weight / 100. The sibling's audit may itself be weighted across sub-categories (claudit has six; avanti has four) — pronto treats the sibling's `composite_score` as the dimension score.

### Sibling absent, kernel presence check passes

Dimension score is **capped at 50** — "presence confirmed; depth not measured."

Rationale: without this cap, an empty scaffold scores higher than a fully-populated repo whose sibling audit honestly reports issues. The cap prevents that perverse incentive — installing the recommended sibling can only move the score up (toward the real state), never down.

The cap value (50) is a tuning knob. Once real audits accumulate across many consumer repos, it's rebalanceable. Phase 1 ships at 50.

### Sibling absent, kernel presence check fails

Dimension scores **0**. The recommended action is either to install the sibling or to roll-your-own per the dimension's roll-your-own reference (see `references/roll-your-own/<slug>.md`).

### Dimensions whose recommended sibling isn't yet shipped

`inkwell`, `lintguini`, `autopompa` are Phase 2+. `avanti` is Phase 1b. Until their siblings ship, these dimensions score under the presence-cap rules above. When the sibling arrives, its audit replaces the presence check and contributes the full depth score.

## Letter grades

Composite score → letter grade:

| Grade | Score range | Label |
|---|---|---|
| A+ | 95-100 | Exceptional |
| A | 90-94 | Excellent |
| B | 75-89 | Good |
| C | 60-74 | Fair |
| D | 40-59 | Needs Work |
| F | 0-39 | Critical |

These match claudit's bands so scorecards are visually comparable across tools.

## Presence-check semantics (kernel detail)

The kernel presence checks are deliberately **coarse** — they answer "does the artifact exist" not "is it any good." Depth is every sibling's job. Kernel checks are the bright-line test that gates dimensions between `0` and `50` in the absence of a sibling audit.

| Dimension | Presence check (exact) |
|---|---|
| `claude-code-config` | `.claude/` directory exists at repo root |
| `skills-quality` | At least one `SKILL.md` under `.claude/skills/*/SKILL.md` OR `plugins/*/skills/*/SKILL.md` OR `~/.claude/skills/*/SKILL.md` (scoped to project if in a project) |
| `commit-hygiene` | The 20 most-recent commits are ≥80% conventional-commit-shaped (`^(feat\|fix\|chore\|docs\|refactor\|test\|perf\|build\|ci\|style)(\(.+\))?!?:`) |
| `code-documentation` | `README.md` exists at repo root and is >=10 lines non-whitespace |
| `lint-posture` | Any of: `.eslintrc*`, `.prettierrc*`, `pyproject.toml` (containing `[tool.ruff]` or `[tool.black]` or `[tool.flake8]`), `.flake8`, `rustfmt.toml`, `Cargo.toml` containing `[lints]`, `.golangci.yml`, `biome.json`, `dprint.json` |
| `event-emission` | grep for any of: `opentelemetry`, `OTEL_`, `tracer`, `metric`, `event_bus`, `eventbus`, `emit(`, `structlog`, `pino`, `winston`, `logrus` in source files |
| `agents-md` | `AGENTS.md` exists at repo root and is >=5 lines non-whitespace |
| `project-record` | `project/` directory exists AND contains all of: `plans/`, `tickets/`, `adrs/`, `pulse/` |

Presence checks are fast — pure filesystem + cheap grep. A full pronto run with no siblings installed should complete presence checks in under a second on a cold cache.

## Extending the rubric

Dimensions are additive. Adding a new dimension requires:

1. A new row in the table above, with a fresh slug and an integer weight.
2. Rebalancing existing weights so the total remains 100.
3. A presence check written into `plugins/pronto/skills/kernel-check/`.
4. A recommendation entry in `plugins/pronto/references/recommendations.json`.
5. A roll-your-own reference at `plugins/pronto/references/roll-your-own/<slug>.md`.

Weight rebalancing is a version-bump-worthy change — consumers' historical scores shift. Changelog per rebalance.

## See also

- [`sibling-audit-contract.md`](sibling-audit-contract.md) — the wire contract siblings emit against, and the parser pattern for siblings that haven't adopted it yet.
- [`recommendations.json`](recommendations.json) — machine-readable dimension-to-sibling recommendation registry.
- [`roll-your-own/`](roll-your-own/) — manual-setup walkthroughs per dimension.
