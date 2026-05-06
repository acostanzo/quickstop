---
phase: 2
status: done
tickets: [t1, t2, t3, t4, t5]
updated: 2026-05-06
---

# Lintguini expansion — from auditor to full lint toolkit

## The role in one paragraph

Expand the `lintguini` plugin from a Pronto-sibling auditor into a full lint toolkit — configure, lint, format, fix — while keeping the existing audit surface intact. Lintguini becomes to consumer repos what avanti is to `project/`: the plugin that owns lint-posture end-to-end, in shapes that match the per-language rubric defined at `plugins/pronto/references/roll-your-own/lint-posture.md`. Five PR-sized milestones land the new skill set, the per-language config templates, the runner/formatter/fixer surface, and conditional audit scorers that grade the toolkit's output. Scope boundary: the rubric is the authority — lintguini configures repos to meet it, never invents parallel definitions.

## The model

### Lint-posture voice

The rubric at `plugins/pronto/references/roll-your-own/lint-posture.md` is the authority for what "good lint posture" means per language. Configurations lintguini writes match the rubric's per-language baselines; the strictness flags `--strict | --lenient | --minimal` are bounded variations *within* a rubric-defined band, never extensions of it. If a new language or strictness level is wanted, it lands in the rubric first; lintguini's templates are mechanical projections of the rubric, not parallel definitions. The contract between rubric and templates is pinned in ADR-008.

What this implies for *how* templates are written:

- **Conventional file shapes only.** Ruff config in `pyproject.toml`, biome in `biome.json`, prettier in `.prettierrc`, eslint in `eslint.config.*`, rustfmt in `rustfmt.toml`, rubocop in `.rubocop.yml`. No invented file shapes; embrace existing tool conventions.
- **Idempotent.** Running `/lintguini:configure` twice on a config'd repo is a no-op. Reading rubric strictness, writing matching config, running again writes the same content.
- **Self-describing.** The first comment in any generated config notes that lintguini wrote it and points at the rubric reference. A future author touching the file must know where the source of truth lives.
- **No silent rewrites.** If a config already exists and diverges from the rubric, configure surfaces the diff and asks before overwriting.

### Configuration model

Lintguini writes config to the consumer's repo using the conventional path for each language and tool. There is no lintguini-owned config shape — the plugin meets each ecosystem on the ecosystem's terms.

| Language | Linter config path | Formatter config path | Source of truth |
|---|---|---|---|
| Python | `pyproject.toml` (`[tool.ruff]`, `[tool.ruff.lint]`) | `pyproject.toml` (`[tool.ruff.format]`) | Rubric §"Python" |
| JavaScript / TypeScript | `biome.json` (default) or `eslint.config.*` + `.prettierrc` | same file | Rubric §"TypeScript / JavaScript" |
| Rust | `Cargo.toml` (`[lints.rust]`, `[lints.clippy]`) | `rustfmt.toml` | Rubric §"Rust" |
| Ruby | `.rubocop.yml` (default) or `standard.yml` | same file (rubocop autocorrect) | Rubric §"Ruby" |
| Go | `.golangci.yml` | `gofmt` (no config file) | Rubric §"Go" |

Strictness flags map to bands within each rubric section:

- `--strict` — the rubric's strict baseline. The default. What pronto's audit grades against.
- `--lenient` — the rubric's loose baseline (e.g., for legacy repos still moving toward strict).
- `--minimal` — presence-only configuration. Linter and formatter are wired but with the smallest opinion footprint that still satisfies pronto's presence check.

### Skill set (final)

