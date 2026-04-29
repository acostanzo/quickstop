---
id: 2a2
plan: phase-2-pronto
status: open
updated: 2026-04-28
---

# 2a2 — Inkwell shell scorers

## Scope

2a1 ships the plugin scaffold with an empty `observations[]`. 2a2
fills that array with four deterministic shell scorers, one per
rubric category in the `code-documentation` dimension:

1. **README quality** — section presence + arrival-question coverage
   against the README skeleton documented in
   `roll-your-own/code-documentation.md`.
2. **Docs coverage** — public-API documentation density per
   detected language. Per-language tool dispatch (interrogate for
   Python, eslint-plugin-jsdoc for JS/TS, revive for Go,
   `cargo doc --show-coverage` for Rust). 80% gate as the reach
   threshold (interrogate's dominant convention).
3. **Staleness** — files in source trees modified since the
   last documentation touch. A novel signal — there's no
   widely-adopted convention to anchor against, so this scorer's
   calibration is fixture-led rather than convention-led.
4. **Internal link health** — `lychee --offline` over the README
   and `docs/` tree, counting broken internal links and broken
   anchor fragments. Network-free by design.

Mechanical pattern matches Phase 1.5 PR 3b (`score-claudit.sh`,
`score-skillet.sh`, `score-commventional.sh`) — same filesystem
produces the same JSON bytes every run.

The scorers are wired into the `:audit` skill's envelope-build step
in 2a3. 2a2 lands the four scorer scripts plus their
unit-test fixtures; the audit skill keeps emitting the empty
envelope until 2a3 flips it to populated.

## Architecture

### Scorer file layout

```
plugins/inkwell/scorers/
├── _common.sh                # shared helpers (jq null guards, ratio formatter)
├── score-readme-quality.sh
├── score-docs-coverage.sh
├── score-doc-staleness.sh
├── score-link-health.sh
└── tests/
    ├── fixtures/             # per-scorer unit-test fixtures
    │   ├── readme/{full,partial,bare}/
    │   ├── docs-coverage/{python,...}/
    │   ├── staleness/<git-init repo>/
    │   └── link-health/<vendored-broken-link tree>/
    ├── readme-quality.test.sh
    ├── docs-coverage.test.sh
    ├── doc-staleness.test.sh
    └── link-health.test.sh
```

These unit-test fixtures live alongside the scorers and are
isolated to the scorer they exercise. They are **distinct from
2a3's dimension-level `low/mid/high` calibration set** under
`plugins/inkwell/tests/fixtures/`, which exercises the full
audit envelope across all four scorers at once. Different
purposes; both are needed.

Scripts live under `plugins/inkwell/scorers/` (parallel to pronto's
`plugins/pronto/agents/parsers/scorers/`). Each accepts a single
`<REPO_ROOT>` argument, exits 0 on success / 2 on usage errors, and
emits a single observation entry as a one-line JSON object on stdout
ready to be `jq -s`'d into the audit envelope by 2a3.

### Observation IDs, kinds, evidence shapes

| Observation ID | Kind | Source | Evidence shape |
|---|---|---|---|
| `readme-arrival-coverage` | ratio | header presence in `README.md` | `{matched: N, expected: 5, ratio: 0.0–1.0}` |
| `docs-coverage-ratio` | ratio | per-language tool stdout | `{language, documented: N, total: M, ratio: N/M}` |
| `docs-staleness-count` | count | mtime walk over src vs docs | `{stale_files: N, threshold_days: 90}` |
| `broken-internal-links-count` | count | lychee `--offline` JSON | `{broken: N, scanned: M}` |

All evidence numbers are integers (counts) or 4-decimal-place ratios.
No floats with hidden precision drift across machines. Empty-scope
short-circuit pattern from `score-skillet.sh`: if a scorer's input
domain is empty (no README, no docs/, no source files in a
detected language), the observation is omitted from the envelope
rather than emitted with `ratio: 0` — empty input is "no scope" not
"failed". The translator already handles missing observations via
case-3 passthrough.

### `score-readme-quality.sh`

Reads `README.md` at repo root. Checks for the five
arrival-question headers from `roll-your-own/code-documentation.md`
section "What 'good' looks like":

1. What does this project do? (loose match: any of the first
   non-blank line after `# <project>`, an `## About` section, or
   the project description in `## <project>`'s body)
2. Who is it for? (loose match: `## (Users?|Audience|For)`)
3. How do I install / run it? (loose match:
   `## (Install|Setup|Quickstart|Usage|Getting Started)`)
4. What's the status? (loose match: `## (Status|Project Status)` or
   a status badge line)
5. Where do I go next? (loose match: `## (Docs?|Documentation|See Also|Next)` or a `[docs/](...)` link)

Loose matching uses case-insensitive section-header regex. The
"loose" framing matters — README layouts vary widely and a strict
header-match scorer rejects perfectly clear documentation just
because the section is titled `## Quick Start` instead of
`## Install`. The acceptance bar (2a3 fixtures) verifies the
loose match doesn't false-positive on the `low` fixture's
README-shaped-but-empty marketing page.

Emits:

```json
{"id": "readme-arrival-coverage", "kind": "ratio",
 "evidence": {"matched": 4, "expected": 5, "ratio": 0.8000},
 "summary": "4/5 README arrival questions covered"}
```

### `score-docs-coverage.sh`

Detects the repo's primary language by file count under expected
source directories (`src/`, `lib/`, top-level `*.py`/`*.js`/`*.go`/
`*.rs` files). Dispatches to the language-appropriate tool:

| Language detector | Tool | Invocation |
|---|---|---|
| `pyproject.toml` or `setup.py` or `*.py > 5` | `interrogate` | `interrogate -q --fail-under 0 --output cobertura -` (parse coverage %) |
| `package.json` (no `tsconfig.json`) | `eslint-plugin-jsdoc` | `eslint --rule '{"jsdoc/require-jsdoc": "error"}' --format json` (count documented vs total exports) |
| `tsconfig.json` | `eslint-plugin-jsdoc` | as above, scoped to `*.ts`/`*.tsx` |
| `go.mod` | `revive` | `revive -formatter json -config <stanza requiring exported-doc>` |
| `Cargo.toml` | `cargo doc --show-coverage` | parse rustdoc's stdout coverage line |

Tool absence is **not** an error — the scorer falls through to
"language detected, no installable tool present", omits the
observation, and routes a notice to stderr. The audit composite
degrades to the other three signals on that repo.

The 80% gate convention (interrogate's `--fail-under 80` default)
informs the rubric stanza in 2a3, not this scorer. 2a2 emits the raw
ratio; 2a3 lays the threshold ladder over it.

Emits:

```json
{"id": "docs-coverage-ratio", "kind": "ratio",
 "evidence": {"language": "python", "documented": 84, "total": 105, "ratio": 0.8000},
 "summary": "84/105 public Python APIs have docstrings (80%)"}
```

### `score-doc-staleness.sh`

Novel signal — no widely-adopted convention to anchor against.
The scorer compares two timestamps per source file:

- `src_mtime` — file's `git log -1 --format=%ct -- <file>` (last
  commit touching that file).
- `docs_mtime` — newest `git log -1 --format=%ct` across files
  under `docs/` and `README.md`.

A source file is "stale" if `src_mtime > docs_mtime + threshold`,
where `threshold` defaults to 90 days. Only counts files in
detected source directories — vendored code, test fixtures, and
generated files are excluded by sticking to `src/` + `lib/` paths
plus top-level language files.

The 90-day threshold is a starting point. 2a3's fixture calibration
will exercise the count under different staleness shapes and may
refine; if a different anchor turns up during fixture calibration
(e.g. "no source file modified more than N commits since the
last docs touch"), this scorer changes shape, and that's expected.

Why it's novel: docs-coverage tools (interrogate, jsdoc, etc.) and
link checkers (lychee) have ecosystem-blessed defaults. Staleness
of docs vs code does not. Treat the calibration as exploratory.

Emits:

```json
{"id": "docs-staleness-count", "kind": "count",
 "evidence": {"stale_files": 12, "threshold_days": 90, "total_source_files": 87},
 "summary": "12/87 source files modified more than 90 days after last docs touch"}
```

### `score-link-health.sh`

Runs `lychee --offline --format json README.md docs/` and parses
the JSON output for broken-link count plus broken-anchor count.
`--offline` skips network checks; only on-disk file targets and
within-document anchors are validated. This is intentional — a
network-aware lychee run picks up flaky external links and adds
variance the harness can't tolerate.

If `lychee` isn't installed, the scorer omits the observation and
routes a notice to stderr (same pattern as
`score-docs-coverage.sh`'s missing-tool branch).

Emits:

```json
{"id": "broken-internal-links-count", "kind": "count",
 "evidence": {"broken": 3, "scanned": 47, "anchors_broken": 1},
 "summary": "3 broken internal links + 1 broken anchor across 47 scanned"}
```

### Initial within-dimension weights

Per `phase-2-pronto.md`'s 2a section: equal quarters across the four
categories. Translates to equal-share averaging across the four
observations under the H4 scoring path (no `weight` field per
observation → `1/n` weighting). Rebalanced after 2a3 fixtures
calibrate, if any signal proves dominant or dead.

## Implementation order

1. **`plugins/inkwell/scorers/_common.sh`** — shared helpers:
   - `format_ratio numerator denominator` — emit `0.0000`-format ratio
     or `null` on `denominator == 0`.
   - `detect_language <REPO_ROOT>` — return `python|js|ts|go|rust|other`
     by source-file detection.
   - `tool_available <command>` — exit 0 if present in `PATH`,
     exit 1 with a stderr notice if absent (callers branch on
     this).
2. **`plugins/inkwell/scorers/score-readme-quality.sh`** —
   header presence with loose-match regex. Unit-test fixtures
   (distinct from 2a3's dimension-level calibration set; lives
   under `plugins/inkwell/scorers/tests/fixtures/readme/`):
   `full` README hitting all five arrival questions, `partial`
   hitting three, `bare` hitting zero. Tests verify the
   numerator/denominator/ratio evidence shape across each.
3. **`plugins/inkwell/scorers/score-link-health.sh`** —
   lychee integration. Vendored fixture with three known broken
   links + one known broken anchor; verifies count.
4. **`plugins/inkwell/scorers/score-doc-staleness.sh`** —
   git mtime walk. Test fixture: a tiny `git init` repo with two
   commits where the source file is newer than docs, verify
   stale_files count == 1.
5. **`plugins/inkwell/scorers/score-docs-coverage.sh`** —
   per-language dispatch. Test fixture: Python project with five
   functions, three with docstrings, verify ratio == 0.6000;
   matching JS/Go/Rust fixtures gated on whether the corresponding
   tool is installed in CI (skip-with-notice if not).
6. **`plugins/inkwell/scorers/tests/*.test.sh`** — one test
   harness per scorer, all callable from a top-level
   `plugins/inkwell/scorers/tests/run-all.sh` for one-command
   verification.
7. **No changes to `plugins/inkwell/skills/audit/SKILL.md` in
   2a2.** The skill keeps emitting the empty envelope. 2a3 wires
   the scorers into the envelope-build step.

## Acceptance

- All four scorers exit 0 on a fresh clone of the repo (which is
  itself a valid `code-documentation` target — README + docs in
  `project/`, no broken links).
- Each scorer's unit tests pass: byte-equivalent JSON output across
  three runs against the same fixture.
- Tool-absent branches route to stderr (no stdout pollution) and
  exit 0 — the absence of `interrogate` / `lychee` is not a fatal
  audit error, it's a signal-omission.
- `score-readme-quality.sh` correctly distinguishes the five
  arrival questions across the README fixtures used in 2a3
  (false-positive rate 0 on the `low` fixture's README-shaped
  marketing page).
- `score-doc-staleness.sh` produces deterministic counts on a
  fixed `git init` fixture across three runs (no
  filesystem-mtime drift; uses `git log -1 --format=%ct` not
  `stat`).
- `score-link-health.sh` produces deterministic counts on a
  vendored fixture across three runs.
- No changes to `plugins/pronto/`, `plugins/inkwell/skills/`, or
  any other plugin in this commit (verified via
  `git diff main..docs/2a-inkwell-tickets -- 'plugins/!(inkwell)/'`
  showing zero output, plus
  `git diff main..docs/2a-inkwell-tickets -- 'plugins/inkwell/!(scorers)/'`
  showing only the 2a1 commits' files).

## Three load-bearing invariants

A. **Every scorer is reproducible.** Same filesystem + same git
state → byte-identical JSON output. Verified by triple-run on each
scorer's fixture under `tests/*.test.sh`.

B. **Tool-absent doesn't fail the audit.** `interrogate`, `lychee`,
`revive`, `cargo` may or may not be on the user's machine. Missing
tools omit the observation and emit a stderr notice; the audit
proceeds with the remaining signals. Verified under
`docs-coverage.test.sh`'s "no python tooling" branch.

C. **Scorers are network-free.** `lychee --offline` skips network
checks. `score-doc-staleness.sh` uses `git log` (local). No scorer
hits a remote. Verified by running the scorer suite under
`unshare -n` (or the BSD equivalent on macOS CI). Variance from
network flakiness is the documented failure mode the H2 hardening
arc closed for the orchestrator path; the scorers must not
re-introduce it.

## Out of scope

- **Wiring scorers into the audit envelope.** Filed as 2a3.
- **Rubric stanza in `rubric.md`.** Filed as 2a3 — calibrated
  against fixtures.
- **Updating `recommendations.json`.** Filed as 2a3.
- **Per-language exhaustiveness for docs-coverage.** Python and
  JavaScript are the must-have detectors; Go and Rust are
  nice-to-have. Fixture coverage in 2a3 will exercise at least
  Python and JS; Go and Rust dispatch is wired but unverified by
  fixture until a follow-up.
- **External link health.** Network-aware lychee mode is documented
  as a future option, not exercised by 2a2's scorer.
- **README quality beyond the five arrival questions.** No section
  ordering check, no length cap, no readability score. Out of
  scope; the five-question coverage is the deliberate floor.

## References

- `project/plans/active/phase-2-pronto.md` — PR 2a 2a2 paragraph.
- `project/tickets/open/phase-2-2a1-inkwell-scaffold.md` — the
  scaffold these scorers slot into.
- `plugins/pronto/references/roll-your-own/code-documentation.md` —
  defines the depth signals these scorers operationalize (README
  arrival questions, docs/ layout, staleness checklist).
- `plugins/pronto/agents/parsers/scorers/score-skillet.sh` — the
  reference shape for empty-scope short-circuit and the v2
  envelope construction these scorers feed.
- `plugins/pronto/agents/parsers/scorers/score-commventional.sh` —
  the reference shape for thin-history-style gating that
  `score-doc-staleness.sh` mirrors (omit observation rather than
  emit a misleading zero).
- `plugins/pronto/references/sibling-audit-contract.md` §
  observations[] entry — the shape each scorer's output is shaped
  to slot into.
- `interrogate` (https://interrogate.readthedocs.io/) — Python
  docstring-coverage tool, dominant convention with `--fail-under 80`
  default.
- `lychee` (https://github.com/lycheeverse/lychee) — link checker;
  `--offline` mode for in-tree-only validation.
- `eslint-plugin-jsdoc`, `revive`, `cargo doc --show-coverage` —
  per-language docs-coverage tools.
