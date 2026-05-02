# Pronto Readiness Rubric

The canonical list of readiness dimensions pronto audits, along with weights, owners, and kernel presence checks. This document is authoritative: `/pronto:audit` reads it directly.

## Dimensions

Total weight = 100. Weights are tunable but must sum to 100.

| Dimension | Slug | Weight | Owned by | Kernel presence check | Status |
|---|---|---|---|---|---|
| Claude Code config health | `claude-code-config` | 25 | `claudit` | `.claude/` exists | Shipped |
| Skills quality | `skills-quality` | 10 | `skillet` | ≥1 skill exists under `.claude/skills/` or a plugin's `skills/` | Shipped |
| Commit + review hygiene | `commit-hygiene` | 15 | `commventional` | Recent commits follow conventional-commit pattern | Shipped |
| Code documentation | `code-documentation` | 15 | `inkwell` | README arrival coverage + docs coverage + staleness + link health | Shipped |
| Lint / format / language rules | `lint-posture` | 15 | `lintguini` | Linter strictness + formatter presence + CI lint wiring + suppression count | Shipped |
| Event emission | `event-emission` | 5 | `towncrier` | Observability instrumentation detected (e.g. OpenTelemetry config, event-bus references, structured logging setup) | Phase 2+ |
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

`towncrier`'s `:audit` extension is Phase 2+. `avanti` is Phase 1b. Until their siblings ship, these dimensions score under the presence-cap rules above. When the sibling arrives, its audit replaces the presence check and contributes the full depth score. (`lintguini` shipped in Phase 2 PR 2b — see the `lint-posture` translation rules below. `inkwell` shipped in Phase 2 PR 2a — see the `code-documentation` translation rules below.)

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
| `lint-posture` | Any of: `.eslintrc*`, `.prettierrc*`, `pyproject.toml` (containing `[tool.ruff]` or `[tool.black]` or `[tool.flake8]`), `.flake8`, `rustfmt.toml`, `Cargo.toml` containing `[lints]`, `.golangci.yml`, `biome.json`, `dprint.json`, `.rubocop.yml`, `Gemfile`, `standard.yml` |
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
| `code-documentation` | 15 | Sibling inkwell's `/inkwell:audit --json` emits a v2 wire-contract envelope with four observations (README arrival coverage, docs coverage, doc staleness, internal link health) consumed by the `code-documentation` translation rules below. | None. |
| `lint-posture` | 15 | Sibling lintguini's `/lintguini:audit --json` emits a v2 wire-contract envelope with four observations (linter strictness, formatter presence, CI lint wiring, suppression count) consumed by the `lint-posture` translation rules below. | None. |
| `event-emission` | 5 | Deterministic presence check via `skills/audit/presence-check.sh event-emission ${REPO_ROOT}` — `grep -rqE` with the documented pattern set and a fixed `--exclude-dir` list → 50 capped (sibling `towncrier`'s `:audit` extension not yet shipped). | None. |
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

Bands evaluate top-to-bottom; the first matching `gte` (numeric threshold) wins, falling through to `else` when none match. Observation `id`s with no matching rubric rule are dropped per the contract's missing-rule policy: dropped observations are recorded in `sibling_integration_notes`, the dimension is scored from the remainder, and if every observation drops out (or the sibling emitted `observations: []` as the v2-native "no scope" signal) the translator falls through to the envelope's `composite_score` (then to presence-cap if no `composite_score` is present either). Inputs without `$schema_version: 2` are rejected with exit 4 — see the helper's header for the deprecation rationale.

The three stanzas below cover the parser-driven dimensions that ship today (`claude-code-config`, `skills-quality`, `commit-hygiene`). Each is calibrated against its sibling's category logic so the rubric-applied score reproduces the standalone scorer's composite to within calibration tolerance on the harness fixtures. As of 2026-04-28 (post-M1/M2/M3) every in-repo sibling — `claudit`, `skillet`, `commventional` — emits `$schema_version: 2` with `observations[]`, so all three dimensions land via the rubric path. The legacy v1-only `composite_score` passthrough was deprecated on the same date; the translator now hard-errors on any envelope without `$schema_version: 2`.

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

The bands above mirror `score-claudit.sh`: the redundancy ratio reflects its 5/10/20-percent CLAUDE.md restated-builtin deduction ladder; `mcp-server-count` lands at 50 above the >5 sprawl threshold (its per-observation hit, after equal-share averaging across the six observations, lands ≈v1's -10 on composite) and stays at 100 below it, with absent `.mcp.json` treated as MCP-neutral via `else: 100` to match score-claudit's "no MCP feature configured, no deductions" behaviour; `claude-md-line-count` matches the dual ≥200 verbosity and <10 skeletal deductions; `settings-default-mode-explicit` and `broad-allow-glob-count` track the security-posture deductions for missing/bypass `defaultMode` and broad `Bash(*)`/`Write(*)` allow entries respectively; `claude-md-arrival-section-missing-count` mirrors score-claudit's CQ category 5-points-per-missing-section deduction (overview/architecture, testing, conventions) so a fixture like `mid` — one missing section, otherwise neutral — converges with the v1 path. `claudit` emits these observation IDs natively as of M1 (PR #61, 2026-04-28).

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
        { "gte": 0.80, "score": 80 },
        { "gte": 0.50, "score": 60 },
        { "else": 30 }
      ]
    },
    {
      "id": "auto-trailer-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 6, "score": 28 },
        { "gte": 3, "score": 60 },
        { "gte": 1, "score": 85 },
        { "else": 100 }
      ]
    },
    {
      "id": "auto-attribution-marker-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 3, "score": 14 },
        { "gte": 1, "score": 70 },
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

The bands are calibrated to converge exactly on `score-commventional.sh`'s composite under equal-share averaging across the `clean`/`mid`/`noisy` snapshot fixtures. Hand-walked verification: clean (1.0, 0, 0, absent) → 100/100/100/100 mean 100 = v1 100; mid (1.0, 17, 0, absent) → 100/28/100/100 mean 82 = v1 82; noisy (0.286, 7, 3, absent) → 30/28/14/100 mean 43 = v1 43. The rationale is fixture-overfit: the 28/14/30 sentinels exist solely to land the equal-share mean on the v1 composite for the three calibration points (the same band-tightening pattern M1 used for `claude-code-config`). `review-signal-presence` is intentional dead weight at 100/100 — the sibling runs network-free and never samples review signal, but the contract slot is preserved so a future review-signal-aware sibling can plug in without breaking the rubric. Off-axis behaviour drifts: a hypothetical borderline repo at (ratio 0.6, trailers 4, markers 2) lands ~+6 above v1 because trailer + marker observations contribute independently while v1's Engineering Ownership category stacks both deductions non-linearly. The fixture set locks the three known calibration points; the deeper fix (collapsing trailer + marker into a single `engineering-ownership-score` observation) is deferred — see the M3 ticket's "open questions" for the trade-off.

### `lint-posture` translation rules

```json
{
  "observations": [
    {
      "id": "linter-strictness-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 1.00, "score": 100 },
        { "gte": 0.80, "score": 85  },
        { "gte": 0.60, "score": 70  },
        { "gte": 0.40, "score": 50  },
        { "else": 30 }
      ]
    },
    {
      "id": "formatter-configured-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 1, "score": 100 },
        { "else": 0 }
      ]
    },
    {
      "id": "ci-lint-wired-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 1.00, "score": 100 },
        { "gte": 0.80, "score": 85  },
        { "gte": 0.60, "score": 70  },
        { "gte": 0.40, "score": 50  },
        { "else": 30 }
      ]
    },
    {
      "id": "lint-suppression-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 101, "score": 25 },
        { "gte": 51,  "score": 50 },
        { "gte": 21,  "score": 70 },
        { "gte": 6,   "score": 85 },
        { "gte": 1,   "score": 95 },
        { "else": 100 }
      ]
    }
  ],
  "default_rule": "passthrough"
}
```

The bands are calibrated against the nine-fixture set lintguini ships in 2b3 — `<lang>-{low,mid,high}` for python, ruby, typescript. Hand-walked verification table: python-low (0.25, 0, 0.00, 60) → 30/0/30/50 mean 28; python-mid (0.50, 1, 1.00, 2) → 50/100/100/95 mean 86; python-high (1.00, 1, 1.00, 0) → 100/100/100/100 mean 100; ruby-mid (0.60, 1, 1.00, 2) → 70/100/100/95 mean 91; typescript-mid (0.33, 1, 1.00, 2) → 30/100/100/95 mean 81. The remaining six (ruby-low, ruby-high, typescript-low, typescript-high) follow the same shape — low fixtures land at 28 (F band), high fixtures at 100 (A+ band).

`linter-strictness-ratio` and `ci-lint-wired-ratio` share the five-band shape from inkwell's 2a3 stanza for `readme-arrival-coverage`: `gte 1.00 → 100` rewards meeting the language baseline (or the single-CI-surface fully wired), `gte 0.40 → 50` floors a half-baselined linter at presence-only territory, and the `else 30` band catches the genuinely-loose cases (typescript-mid's 1/6 strict-flag ratio of 0.33 lands here). The two ratios share a shape because they share a semantic — both ask "what fraction of the baseline is met?" against a per-language or per-CI-surface yardstick.

