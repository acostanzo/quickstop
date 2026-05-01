---
id: 2b2
plan: phase-2-pronto
status: open
updated: 2026-05-01
---

# 2b2 — Lintguini language detection + shell scorers

## Scope

2b1 ships the plugin scaffold with an empty `observations[]` envelope.
2b2 fills that array with four deterministic shell scorers, one per
rubric category in the `lint-posture` dimension:

1. **Linter presence + strictness** — detect the language's
   conventional linter (ruff, biome/ESLint, clippy, golangci-lint),
   parse its config, count configured rules vs the per-language
   baseline documented in `roll-your-own/lint-posture.md`. Emit a
   ratio observation.
2. **Formatter presence** — detect the language's conventional
   formatter (ruff format, biome format, prettier, rustfmt, gofmt).
   Boolean-ish: configured = 0 or 1. Emit a count observation.
3. **CI lint wiring** — grep `.github/workflows/*.yml`,
   `.gitlab-ci.yml`, `.circleci/config.yml`, `Makefile` for lint
   invocations. One boolean per detected CI surface; emit a ratio
   over surfaces-with-lint / surfaces-detected.
4. **Suppression count** — count `eslint-disable*` / `# noqa` /
   `// nolint` / `#[allow(...)]` / `# type: ignore` markers across
   source files. Per-language dispatch. Emit a count observation
   with a documented threshold ladder for "high suppression".

Mechanical pattern matches Phase 1.5 PR 3b (`score-claudit.sh`,
`score-skillet.sh`, `score-commventional.sh`) and the Phase 2 2a2
inkwell shape — same filesystem produces the same JSON bytes every
run. The bait-and-switch case the rubric calls out (eslint config
present + zero CI gate + 200 `eslint-disable` comments) is **not** a
fifth scorer; it falls out of the four scorers' composite naturally
(high suppression count + low CI-lint-wired + present linter config
= a low composite).

The four scorers are network-free, language-toolchain-free (pure
shell + grep + awk + jq, no `ruff` / `biome` / `golangci-lint`
binaries on PATH required), and ADR-006 conformant — `Read` / `Glob`
/ `Grep` / `Bash` only, no host-state writes.

## Architecture

### Scorer file layout

```
plugins/lintguini/scorers/
├── _common.sh                    # shared helpers (language detection, ratio formatter)
├── score-linter-presence.sh
├── score-formatter-presence.sh
├── score-ci-lint-wired.sh
├── score-suppression-count.sh
└── tests/
    ├── fixtures/                 # per-scorer unit-test fixtures
    │   ├── linter-presence/{python-strict,python-loose,js-biome,rust,go,empty}/
    │   ├── formatter-presence/{python,js,go,rust,absent,empty}/
    │   ├── ci-lint-wired/{github-wired,github-bare,multi-surface,no-ci,empty}/
    │   └── suppression-count/{python-clean,python-noisy,js-bait,go,empty}/
    ├── linter-presence.test.sh
    ├── formatter-presence.test.sh
    ├── ci-lint-wired.test.sh
    ├── suppression-count.test.sh
    ├── end-to-end.test.sh         # the lifted 2b1 smoke
    └── run-all.sh
plugins/lintguini/bin/
└── build-envelope.sh              # orchestrator: composes 4 scorers → v2 envelope
plugins/lintguini/skills/audit/SKILL.md  # updated to invoke build-envelope.sh
```

These unit-test fixtures live alongside the scorers and are isolated
to the scorer they exercise. They are **distinct from 2b3's
dimension-level multi-language calibration set** under
`plugins/lintguini/tests/fixtures/`, which exercises the full audit
envelope across all four scorers at once and underwrites the
variance / grade-flip acceptance bar. Different purposes; both are
needed.

