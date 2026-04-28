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

## Mechanical vs judgment split

Phase 1.5 PR 3b mechanized every scoreable signal in the shipped
dimensions. The goal is determinism: the same filesystem state must
produce the same composite, byte-for-byte, across runs. Each row below
lists how the dimension is scored and where it lands on the
mechanical/judgment axis.

| Dimension | Weight | Score path | Residual judgment |
|---|---|---|---|
| `claude-code-config` | 25 | Deterministic shell scorer at `agents/parsers/scorers/score-claudit.sh` — counts non-blank lines, regex matches, hook entries, MCP servers, broad allow-list globs, aggregate instruction lines, broken `@import`s. | None. |
| `skills-quality` | 10 | Deterministic shell scorer at `agents/parsers/scorers/score-skillet.sh` — per-skill frontmatter field presence, line-count thresholds, `TODO` counts, stray-file counts, broken `references/` pointers. | None. |
| `commit-hygiene` | 15 | Deterministic shell scorer at `agents/parsers/scorers/score-commventional.sh` — `git log` regex match ratios plus trailer and auto-attribution counts. Conventional Comments defaults to 100 with a low-severity "no review signal" note; the audit stays network-free. | None. |
| `code-documentation` | 15 | Kernel presence check: `README` ≥10 non-blank lines → 50 capped (sibling `inkwell` not yet shipped). | None. |
| `lint-posture` | 15 | Deterministic presence check via `skills/audit/presence-check.sh lint-posture ${REPO_ROOT}` — fixed list of language-appropriate lint config files → 50 capped (sibling `lintguini` not yet shipped). | None. |
| `event-emission` | 5 | Deterministic presence check via `skills/audit/presence-check.sh event-emission ${REPO_ROOT}` — `grep -rqE` with the documented pattern set and a fixed `--exclude-dir` list → 50 capped (sibling `autopompa` not yet shipped). | None. |
| `agents-md` | 10 | Kernel binary: `AGENTS.md` exists and ≥5 non-blank lines → 100, else 0. No presence cap — this dimension is always kernel-driven. | None. |
| `project-record` | 5 | Avanti's native `/avanti:audit --json` (declared in `plugins/avanti/.claude-plugin/plugin.json`) returns a deterministic composite. Falls back to kernel binary (capped at 50) only if the avanti dispatch itself fails. | None. |

**100% of the composite weight is mechanical.** The parser agents
(`agents/parsers/<sibling>.md`) are now thin wrappers over the
deterministic shell scorers — they execute one Bash command and emit
the script's stdout verbatim. Presence checks are literal Bash
one-liners. No LLM judgment participates in any score path.

"Residual judgment" is listed for traceability. If a dimension ever
acquires a genuinely fuzzy signal (one that cannot be reduced to a
count, regex, or threshold), the row above should name what it is and
why mechanizing it is prohibitive — that becomes the next determinism
lever.

### Why this matters

Before PR 3b, parser agents were Haiku sub-Claude invocations given a
"start at 100 and deduct" playbook. Running the same playbook twice
produced different deductions because the LLM sometimes miscounted
matches, sometimes missed them entirely, and sometimes applied a
deduction a different number of times. The reported PR 3a baseline
spreads on the `mid` fixture — claude-code-config stddev 5.2,
commit-hygiene stddev 5.2, skills-quality stddev 2.7, event-emission
stddev 15.7, composite stddev 1.4, grade-flip rate 22% — were not
scoring disagreements; they were measurement errors from a
non-deterministic measurement device.

Replacing the playbook with a shell script that performs the same
counts via `grep`, `wc`, `jq`, and `git log` makes the device
deterministic. The parser agent's residual job is to run the script
and pass its output through unchanged — that residual is small enough
that a Haiku wrapper is acceptable (and still useful: it keeps the
dispatch shape intact for the day a sibling ships native `--json` and
the parser becomes a no-op to delete).


## Observation translation rules

Per ADR-005 §3 and the v2 wire contract (`sibling-audit-contract.md`), siblings on schema 2 emit `observations[]` instead of (or alongside) the legacy `composite_score` field. Each observation carries a stable `id` and one of four `kind` values — `ratio`, `count`, `presence`, `score`. Pronto's translator (`agents/parsers/scorers/observations-to-score.sh`) reads the per-dimension stanzas below, applies the matching rule to each observation, and produces the dimension's composite score.

Stanza shape:

- `observations[]` — one rule per known observation `id`. Required keys: `id`, `kind`, `rule`. `kind`-specific keys: `bands` for `kind: ratio` and `kind: count` with `rule: ladder`; `present`/`absent` integers for `kind: presence` with `rule: boolean`; `rule: passthrough` (no extra keys) for `kind: score`. An optional `weight` (decimal 0.0–1.0) overrides the default equal-share weighting; if any observation declares a weight, every observation in the stanza must declare one.
- `default_rule` — applied when an observation's `kind` is `score` and no specific rule is registered. Always `passthrough` for v2 observations.

Bands evaluate top-to-bottom; the first matching `gte` (numeric threshold) wins, falling through to `else` when none match. Observation `id`s with no matching rubric rule are dropped per the contract's missing-rule policy: dropped observations are recorded in `sibling_integration_notes`, the dimension is scored from the remainder, and if every observation drops out the translator falls through to legacy `composite_score` passthrough (then to presence-cap if no `composite_score` is present either).

The three stanzas below cover the parser-driven dimensions that ship today (`claude-code-config`, `skills-quality`, `commit-hygiene`). Each is calibrated against its current scorer's category logic so that — when the matching sibling migrates to native `observations[]` emission — the rubric-applied score reproduces today's path. Until then, the shipped siblings stay on v1 and ride the back-compat passthrough rule unchanged.

### `claude-code-config` translation rules