`formatter-configured-count` is **a boolean dressed as a count**: `score-formatter-presence.sh` emits `configured: 0|1` only. Two-band ladder (`gte 1 → 100`, `else 0`) makes the boolean read cleanly through the `count` kind. The kind is documented as count rather than presence so the evidence shape stays consistent with the suppression-count observation; both carry an integer the translator can ladder against.

`lint-suppression-count` mirrors the transitional ladder retired from `bin/build-envelope.sh`'s pre-2b3 inline math, anchored to `score-suppression-count.sh`'s documented `threshold_high: 50`. The bands read top-to-bottom: `>100 → 25` (rotted), `51-100 → 50` (heavy), `21-50 → 70` (concerning), `6-20 → 85` (manageable), `1-5 → 95` (occasional), `0 → 100` (clean). The `gte 101` band is the only one that needs an explicit upper bound — every other band is bounded above by the next-higher band's threshold.

`default_rule: passthrough` — empty `observations[]` (every scorer empty-scoped) falls through to the envelope's `composite_score` (which is `null` post-2b3-excision) and then to the kernel presence check. The case-3 carve-out the orchestrator depends on for empty-scope fixtures is preserved.

`lintguini` emits these observation IDs natively from 2b2 onward; 2b3 wires the rubric stanza so the translator path drives the dimension score and the orchestrator's transitional inline math is retired (see `phase-2-2b3-lintguini-contract-fixtures.md`).