| Skill | Purpose |
|---|---|
| `/lintguini:audit` | Existing. Surface unchanged. Stays deterministic — pure shell + grep + awk + jq, no consumer-state mutation. Gains conditional scorers in M5. |
| `/lintguini:configure <language?>` | Detect language(s) in the repo; install or upgrade lint/format config to match the rubric. Flags: `--language <lang>` to scope, `--strict`/`--lenient`/`--minimal` to pick the strictness band, `--ci` to also wire a lint step into the detected CI surface. Idempotent. |
| `/lintguini:lint [--language <lang>]` | Run the configured linter(s) and emit structured findings (`path:line:rule:message` shape so downstream tooling can consume). Empty-scope cleanly when nothing is configured. |
| `/lintguini:format [--language <lang>] [--check]` | Run the configured formatter(s). `--check` reports diffs without writing and exits non-zero when diffs exist (CI-friendly); default applies them. |
| `/lintguini:fix [--language <lang>]` | Wrap the linter/formatter's auto-fix mode. `--apply` performs safe fixes (formatting, import sort, trivial rule auto-fixes). `--apply-semantic` emits a unified diff for rule-violations that could change behaviour, without writing — mirrors `/inkwell:tidy`'s mechanical-vs-semantic split. |

### CI wiring

When `/lintguini:configure --ci` is invoked, lintguini detects the consumer's CI surface and adds a lint step. The detection set mirrors `score-ci-lint-wired.sh` (already enumerated in scorers): `.github/workflows/*.yml`, `.gitlab-ci.yml`, `Makefile`, `lefthook.yml`, `.pre-commit-config.yaml`.

If multiple surfaces exist, lintguini targets the most-conventional one for the language (GitHub Actions for most repos). The rule of thumb: where would a new contributor expect the lint step to live? That's the surface lintguini writes to.

CI wiring is opt-in. Without `--ci`, configure writes only the local config and leaves CI alone — repos that prefer to wire CI by hand keep that ergonomics.

### Bin layout (post-M5)

```
plugins/lintguini/
├── bin/
│   ├── build-envelope.sh                # existing — audit orchestrator
│   ├── lintguini-detect-language.sh     # M1 — shared detection
│   ├── lintguini-configure.sh           # M2 — config authoring
│   ├── lintguini-lint.sh                # M3 — linter dispatch
│   ├── lintguini-format.sh              # M3 — formatter dispatch
│   └── lintguini-fix.sh                 # M4 — auto-fix dispatch
├── references/
│   └── thresholds.json                  # M5 — shared knobs (mirror inkwell)
├── templates/
│   ├── python/                          # M1 — per-language canonical configs
│   │   ├── pyproject.toml.template
│   │   └── ...
│   ├── javascript/
│   ├── typescript/
│   ├── rust/
│   ├── ruby/
│   └── go/
├── scorers/                             # existing 4 + M5's conditionals
│   ├── _common.sh                       # M1 — shared language detection
│   ├── score-linter-presence.sh
│   ├── score-formatter-presence.sh
│   ├── score-ci-lint-wired.sh
│   ├── score-suppression-count.sh
│   ├── score-lint-pass-rate.sh          # M5 — new conditional
│   └── score-suppression-staleness.sh   # M5 — new conditional (stretch)
├── skills/
│   ├── audit/                           # existing
│   ├── configure/                       # M2
│   ├── lint/                            # M3
│   ├── format/                          # M3
│   └── fix/                             # M4
```

### What gets deleted

- `plugins/lintguini/agents/parse-lintguini.md` — the deprecated transitional agent.
- The matching `parser_agent` entry in `plugins/pronto/references/recommendations.json` is already `null` for the `lint-posture` dimension; verify and leave alone if so.
- Any references to `parse-lintguini` in lintguini's README or pronto's docs.

This is its own atomic commit early in the M1 milestone — clears the deck before the new surface lands. Mirrors the pattern from inkwell-expansion T1's `parse-inkwell` strip.

## Tickets

### T1 — Foundations + parse-lintguini removal

Land the M1 foundations: per-language config templates under `plugins/lintguini/templates/` (one subdir per supported language: `python/`, `javascript/`, `typescript/`, `rust/`, `ruby/`, `go/`), each holding the canonical config file(s) for that ecosystem with strict/lenient/minimal variants derived from the rubric. Extract the shared language-detection logic that today lives across the four scorers into `bin/lintguini-detect-language.sh` (callable) and `scorers/_common.sh` (sourceable). Update lintguini's README to describe the new toolkit shape at the high level — full README rewrite is deferred until after M3 lands the writer/runner surface, since the README has nothing concrete to describe before then; M1's delta is scoped to the role-paragraph and the toolkit list. In the same milestone (separate atomic commit), delete `plugins/lintguini/agents/parse-lintguini.md`, strip any `parse-lintguini` references from lintguini's README and pronto's docs, and verify `plugins/pronto/references/recommendations.json` (the `lint-posture` entry already carries `parser_agent: null` — confirm and move on).