```json
{
  "observations": [
    {
      "id": "claude-md-redundancy-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 0.20, "score": 40 },
        { "gte": 0.10, "score": 70 },
        { "gte": 0.05, "score": 85 },
        { "else": 100 }
      ]
    },
    {
      "id": "mcp-server-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 6, "score": 50 },
        { "else": 100 }
      ]
    },
    {
      "id": "claude-md-line-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 200, "score": 80 },
        { "gte": 10,  "score": 100 },
        { "else": 60 }
      ]
    },
    {
      "id": "settings-default-mode-explicit",
      "kind": "presence",
      "rule": "boolean",
      "present": 100,
      "absent": 80
    },
    {
      "id": "broad-allow-glob-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 2, "score": 70 },
        { "gte": 1, "score": 85 },
        { "else": 100 }
      ]
    },
    {
      "id": "claude-md-arrival-section-missing-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 3, "score": 80 },
        { "gte": 1, "score": 95 },
        { "else": 100 }
      ]
    }
  ],
  "default_rule": "passthrough"
}
```

The bands above mirror `score-claudit.sh`: the redundancy ratio reflects its 5/10/20-percent CLAUDE.md restated-builtin deduction ladder; `mcp-server-count` lands at 50 above the >5 sprawl threshold (its per-observation hit, after equal-share averaging across the six observations, lands ≈v1's -10 on composite) and stays at 100 below it, with absent `.mcp.json` treated as MCP-neutral via `else: 100` to match score-claudit's "no MCP feature configured, no deductions" behaviour; `claude-md-line-count` matches the dual ≥200 verbosity and <10 skeletal deductions; `settings-default-mode-explicit` and `broad-allow-glob-count` track the security-posture deductions for missing/bypass `defaultMode` and broad `Bash(*)`/`Write(*)` allow entries respectively; `claude-md-arrival-section-missing-count` mirrors score-claudit's CQ category 5-points-per-missing-section deduction (overview/architecture, testing, conventions) so a fixture like `mid` — one missing section, otherwise neutral — converges with the v1 path. When `claudit` migrates to native v2 emission it should emit observation IDs from this set; until then the v1 `composite_score` passthrough applies.

### `skills-quality` translation rules

```json
{
  "observations": [
    {
      "id": "skill-frontmatter-completeness-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 0.95, "score": 100 },
        { "gte": 0.80, "score": 85 },
        { "gte": 0.60, "score": 70 },
        { "else": 40 }
      ]
    },
    {
      "id": "skill-skeletal-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 1, "score": 60 },
        { "else": 100 }
      ]
    },
    {
      "id": "skill-todo-marker-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 100, "score": 70 },
        { "gte": 50,  "score": 80 },
        { "gte": 20,  "score": 90 },
        { "gte": 5,   "score": 95 },
        { "else": 100 }
      ]
    },
    {
      "id": "skill-broken-references-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 20, "score": 60 },
        { "gte": 10, "score": 80 },
        { "gte": 5,  "score": 90 },
        { "gte": 1,  "score": 95 },
        { "else": 100 }
      ]
    },
    {
      "id": "skill-stray-file-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 3, "score": 85 },
        { "gte": 1, "score": 95 },
        { "else": 100 }
      ]
    }
  ],
  "default_rule": "passthrough"
}
```

The bands track `score-skillet.sh`'s per-skill averaged deductions: `skill-frontmatter-completeness-ratio` reflects its `name`/`description`/`allowed-tools`/`disable-model-invocation` 40/30/20/10 ladder collapsed to a fraction-of-required-fields-present view; `skill-skeletal-count` marks any skill under 20 non-blank lines; `skill-todo-marker-count` and `skill-broken-references-count` ride a multi-skill aggregate ladder (5/20/50/100 and 1/5/10/20 thresholds respectively) — the original `gte 3 → 70` / `gte 2 → 60` shapes were calibrated against M1's claudit per-config counts and undershot the score-skillet path by ~11 points on the harness `mid` fixture (22 skills, 31 aggregate TODOs ≈ 1.4/skill, 8 broken refs ≈ 0.36/skill); the rescaled bands re-converge the rubric path on score-skillet's per-skill cap-and-average within ±1 across `clean`/`mid`/`noisy`. `skill-stray-file-count` tracks the per-skill stray-file deduction unchanged. Aggregation across multiple skills happens inside the sibling before emission — the observations carry already-aggregated totals.

### `commit-hygiene` translation rules

```json
{
  "observations": [
    {
      "id": "conventional-commit-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 0.95, "score": 100 },
        { "gte": 0.80, "score": 90 },
        { "gte": 0.50, "score": 70 },
        { "else": 40 }
      ]
    },
    {
      "id": "auto-trailer-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 6, "score": 40 },
        { "gte": 3, "score": 70 },
        { "gte": 1, "score": 90 },
        { "else": 100 }
      ]
    },
    {
      "id": "auto-attribution-marker-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 3, "score": 70 },
        { "gte": 1, "score": 90 },
        { "else": 100 }
      ]
    },
    {
      "id": "review-signal-presence",
      "kind": "presence",
      "rule": "boolean",
      "present": 100,
      "absent": 100
    }
  ],
  "default_rule": "passthrough"
}
```

The bands track `score-commventional.sh`: `conventional-commit-ratio` mirrors its 0.95/0.80/0.50 thresholds (0/-10/-30/-60); `auto-trailer-count` reflects the -10-per-trailer ladder capped at -60; `auto-attribution-marker-count` reflects the parallel "Generated with Claude Code" marker count capped at -30; `review-signal-presence` defaults to 100 either way because the sibling deliberately runs network-free and treats absent review-comment signal as informational, not as a deduction (matching `cmt_score=100` in the current scorer).

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