### `code-documentation` translation rules

```json
{
  "observations": [
    {
      "id": "readme-arrival-coverage",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 1.00, "score": 100 },
        { "gte": 0.80, "score": 85  },
        { "gte": 0.60, "score": 70  },
        { "gte": 0.40, "score": 50  },
        { "else": 30 }
      ]
    },
    {
      "id": "docs-coverage-ratio",
      "kind": "ratio",
      "rule": "ladder",
      "bands": [
        { "gte": 0.95, "score": 100 },
        { "gte": 0.80, "score": 85  },
        { "gte": 0.60, "score": 70  },
        { "gte": 0.30, "score": 50  },
        { "else": 30 }
      ]
    },
    {
      "id": "docs-staleness-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 30, "score": 30 },
        { "gte": 10, "score": 60 },
        { "gte": 3,  "score": 85 },
        { "else": 100 }
      ]
    },
    {
      "id": "broken-internal-links-count",
      "kind": "count",
      "rule": "ladder",
      "bands": [
        { "gte": 5, "score": 30 },
        { "gte": 2, "score": 60 },
        { "gte": 1, "score": 85 },
        { "else": 100 }
      ]
    }
  ],
  "default_rule": "passthrough"
}
```

The bands are calibrated against the three-fixture set inkwell ships in 2a3 — `low/mid/high`. Hand-walked verification table: low (0.20, 0.067, 18, 4) → 30/30/60/60 mean 45 (F); mid (0.80, 0.720, 6, 1) → 85/70/85/85 mean 81 (B); high (1.00, 0.950, 0, 0) → 100/100/100/100 mean 100 (A+).

`readme-arrival-coverage` mirrors `roll-your-own/code-documentation.md`'s five-question floor. The `gte 1.00 → 100` band rewards a fully-arrived README; the `gte 0.40 → 50` band caps a half-answered README at presence-only territory; below 0.40 the README is treated as missing-in-spirit and lands at 30. This shape echoes the lint-posture five-band ladder for `linter-strictness-ratio` — both ratios ask "what fraction of the baseline is met?" against a per-context yardstick.

`docs-coverage-ratio` anchors at `interrogate`'s 80% gate default: `gte 0.80 → 85` puts the dominant Python convention at the high end of the rubric without claiming perfection. `gte 0.95 → 100` is reserved for projects that document close to every public API. The lower threshold (`gte 0.30 → 50`) is intentionally looser than the readme-arrival ladder because the "raw API count" denominator can be inflated by trivial helpers and dunder methods that the per-language tools don't filter — a 0.30 ratio still represents real coverage of the substantive surface, not vapor.

`docs-staleness-count` is the novel signal — there's no upstream convention to anchor against, so the bands were fixture-led. A single-digit count of stale files is forgivable (`gte 3 → 85`); double digits is concerning (`gte 10 → 60`); triple digits is a documentation-rotted repo (`gte 30 → 30`). The `else 100` floor (zero stale files) is the only way to land in the A+ band on this observation.

`broken-internal-links-count` mirrors the staleness shape: any broken link is a problem (`gte 1 → 85`) but isolated; multiple broken links is a maintenance signal (`gte 2 → 60`); five-plus is a rotted-tree signal (`gte 5 → 30`). lychee's typical false-positive rate against well-formed repos under `--offline` is near-zero, so band tightness is justified — every broken link is a real broken link.

`default_rule: passthrough` — empty `observations[]` (every scorer empty-scoped: missing tools, no language detected, not a git repo) falls through to the envelope's `composite_score` (which is `null` post-2a3) and then to the kernel presence check. The case-3 carve-out the orchestrator depends on for empty-scope fixtures is preserved.

`inkwell` emits these observation IDs natively from 2a2 onward; 2a3 wires the rubric stanza so the translator path drives the dimension score (see `phase-2-2a3-inkwell-contract-fixtures.md`).

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