Scripts live under `plugins/lintguini/scorers/` (parallel to pronto's
`plugins/pronto/agents/parsers/scorers/` and inkwell's
`plugins/inkwell/scorers/`). Each scorer accepts a single
`<REPO_ROOT>` argument, exits 0 on success / 2 on usage errors, and
emits a single observation entry as a one-line JSON object on stdout
ready to be `jq -s`'d into the envelope by `build-envelope.sh`.

### Observation IDs, kinds, evidence shapes

| Observation ID | Kind | Source | Evidence shape |
|---|---|---|---|
| `linter-strictness-ratio` | ratio | per-language tool config inspection | `{language, configured_rules: N, baseline_rules: M, ratio: N/M}` |
| `formatter-configured-count` | count | formatter config presence | `{language, configured: 0 \| 1}` |
| `ci-lint-wired-ratio` | ratio | CI surface grep | `{ci_surfaces_detected: N, ci_surfaces_with_lint: M, ratio: M/N}` |
| `lint-suppression-count` | count | per-language suppression-marker grep | `{language, suppressions: N, files_scanned: M, threshold_high: 50}` |

All evidence numbers are integers (counts) or 4-decimal-place ratios.
No floats with hidden precision drift across machines. Empty-scope
short-circuit pattern from `score-skillet.sh` and 2a2: if a scorer's
input domain is empty (no detected language, no CI surfaces, no
source files), the observation is omitted from the envelope rather
than emitted with `ratio: 0` — empty input is "no scope" not
"failed". The translator already handles missing observations via
case-3 passthrough.

### `score-linter-presence.sh`

Detects the repo's primary language (by config-file presence:
`pyproject.toml` → python, `package.json` → js/ts, `Cargo.toml` →
rust, `go.mod` → go) and dispatches:

| Language | Linter detected via | Configured rules counted from |
|---|---|---|
| python | `[tool.ruff.lint]` table in `pyproject.toml`, OR `.flake8`, OR `[tool.flake8]` | `select` array length (ruff) or fallthrough to `1` for flake8 presence |
| js / ts | `biome.json` `linter.rules` block, OR `.eslintrc*` `rules` block | count of rule keys |
| rust | `[lints.clippy]` table in `Cargo.toml` | count of rule keys |
| go | `.golangci.yml` `linters.enable` array | array length |

Baseline counts come from `roll-your-own/lint-posture.md` "Minimum
viable setup by language":

| Language | Baseline |
|---|---|
| python | 8 (ruff `["E","F","I","N","UP","B","SIM","RUF"]`) |
| js / ts | 1 (biome `recommended: true`) |
| rust | 2 (`unsafe_code`, `pedantic`) |
| go | 6 (errcheck, gosimple, govet, ineffassign, staticcheck, unused) |

Ratio = configured / baseline, clamped to [0.0, 1.0]. A repo whose
config exceeds the baseline gets 1.0 (over-strictness isn't penalised
or rewarded — the baseline is a floor, not a target). Linter absent
but config-file present: ratio = 0.0. Config-file absent: observation
omitted.

Emits:

```json
{"id": "linter-strictness-ratio", "kind": "ratio",
 "evidence": {"language": "python", "configured_rules": 8, "baseline_rules": 8, "ratio": 1.0000},
 "summary": "8/8 baseline ruff rules configured (python)"}
```

### `score-formatter-presence.sh`

Detects primary language (same dispatch as linter scorer) and
checks for the language's conventional formatter config:

| Language | Formatter check |
|---|---|
| python | `[tool.ruff.format]` block in `pyproject.toml`, OR `[tool.black]` block, OR top-level `.black.toml` |
| js / ts | `biome.json` `formatter.enabled: true`, OR `.prettierrc*` |
| rust | `rustfmt.toml`, OR `.rustfmt.toml`, OR `[tool.rustfmt]` block in `Cargo.toml` |
| go | `gofmt` is implicit in Go toolchain — pass if `go.mod` exists (gofmt is the default; no opt-out config required) |

Configured = 1 if any check passes, 0 otherwise. Empty-scope
short-circuit applies if no language detected.

Emits:

```json
{"id": "formatter-configured-count", "kind": "count",
 "evidence": {"language": "python", "configured": 1},
 "summary": "Formatter configured (python: ruff format)"}
```

### `score-ci-lint-wired.sh`

Walks the repo for CI surfaces and greps each for lint invocations.
Surfaces:

- `.github/workflows/*.yml` and `*.yaml` (each file = one surface)
- `.gitlab-ci.yml` (one surface)
- `.circleci/config.yml` (one surface)
- `Makefile` and `makefile` (one surface)
- `lefthook.yml` and `.lefthook.yml` and `lefthook.yaml` (one surface)
- `.pre-commit-config.yaml` (one surface)

Lint-invocation grep patterns (case-insensitive, fixed set so matches
are deterministic):

```
ruff (check|format)
biome (check|format|lint)
eslint( |$)
prettier( |--check| --write)
clippy
cargo +(fmt|clippy)
golangci-lint
gofmt
black( |--check)
flake8
```

A surface counts as "lint-wired" if any pattern matches. Ratio =
surfaces-with-lint / surfaces-detected. Empty-scope short-circuit:
if zero CI surfaces detected, observation is omitted (not "no lint
in CI" — that conflates absence-of-CI with broken-lint-in-CI).

Emits:

```json
{"id": "ci-lint-wired-ratio", "kind": "ratio",
 "evidence": {"ci_surfaces_detected": 3, "ci_surfaces_with_lint": 2, "ratio": 0.6667},
 "summary": "2/3 CI surfaces invoke a linter"}
```

### `score-suppression-count.sh`

Per-language suppression-marker grep across source files:

| Language | Suppression markers | Source-file glob |
|---|---|---|
| python | `# noqa` (with or without rule code), `# type: ignore`, `# pylint: disable` | `**/*.py` (excludes `**/.venv/`, `**/venv/`, `**/__pycache__/`) |
| js / ts | `eslint-disable`, `eslint-disable-next-line`, `eslint-disable-line`, `// @ts-ignore`, `// @ts-expect-error` | `**/*.{js,jsx,ts,tsx,mjs,cjs}` (excludes `**/node_modules/`, `**/dist/`, `**/build/`) |
| rust | `#[allow(`, `#![allow(` | `**/*.rs` (excludes `**/target/`) |
| go | `//nolint` (with or without rule code), `//lint:ignore` | `**/*.go` (excludes `**/vendor/`) |

`files_scanned` = total source files matched by the language glob
(post-exclude). `suppressions` = `grep -c` summed across those files.
`threshold_high` = 50 (documented threshold; the rubric stanza in
2b3 will lay the count→score ladder over it). Empty-scope
short-circuit: no source files of detected language → observation
omitted.

Emits:

```json
{"id": "lint-suppression-count", "kind": "count",
 "evidence": {"language": "javascript", "suppressions": 47, "files_scanned": 312, "threshold_high": 50},
 "summary": "47 suppression markers across 312 source files (javascript)"}
```

### Initial within-dimension weights

Per `phase-2-pronto.md`'s 2b section: composite across (a) linter
present + configured, (b) formatter present + configured, (c) CI
runs lint, (d) suppression count. Equal quarters across the four
categories until 2b3 fixtures calibrate. Translates to equal-share
averaging across the four observations under the H4 scoring path
(no `weight` field per observation → `1/n` weighting). Rebalanced
after 2b3 fixtures calibrate, if any signal proves dominant or dead.

## Deviation from 2a2 (canonical pattern)

The 2a2 inkwell ticket explicitly defers SKILL.md envelope-wiring
and the orchestrator-level envelope build to 2a3:

> **No changes to `plugins/inkwell/skills/audit/SKILL.md` in 2a2.**
> The skill keeps emitting the empty envelope. 2a3 wires the scorers
> into the envelope-build step.

2b2 deviates: the SKILL.md update and the orchestrator script ship
in 2b2 alongside the scorers. The deviation is justified by 2b1's
PR test plan, which deferred the `/lintguini:audit --json` smoke
(and the `/hone lintguini` Pronto Compliance check) to 2b2:

> - [ ] `/lintguini:audit --json` smoke — deferred to 2b2 (envelope
>       template returns empty `observations[]`; case-3 passthrough)
> - [ ] `/hone lintguini` Pronto Compliance ≥85 — deferred until
>       scorers land (2b2)

To honour those commitments, 2b2 ships:

1. `bin/build-envelope.sh` — orchestrator that runs the four scorers,
   `jq -s`'s their outputs into `observations[]`, and emits a v2
   envelope with a **transitional** `composite_score` (equal-share
   mean of per-observation translation rules; replaced in 2b3 by
   the rubric-stanza math). The transitional rule set is documented
   inline in `build-envelope.sh` so the 2b3 hand-off is mechanical:
   delete the inline math, point at the rubric stanza, done.
2. SKILL.md updated to invoke `build-envelope.sh` and emit its
   stdout. The model's job collapses to "run this script, paste its
   output" — minimum room for non-determinism.
3. `tests/end-to-end.test.sh` — bash-level smoke that runs
   `build-envelope.sh` against the smallest possible fixture and
   pipes through `plugins/pronto/agents/parsers/scorers/observations-to-score.sh`.
   Asserts: `passthrough_used: true` (no rubric stanza for
   lint-posture yet), `composite_score` is numeric (transitional
   value passed through), helper exits 0.

What stays in 2b3:
- Multi-language `low/mid/high` fixture set under
  `plugins/lintguini/tests/fixtures/`.
- Rubric stanza in `plugins/pronto/references/rubric.md`.
- Variance harness ≤ 1.0 stddev / ≤ 5% grade-flip acceptance.
- Removal of the transitional composite math from `build-envelope.sh`
  (the rubric stanza becomes the authority).

The deviation is contained: scorers and per-scorer fixtures stay on
the 2a2 pattern (one observation per scorer, empty-scope
short-circuit, no LLM judgment). Only the orchestrator + smoke ship
forward.

## Implementation order

1. **`plugins/lintguini/scorers/_common.sh`** — shared helpers:
   - `format_ratio numerator denominator` — emit `0.0000`-format
     ratio or `null` on `denominator == 0`.
   - `detect_primary_language <REPO_ROOT>` — return
     `python|javascript|typescript|rust|go|none` by config-file
     precedence (`pyproject.toml` > `Cargo.toml` > `go.mod` >
     `tsconfig.json` > `package.json` > none).
   - `clamp_ratio` — bound `[0.0, 1.0]` for over-baseline cases.
2. **`plugins/lintguini/scorers/score-linter-presence.sh`** —
   per-language config inspection. Unit-test fixtures (distinct from
   2b3's dimension-level calibration set; lives under
   `plugins/lintguini/scorers/tests/fixtures/linter-presence/`):
   `python-strict` (full ruff config, ratio = 1.0), `python-loose`
   (ruff with 4 of 8 baseline rules, ratio = 0.5), `js-biome`,
   `rust`, `go`, `empty` (no language → observation omitted).
3. **`plugins/lintguini/scorers/score-formatter-presence.sh`** —
   formatter config presence check. Fixtures: one per language
   detected + formatter present, one with language detected but
   formatter absent, one empty-scope.
4. **`plugins/lintguini/scorers/score-ci-lint-wired.sh`** — CI
   surface grep. Fixtures: `github-wired` (lint in `.github/`),
   `github-bare` (CI exists but no lint), `multi-surface` (Makefile
   + `.github/`, both wired), `no-ci` (empty-scope), `empty`.
5. **`plugins/lintguini/scorers/score-suppression-count.sh`** —
   per-language grep with documented globs and excludes. Fixtures:
   `python-clean` (zero suppressions), `python-noisy` (10
   suppressions across 4 files), `js-bait` (200 `eslint-disable`
   markers — the rubric's bait-and-switch case), `go`, `empty`.
6. **`plugins/lintguini/scorers/tests/*.test.sh`** — one test
   harness per scorer plus `tests/end-to-end.test.sh`, all callable
   from `tests/run-all.sh` for one-command verification.
7. **`plugins/lintguini/bin/build-envelope.sh`** — orchestrator.
   Composes the four scorer outputs into a v2 envelope with
   transitional composite. ADR-006 conformant: only reads from
   `<REPO_ROOT>`, only writes to stdout.
8. **`plugins/lintguini/skills/audit/SKILL.md`** — update to
   instruct the model to run `bin/build-envelope.sh` and emit its
   stdout verbatim.
9. **`plugins/lintguini/scorers/tests/end-to-end.test.sh`** —
   smoke that runs `build-envelope.sh` against a tiny fixture and
   pipes through `observations-to-score.sh`.

## Acceptance

- All four scorers exit 0 on a fresh clone of the repo (which is
  itself a valid `lint-posture` target — quickstop has no language
  source tree at root, so most scorers empty-scope-omit; CI scorer
  detects `.github/` and reports its lint state).
- Each scorer's unit tests pass: byte-equivalent JSON output across
  three runs against the same fixture.
- Empty-scope branches omit the observation (no stdout pollution; no
  `ratio: 0` masquerading as a finding) and exit 0.
- `score-suppression-count.sh` correctly handles the bait-and-switch
  fixture: 200 `eslint-disable` markers in a 50-file JS repo without
  CI lint produces a high suppression count, low CI-lint-wired
  ratio, and present linter config — exactly the composite-low
  shape the rubric calls out.
- `bin/build-envelope.sh` against a tiny fixture produces a v2
  envelope with `observations[]` populated (≥1 entry, ≤4) and a
  numeric `composite_score`. JSON parses with `jq .`.
- `tests/end-to-end.test.sh` runs `build-envelope.sh` against its
  fixture, pipes stdout to `plugins/pronto/agents/parsers/scorers/observations-to-score.sh lint-posture <(stdin)`,
  and asserts: helper exits 0, output JSON has
  `passthrough_used: true` (no rubric stanza yet for `lint-posture`),
  output JSON has numeric `composite_score`.
- No changes to `plugins/pronto/`, `plugins/inkwell/`, or any other
  plugin in this branch (verified via
  `git diff main..2b2-lintguini-scorers -- 'plugins/!(lintguini)/'`
  showing zero output).

## Three load-bearing invariants

A. **Every scorer is reproducible.** Same filesystem state →
byte-identical JSON output. Verified by triple-run on each scorer's
fixture under `tests/*.test.sh`.

B. **No language toolchain required.** Pure shell + grep + awk + jq.
No `ruff` / `biome` / `golangci-lint` / `cargo` / `go` binaries on
PATH. This is a deliberate departure from 2a2's docs-coverage
scorer, which dispatches to language tools (interrogate, eslint,
revive, cargo doc). Lint-posture's signals are extractable from
config files alone — full toolchain dispatch would buy precision at
the cost of CI portability and would re-introduce the
tool-absent-omit branch 2a2 had to ship explicitly. 2b2 sidesteps
the whole concern by reading config rather than running tools.

C. **Scorers are network-free and host-state-free.** No scorer hits
a remote, writes to `~/.claude/`, mutates the consumer's repo, or
depends on the host's installed plugin set. Verified by running the
scorer suite under `unshare -n` on Linux (or BSD equivalent on
macOS CI). ADR-006 §2 / §3 invariants hold at scorer level.

## ADR-006 conformance

Per ADR-006 §2 (no silent mutation of consumer artefacts) and §3
(hook invariants — vacuously satisfied since lintguini ships no
hooks), the scorers operate strictly read-only on `<REPO_ROOT>`:
- Allowed tools: `Read`, `Glob`, `Grep`, `Bash` (matches the
  SKILL.md frontmatter declaration from 2b1).
- No writes outside the scorers' own scratch tempfiles (which live
  under `mktemp -t` and are cleaned by `trap`).
- No reads outside `<REPO_ROOT>` except for the scorer scripts
  themselves and their `_common.sh`. No `~/.claude/` reads, no host
  config reads.
- The orchestrator (`bin/build-envelope.sh`) inherits the same
  posture and explicitly does not write any state outside stdout
  and tempfiles.

This scorer-level non-mutation posture is documented at the top of
`_common.sh` and reiterated in `build-envelope.sh`'s header.

## Out of scope

- **Multi-language aggregation.** Each scorer reports against the
  primary detected language. A polyglot repo (e.g. JS frontend +
  Python backend) gets one observation per scorer, scoped to the
  highest-priority detected language. Multi-language emission (one
  observation per detected language with aggregation in
  `build-envelope.sh`) is a follow-up — call sites that need
  per-language breakdown are unconvinced enough today to defer.
- **Rubric stanza in `rubric.md`.** Filed as 2b3 — calibrated
  against the multi-language fixture set.
- **Multi-language `low/mid/high` fixture set.** Filed as 2b3.
- **Variance harness ≤ 1.0 stddev / ≤ 5% grade-flip acceptance.**
  Filed as 2b3.
- **Updating `recommendations.json`** beyond what 2b1 already
  carries. Filed as 2b3.
- **Per-rule strictness scoring** (e.g. "ruff has `B`, `SIM`, `RUF`
  but missing `E`"). 2b2 counts configured-rule cardinality only.
  Per-rule depth is a follow-up if 2b3 fixtures show the cardinality
  signal undershoots.
- **Strictness scoring for ESLint legacy / non-Biome configs.** ESLint
  config can live in `.eslintrc.{js,json,yml}` or `package.json`
  `eslintConfig` block; 2b2 detects presence (single rule = baseline
  passed) but does not parse rule-block depth. Biome is the modern
  default per the roll-your-own doc; ESLint deep-parse is a 2b3
  judgment call.
- **Native `--json` adoption.** The transitional parser agent
  `plugins/lintguini/agents/parse-lintguini.md` (shipped in 2b1)
  remains the parser-agent step-2 fallback per ADR-005 §5; native
  `--json` retirement is a separate per-sibling work cycle.

## References

- `project/plans/active/phase-2-pronto.md` — PR 2b 2b2 paragraph.
- `project/tickets/open/phase-2-2a2-inkwell-scorers.md` — the
  canonical 2a2 pattern. 2b2 mirrors layout, observation table,
  empty-scope short-circuit, and per-scorer test convention; the
  SKILL.md / orchestrator deviation is documented above.
- 2b1 PR (#73) — the dogfood that produced this scaffold and
  deferred the `/lintguini:audit --json` smoke to 2b2.
- `plugins/pronto/references/rubric.md` `lint-posture` row — weight
  15, four composite categories.
- `plugins/pronto/references/roll-your-own/lint-posture.md` —
  per-language config patterns and baseline rule sets these scorers
  read against.
- `plugins/pronto/references/sibling-audit-contract.md` § `observations[]`
  entry — the shape each scorer's output is shaped to slot into.
- `plugins/pronto/agents/parsers/scorers/score-skillet.sh` — the
  reference shape for empty-scope short-circuit and the v2 envelope
  construction these scorers feed.
- `plugins/pronto/agents/parsers/scorers/score-claudit.sh` — the
  reference shape for shell + grep + jq scoring without LLM
  judgment.
- `plugins/pronto/agents/parsers/scorers/observations-to-score.sh` —
  the helper the end-to-end smoke pipes through; case-3 passthrough
  branch is the verified path in 2b2.
- ADR-005 §1 / §3 — `:audit` skill convention and observations[]
  payload spec.
- ADR-006 §2 / §3 — non-mutation declaration and hook invariants
  (vacuously satisfied).