**Acceptance:** all six language template directories exist with rubric-aligned strict/lenient/minimal config variants; `bin/lintguini-detect-language.sh` returns the detected language(s) for a fixture repo; `scorers/_common.sh` exists and is sourced by all four existing scorers without behaviour change (envelope output unchanged on existing fixtures); `agents/parse-lintguini.md` is gone; `grep -r 'parse-lintguini' plugins/` returns zero hits in shipped plugin files; `recommendations.json` parses as valid JSON and the `lint-posture.parser_agent` field reads `null`.

### T2 — `/lintguini:configure`

Skill `plugins/lintguini/skills/configure/SKILL.md` plus `bin/lintguini-configure.sh`. Detects language(s) via the M1 helper, picks the strictness band per `--strict` / `--lenient` / `--minimal` (default `--strict`), and writes config files using the conventional shape per tool (ruff in `pyproject.toml`, biome in `biome.json`, etc.). The first non-blank line of every generated config is a self-describing comment: "Generated by lintguini — see plugins/pronto/references/roll-your-own/lint-posture.md for the source of truth." When config already exists and diverges from the rubric baseline, configure surfaces the diff and asks before overwriting. `--ci` detects the consumer's CI surface (using the existing detection set from `score-ci-lint-wired.sh`) and adds a lint step targeting the most-conventional surface for the detected language — GitHub Actions for most repos. Idempotent — running twice on a config'd repo writes byte-equivalent output and is a no-op against the working tree.

**Acceptance:** `/lintguini:configure --language python --strict` on a fresh fixture produces a `pyproject.toml` with `[tool.ruff]` content matching the rubric's strict baseline and a self-describing leading comment; running it a second time produces no working-tree diff; `--lenient` and `--minimal` produce demonstrably-different config that still satisfies pronto's presence check; `--ci` on a repo with `.github/workflows/` adds a `lint.yml` (or appends to a conventional ci.yml) that invokes the configured linter; configure on a repo with a divergent existing config surfaces the diff rather than overwriting silently.

### T3 — `/lintguini:lint` and `/lintguini:format`

The daily-run surface — lintguini's most-frequently-invoked skill set. Skill `plugins/lintguini/skills/lint/SKILL.md` plus `bin/lintguini-lint.sh` detects the configured tools, dispatches them, and surfaces structured findings as `path:line:rule:message` (one finding per line, machine-readable so downstream tooling — including the M5 audit scorer — can consume). When no lintguini-managed config exists, lint exits 0 with an empty-scope message and a pointer to `/lintguini:configure`. Skill `plugins/lintguini/skills/format/SKILL.md` plus `bin/lintguini-format.sh` wraps the configured formatter(s); `--check` reports diffs without writing and exits non-zero when diffs exist (CI-friendly), default applies them in place. Both skills support `--language <lang>` to scope to a single language in polyglot repos.

**Acceptance:** `/lintguini:configure --language python --strict` on a fresh repo, then `/lintguini:lint` on a deliberately-broken Python file, returns at least one finding in `path:line:rule:message` shape naming the rule and line; `/lintguini:lint` on an empty-config repo prints the empty-scope message and exits 0; `/lintguini:format --check` on an unformatted file prints a diff and exits non-zero; `/lintguini:format` (no flag) on the same file rewrites it in place and exits 0; `--language ts` in a polyglot repo runs only the TypeScript tool.

### T4 — `/lintguini:fix`

Skill `plugins/lintguini/skills/fix/SKILL.md` plus `bin/lintguini-fix.sh`. The auto-fix wrapper. Three modes:

- **Default (no flag)** — read-only. Reports what `--apply` and `--apply-semantic` would do, doesn't write.
- **`--apply`** — performs safe fixes only: formatting normalization, import sort, trivial rule auto-fixes the linter's own auto-fixer flags as safe (e.g., ruff's `--fix` against `--unsafe-fixes`).
- **`--apply-semantic`** — emits a unified diff to stdout for rule-violations that could change behaviour (e.g., dead-code removal, exception-handling rewrites). Does not write to the working tree; the user reviews the diff and applies it themselves.

The mechanical-vs-semantic split mirrors `/inkwell:tidy` — semantic changes never land without human review.

**Acceptance:** `/lintguini:fix` on a fixture with mixed safe + semantic findings lists both and writes nothing; `/lintguini:fix --apply` resolves the safe findings (working tree changes verifiable via git diff) and leaves the semantic ones; `/lintguini:fix --apply-semantic` emits a unified diff for the semantic findings to stdout and does not write; `/lintguini:fix` on a clean fixture exits 0 with no findings.

### T5 — Conditional audit scorers + plan close

Land the conditional audit scorers and close the plan.

- **`scorers/score-lint-pass-rate.sh`** — runs the configured linter on the consumer repo, parses the output count of findings against the count of files linted, and emits a pass-rate observation. Gated on lintguini-config presence (detected via the M1 helper); empty-scope on non-lintguini consumers, preserving today's audit semantics.
- **`scorers/score-suppression-staleness.sh` (stretch)** — flags suppressions for rules that no longer fire. Same gating.

In the same milestone:

- Bump `plugins/lintguini/.claude-plugin/plugin.json` `version` from `0.4.1` to `0.5.0`.
- Update `.claude-plugin/marketplace.json` to match (the `source` field is required per quickstop's marketplace rules).
- Update root `README.md` to display `0.5.0`.
- Run `./scripts/check-plugin-versions.sh` to verify alignment.
- Promote the plan from `project/plans/active/` to `project/plans/done/` via `/avanti:promote plan:lintguini-expansion`.

The architectural rationale (rubric-as-authority) lives in `project/adrs/008-lintguini-rubric-authority.md`; this ticket implements its consequence — the audit's new conditional scorers grade against the rubric, not against lintguini-internal definitions.

**Acceptance:** `score-lint-pass-rate.sh` against a lintguini-configured repo with seeded findings returns a non-empty observation with a numeric pass rate; the same scorer against a non-lintguini repo emits empty-scope; the version bump is reflected in `plugin.json`, `marketplace.json`, and root `README.md`; `./scripts/check-plugin-versions.sh` exits 0; the plan promotes to `plans/done/` cleanly; ADR-008 status is `accepted`.

## Acceptance bars

Every A-bar passes on a fresh lintguini install in a fixture repo.

### A1 — Templates produce rubric-compliant configs

1. For each supported language (Python, JavaScript, TypeScript, Rust, Ruby, Go), scaffold a fixture repo that contains only the language's primary source-file marker (e.g., `*.py` for Python).
2. Run `/lintguini:configure --language <lang> --strict` on each fixture.
3. Inspect the produced config file against the rubric's strictness baseline at `plugins/pronto/references/roll-your-own/lint-posture.md`.
4. Run `/lintguini:audit` on the configured fixture and read the `linter-presence` and `formatter-presence` scorer observations.

**Pass:** for every language, the produced config matches the rubric's strict baseline (rule list, version, file shape); the audit's linter-presence and formatter-presence scorers grade the configured fixture at the rubric's strict band; running configure a second time produces no working-tree diff.

### A2 — Lint round-trip

1. `/lintguini:configure --language python --strict` on a fresh fixture.
2. Add a Python file with a deliberate lint violation (unused import + line too long).
3. `/lintguini:lint`.
4. Separately: `/lintguini:lint` on a fresh fixture with no lintguini config.

**Pass:** step 3 returns at least one finding in `path:line:rule:message` shape naming both violations and the rule that caught each; step 4 prints the empty-scope message ("no lintguini-managed config found; run /lintguini:configure to start") and exits 0.

### A3 — Format round-trip

1. `/lintguini:configure --language python --strict` on a fresh fixture.
2. Add an unformatted Python file (e.g., wrong quote style, missing trailing newline).
3. `/lintguini:format --check` and capture exit code + stdout.
4. `/lintguini:format` (no flag).

**Pass:** step 3 prints a unified diff and exits non-zero; step 4 rewrites the file in place to match the formatter's output and exits 0; running step 4 a second time exits 0 with no diff (idempotent).

### A4 — Audit unchanged on non-lintguini consumers

1. Build a fixture repo with a lintguini-managed config (call it `lintguini-marked`).
2. **Derive** a plain fixture from `lintguini-marked` at test time by stripping the self-describing comment / lintguini marker (call it `lintguini-plain`). Do not maintain `lintguini-plain` as a separate hand-edited fixture — derivation at test time is the load-bearing assertion that catches drift.
3. Run `/lintguini:audit` against both fixtures.
4. Compare the four pre-T5 scorer outputs (`linter-presence`, `formatter-presence`, `ci-lint-wired`, `suppression-count`) on `lintguini-plain` against today's 0.4.1 envelope captured in tests.

**Pass:** the four pre-T5 scorers' observations on `lintguini-plain` are byte-equivalent to the 0.4.1-captured envelope; the new T5 conditional scorers (`score-lint-pass-rate.sh`, optionally `score-suppression-staleness.sh`) emit empty-scope on `lintguini-plain` and contribute observations on `lintguini-marked`. Existing audit semantics on non-lintguini consumers are demonstrably unchanged.

### A5 — parse-lintguini removed end-to-end

1. `find plugins/lintguini/agents -type f` returns no `parse-lintguini.md`.
2. `grep -r 'parse-lintguini' plugins/` returns zero hits in shipped plugin files (excluding tests' historical fixtures, if any).
3. `plugins/pronto/references/recommendations.json` parses as valid JSON; the `lint-posture.parser_agent` field reads `null`.

**Pass:** all three checks return clean.

## Out of scope

- **Inventing strictness levels not in the rubric.** The rubric is the authority. New baselines belong in a rubric update (which lands as its own change against `plugins/pronto/references/roll-your-own/lint-posture.md`), not in lintguini's templates. Closed by ADR-008.
- **Languages outside the existing rubric coverage** (Python, JS/TS, Rust, Ruby, Go). New languages get added to the rubric first, then lintguini follows. Adding a language to lintguini without a corresponding rubric section is a violation of ADR-008.
- **IDE / editor integration** (vscode settings, eslint extensions, JetBrains config). Out of scope for v1; the toolkit targets CLI and CI only. Editor wiring is per-developer ergonomics; lintguini owns repo-level config.
- **Suppression-staleness as a non-stretch goal** — it's M5 stretch, not a required deliverable. If it doesn't land in M5, it ships as its own follow-up.
- **Vector-search / RAG over lint findings.** Not the toolkit's shape; that's inkwell's surface (per ADR-007). Lint findings are short, structured, and consumed by tooling — they don't need retrieval.
- **README full rewrite.** Held until after M3 lands — once the writer/runner surface is real, the README has something concrete to describe. The M1 README delta is scoped to the role-paragraph, the toolkit-shape one-liner, and the parse-lintguini strip; the full rewrite is its own follow-up.
- **Audit-side LLM dispatch.** The audit stays deterministic — pure shell + grep + awk + jq, no subagent dispatch in scorers. Mirrors ADR-007's audit-vs-query split for inkwell.

## Definition of done

- All T-tickets land with their own atomic conventional commits under `plugins/lintguini/` (or `plugins/pronto/` for any reference-cleanup commit).
- All A-bars pass on a fresh lintguini install in the test fixture repo.
- ADR-008 (`project/adrs/008-lintguini-rubric-authority.md`) is `accepted`.
- `plugins/lintguini/.claude-plugin/plugin.json` `version` is bumped from `0.4.1` to `0.5.0`; `.claude-plugin/marketplace.json` and root `README.md` are updated to match.
- `./scripts/check-plugin-versions.sh` exits 0.
- Existing audit semantics on non-lintguini consumers are unchanged — verified by A4.
- The plan promotes from `plans/active/` to `plans/done/` via `/avanti:promote plan:lintguini-expansion` once every ticket is closed and every A-bar passes.
