---
id: 2c2
plan: phase-2-pronto
status: open
updated: 2026-05-02
---

# 2c2 — Towncrier shell scorers (event-emission)

## Scope

2c1 ships the `:audit` skill scaffold with an empty `observations[]`.
2c2 fills that array with four deterministic shell scorers, one per
rubric category in the `event-emission` dimension:

1. **Structured-logging ratio** — per-language detection of
   structured-logger config/import vs free-form `print` /
   `console.log` / `fmt.Println` emission sites. Ratio of
   structured-emit sites vs total emission sites.
2. **Metrics instrumentation presence** — per-language detection
   of metrics-library imports + active metrics-defining call sites
   (counters, histograms, gauges). Count of metrics-defining sites
   plus a configured-or-not flag.
3. **Trace propagation** — detection of OpenTelemetry SDK setup
   plus W3C trace-header references (`traceparent` / `tracestate`)
   in request-handler files. Ratio of request-handler-shaped files
   referencing trace context vs total.
4. **Event schema consistency** — walks emission sites, extracts
   the field set per emission, counts distinct schemas, and emits
   a "well-shaped event" ratio. Catches the mixed-emission case
   the plan explicitly flags (structured logger configured, but
   half the emit sites still use free-form `console.log`).

The exact scorer count is **non-binding**. The plan-doc suggests
four (one per category above) and 2c2 ships against that suggestion;
event-emission spans more code surface than the other audit
dimensions, and during implementation a category may split (e.g.
trace propagation may want one scorer for SDK setup and a separate
one for header propagation in request handlers) or merge. If 2c2
ships fewer or more than four scorers, the rubric stanza in 2c3
calibrates against the actual shape.

Mechanical pattern matches 2a2 / 2b2 — same filesystem produces the
same JSON bytes every run. The bait-and-switch case the plan calls
out (structured-logging grep matches pass but the structured-logging
ratio scorer returns < 0.5) **falls out of the four scorers'
composite naturally**: kernel-level presence-check greps the
keyword (passes); the depth scorer counts emission-site shape
(low ratio). 2c3's fixture set includes this case explicitly.

The four scorers are network-free, language-toolchain-free (pure
shell + grep + awk + jq, no `python` / `node` / `go` / `cargo`
binaries on PATH required), and ADR-006 conformant — `Read` /
`Glob` / `Grep` / `Bash` only, no host-state writes.

## First-class languages

The scorers dispatch across **five first-class languages** matching
the depth-signal coverage in
`plugins/pronto/references/roll-your-own/event-emission.md`:

| Language | Detection signal | Notes |
|---|---|---|
| python | `pyproject.toml` or `setup.py` or `*.py > 5` | Highest precedence |
| go | `go.mod` | |
| rust | `Cargo.toml` | |
| typescript | `tsconfig.json` | Split from javascript — TS-specific OTel package names land on this dispatch path |
| javascript | `package.json` | Lowest precedence |

Languages outside this set (Crystal, Elixir, PHP, C#, Swift, Ruby,
etc.) are explicitly deferred — see "Out of scope". The first-class
set mirrors lintguini's 2b2 set with one substitution: ruby drops
out (rubocop-driven lint is real-world heavy in ruby; structured
logging / OTel less so as a ruby-shop default), and the slot is
freed for follow-up if a fixture-led need surfaces.

## Architecture

### Scorer file layout

```
plugins/towncrier/scorers/
├── _common.sh                      # shared helpers (language detection, ratio formatter, emit-site finder)
├── score-structured-logging-ratio.sh
├── score-metrics-presence.sh
├── score-trace-propagation.sh
├── score-event-schema-consistency.sh
└── tests/
    ├── fixtures/                   # per-scorer unit-test fixtures
    │   ├── structured-logging/{python-structured,python-mixed,python-freeform,ts-pino,ts-mixed,go-zerolog,go-freeform,rust-tracing,empty}/
    │   ├── metrics-presence/{python-prometheus,python-otel-metrics,python-none,ts-prom-client,go-prometheus,rust-metrics,empty}/
    │   ├── trace-propagation/{python-otel-full,python-otel-bare,ts-otel-handlers,ts-handler-no-trace,go-otel,empty}/
    │   ├── event-schema-consistency/{python-clean,python-bait,ts-mixed,empty}/
    │   └── shared/                 # shared inputs (e.g. tiny known-shape repos used across scorers)
    ├── structured-logging-ratio.test.sh
    ├── metrics-presence.test.sh
    ├── trace-propagation.test.sh
    ├── event-schema-consistency.test.sh
    └── run-all.sh
```

These unit-test fixtures live alongside the scorers and are isolated
to the scorer they exercise. They are **distinct from 2c3's
dimension-level multi-language calibration set** under
`plugins/towncrier/tests/fixtures/`, which exercises the full audit
envelope across all four scorers at once. Different purposes; both
are needed.

Scripts live under `plugins/towncrier/scorers/` (parallel to
`plugins/inkwell/scorers/` and `plugins/lintguini/scorers/`). Each
scorer accepts a single `<REPO_ROOT>` argument, exits 0 on success
/ 2 on usage errors, and emits a single observation entry as a
one-line JSON object on stdout ready to be `jq -s`'d into the
audit envelope by 2c3's orchestrator.

### Observation IDs, kinds, evidence shapes

| Observation ID | Kind | Source | Evidence shape |
|---|---|---|---|
| `structured-logging-ratio` | ratio | per-language emit-site grep | `{language, structured_sites: N, total_sites: M, ratio: N/M}` |
| `metrics-instrumentation-count` | count | per-language metrics-call grep | `{language, configured: 0 \| 1, metrics_sites: N}` |
| `trace-propagation-ratio` | ratio | per-language handler-file scan | `{language, handlers_with_trace: N, handlers_total: M, ratio: N/M}` |
| `event-schema-consistency-ratio` | ratio | per-language emit-site field-set parse | `{language, well_shaped_events: N, total_events: M, ratio: N/M, distinct_schemas: K}` |

All evidence numbers are integers (counts) or 4-decimal-place ratios.
No floats with hidden precision drift across machines. Empty-scope
short-circuit pattern from 2a2 / 2b2: if a scorer's input domain is
empty (no detected language, no emission sites in the repo), the
observation is omitted from the envelope rather than emitted with
`ratio: 0` — empty input is "no scope" not "failed". The translator
already handles missing observations via case-3 passthrough.

### `score-structured-logging-ratio.sh`

Detects the repo's primary language (per the precedence chain) and
walks source files for emission-shape patterns. Two pattern classes:

**Free-form emit patterns** (counted as `unstructured`):

| Language | Patterns |
|---|---|
| python | `\bprint\(`, `sys\.stderr\.write\(`, `sys\.stdout\.write\(` |
| typescript / javascript | `console\.(log\|error\|warn\|info\|debug)\(`, `process\.stdout\.write\(`, `process\.stderr\.write\(` |
| go | `fmt\.(Print\|Println\|Printf)\(`, `os\.Std(out\|err)\.Write\(` |
| rust | `println!\(`, `eprintln!\(`, `print!\(`, `eprint!\(` |

**Structured emit patterns** (counted as `structured`):

| Language | Patterns |
|---|---|
| python | `(?:struct\|json\|loguru)?logger?\.(info\|warning\|error\|debug\|critical)\(`, `structlog\..*\.bind\(`, `loguru\.logger\.` |
| typescript / javascript | `(?:pino\|bunyan\|winston\|log)\.(info\|warn\|error\|debug\|trace\|fatal)\(`, `logger\.` |
| go | `(?:zerolog\|zap\|logrus\|slog)\.(?:Info\|Warn\|Error\|Debug)\(`, `\.Logger\(\)\.`, `slog\.(Info\|Warn\|Error\|Debug)` |
| rust | `tracing::(info\|warn\|error\|debug\|trace)!\(`, `slog::(info\|warn\|error\|debug)!\(`, `log::(info\|warn\|error\|debug)!\(` |

Source-file glob per language matches lintguini's
`score-suppression-count.sh` — same exclude set (`**/node_modules/`,
`**/dist/`, `**/build/`, `**/.venv/`, `**/venv/`, `**/__pycache__/`,
`**/target/`, `**/vendor/`).

`structured_sites = grep -c` summed across the structured patterns;
`total_sites = structured_sites + unstructured_sites`. Ratio =
`structured_sites / total_sites`. Empty-scope: `total_sites == 0`
→ observation omitted.

A repo with import statements for a structured logger but zero
emission sites still empty-scopes — the import itself is a kernel
presence check (handled at the orchestrator level, not here).
**This is the bait-and-switch case the plan calls for**: kernel
greps for `pino` (passes); 2c2 counts emission shape and reports
ratio 0.000 if every actual emit is `console.log`.

Emits:

```json
{"id": "structured-logging-ratio", "kind": "ratio",
 "evidence": {"language": "python", "structured_sites": 47, "total_sites": 60, "ratio": 0.7833},
 "summary": "47/60 emission sites use a structured logger (python)"}
```

### `score-metrics-presence.sh`

Detects primary language and checks for both:

1. **Metrics library import / config** (boolean):

| Language | Detection patterns |
|---|---|
| python | `from prometheus_client import`, `import prometheus_client`, `from opentelemetry.metrics import`, `from statsd import`, `import datadog\b` |
| typescript / javascript | `from "prom-client"`, `from "@opentelemetry/sdk-metrics"`, `from "node-statsd"`, `from "hot-shots"`, `from "datadog-metrics"` |
| go | `prometheus/client_golang`, `go.opentelemetry.io/otel/metric`, `cactus/go-statsd-client` |
| rust | `prometheus = `, `metrics = `, `opentelemetry = ` (in `Cargo.toml` `[dependencies]`) |

2. **Metrics-defining call sites** (count):

| Language | Patterns |
|---|---|
| python | `Counter\(`, `Histogram\(`, `Gauge\(`, `Summary\(`, `meter\.create_(?:counter\|histogram\|up_down_counter)`, `statsd\.(?:incr\|gauge\|histogram)\(` |
| typescript / javascript | `new (?:Counter\|Histogram\|Gauge\|Summary)\(`, `createCounter\(`, `createHistogram\(`, `\.observe\(`, `statsd\.(?:increment\|gauge\|histogram)\(` |
| go | `prometheus\.NewCounter(?:Vec)?\(`, `prometheus\.NewHistogram(?:Vec)?\(`, `prometheus\.NewGauge(?:Vec)?\(`, `\.Float64Counter\(`, `\.Int64Histogram\(` |
| rust | `counter!\(`, `gauge!\(`, `histogram!\(`, `register_counter!\(` |

`configured` = 1 if any import detected, 0 otherwise. `metrics_sites`
= total grep count across the call-site patterns. Empty-scope:
no language detected → observation omitted. Imported but no
call sites → `configured: 1, metrics_sites: 0` (real signal — the
infra exists but isn't used).

Emits:

```json
{"id": "metrics-instrumentation-count", "kind": "count",
 "evidence": {"language": "go", "configured": 1, "metrics_sites": 12},
 "summary": "12 metrics-defining call sites (go, prometheus client configured)"}
```

### `score-trace-propagation.sh`

Detects primary language. Then:

1. **OTel SDK setup detection** (boolean precondition):

| Language | Patterns |
|---|---|
| python | `from opentelemetry import trace`, `TracerProvider\(`, `BatchSpanProcessor\(` |
| typescript / javascript | `from "@opentelemetry/sdk-trace-node"`, `from "@opentelemetry/api"`, `new NodeSDK\(`, `trace\.getTracer\(` |
| go | `go.opentelemetry.io/otel`, `otel\.GetTracerProvider\(\)`, `tracer := otel\.Tracer\(` |
| rust | `opentelemetry::global::tracer\(`, `tracing_opentelemetry::` |

2. **Request-handler-shaped file detection**:

| Language | Heuristic |
|---|---|
| python | files containing `Flask\(`, `FastAPI\(`, `@app\.(route\|get\|post\|put\|delete)`, `def view_`, `class .*View(?:Set)?\(`, `aiohttp\.web\.RouteTableDef\(\)` |
| typescript / javascript | files containing `express\(\)`, `fastify\(`, `app\.(get\|post\|put\|delete\|patch)\(`, `@Controller\(`, `Router\(\)` |
| go | files containing `http\.HandleFunc\(`, `mux\.Handle(?:Func)?\(`, `gin\.New\(`, `chi\.NewRouter\(`, `fiber\.New\(` |
| rust | files containing `axum::Router::new\(`, `actix_web::App::new\(`, `rocket::build\(`, `warp::path` |

3. **Trace context references inside handler files**:

| Language | Patterns |
|---|---|
| python | `traceparent`, `tracestate`, `trace\.get_current_span\(`, `set_attribute\(`, `tracer\.start_as_current_span\(` |
| typescript / javascript | `traceparent`, `tracestate`, `trace\.getActiveSpan\(`, `propagation\.inject\(`, `propagation\.extract\(` |
| go | `traceparent`, `tracestate`, `tracer\.Start\(`, `otelhttp\.NewHandler\(`, `propagation\.HeaderCarrier` |
| rust | `traceparent`, `tracestate`, `tracing::Span::current\(\)`, `Instrument`, `OpenTelemetryLayer` |

`handlers_total` = count of files matching the handler-shape
heuristic for the detected language. `handlers_with_trace` = count
of those files where ≥1 trace-context pattern matches. Ratio =
`handlers_with_trace / handlers_total`. Empty-scope:
`handlers_total == 0` → observation omitted (no handlers to
instrument).

Emits:

```json
{"id": "trace-propagation-ratio", "kind": "ratio",
 "evidence": {"language": "go", "handlers_with_trace": 4, "handlers_total": 6, "ratio": 0.6667},
 "summary": "4/6 request-handler files reference trace context (go)"}
```

### `score-event-schema-consistency.sh`

This scorer is the most heuristic of the four — "consistent event
shape" is structurally fuzzier than the other three signals. The
shipped scoring keeps the heuristic deterministic by reducing
"consistent" to a measurable proxy: **what fraction of structured
emission sites carry an `event` (or equivalent) field that anchors
the emission to a named domain transition**.

For each language, identify structured emission sites (reuse the
patterns from `score-structured-logging-ratio.sh`'s structured-
emit set). For each site, parse the call's first-positional or
keyword argument and check whether it includes:

- A literal-string `event` / `event_name` / `name` keyword argument,
  OR
- A dict / object literal containing `"event"` / `"name"` /
  `"type"` as a key.

Sites that match are "well-shaped events"; sites that don't are
"freeform structured emissions" (using a structured logger but
without a domain anchor).

| Language | Well-shaped indicators |
|---|---|
| python | `event=`, `event_name=`, `event_type=`, dict with `"event":` / `"name":` / `"type":` keys |
| typescript / javascript | object literal with `event:` / `name:` / `type:` keys, e.g. `log.info({ event: "order.placed", ... })` |
| go | struct field `Event:` / `Name:` / `Type:` in the call's literal-struct argument; map literal keyed `"event"` |
| rust | `event = "..."`, `event_name = "..."`, structured-field syntax in `tracing::info!(event = ...)` |

`well_shaped_events` = count of structured emission sites whose
first argument matches a well-shaped pattern. `total_events` =
total structured emission sites (output of the structured-emit
patterns from scorer 1). `distinct_schemas` = approximate count
of unique event-name strings observed in well-shaped sites
(exact extraction is per-language; deterministic via fixed-pattern
parsing).

Ratio = `well_shaped_events / total_events`. Empty-scope:
`total_events == 0` → observation omitted (no structured emissions
to assess).

Why this proxy: ADR-005 §3 / `roll-your-own/event-emission.md`'s
"What 'good' looks like" point about "events for state transitions"
boils down to *can a consumer of the log stream find the domain
event by looking at one field?*. A structured logger emitting
`{"level":"info","ts":"...","message":"some text"}` is structured
but not an event; one emitting `{"event":"order.placed","ts":"...","order_id":42}`
is. The well-shaped ratio captures that distinction without
requiring the scorer to understand domain semantics.

Emits:

```json
{"id": "event-schema-consistency-ratio", "kind": "ratio",
 "evidence": {"language": "python", "well_shaped_events": 32, "total_events": 47, "ratio": 0.6809, "distinct_schemas": 18},
 "summary": "32/47 structured emissions carry an event-anchor field (python; 18 distinct schemas)"}
```

### Initial within-dimension weights

Per `phase-2-pronto.md`'s 2c section: composite across (a) structured
logging, (b) metrics presence, (c) trace propagation, (d) event
schema consistency. Equal quarters across the four categories until
2c3 fixtures calibrate. Translates to equal-share averaging across
the four observations under the H4 scoring path (no `weight` field
per observation → `1/n` weighting). Rebalanced after 2c3 fixtures
calibrate, if any signal proves dominant or dead.

The plan-doc flags event-emission as the hardest of the three
audit siblings — expect either a larger parser per scorer or a
larger fixture surface. If during 2c2 implementation a category
splits (e.g. trace propagation into "SDK setup" + "header
propagation in handlers"), the rubric stanza in 2c3 calibrates
against five observations rather than four. The plan-doc's "four"
is non-binding; the load-bearing constraint is one observation per
distinct depth signal.

## Deviation from 2a2 / alignment with 2b2

The 2a2 inkwell ticket explicitly defers SKILL.md envelope-wiring
and the orchestrator-level envelope build to 2a3. 2b2 lintguini
deviated by lifting the orchestrator (`bin/build-envelope.sh`) and
SKILL.md update forward to satisfy a 2b1 PR test plan that
deferred the audit smoke.

2c2 follows the **2a2 pattern, not 2b2's**:

- SKILL.md stays at the 2c1 empty-envelope shape — no orchestrator
  in 2c2.
- The orchestrator (`plugins/towncrier/bin/build-envelope.sh`) and
  SKILL.md update ship in 2c3.
- 2c2's deliverable is the four scorer scripts plus their
  unit-test fixtures and per-scorer test harnesses.

The 2b2 deviation existed because lintguini's 2b1 deferred
verification gates (Pronto Compliance ≥85, audit smoke). Towncrier's
2c1 doesn't defer those gates — the empty-envelope smoke is
verified at 2c1 PR time per its acceptance bar, and Pronto
Compliance for towncrier is unaffected by scorer presence (it
audits plugin structure, not depth). So 2c2 has no carry-forward
work and the canonical 2a2 split holds.

## Implementation order

1. **`plugins/towncrier/scorers/_common.sh`** — shared helpers:
   - `format_ratio numerator denominator` — emit `0.0000`-format
     ratio or `null` on `denominator == 0`.
   - `detect_primary_language <REPO_ROOT>` — return
     `python|go|rust|typescript|javascript|none` by config-file
     precedence (`pyproject.toml` > `go.mod` > `Cargo.toml` >
     `tsconfig.json` > `package.json` > none).
   - `language_source_glob <language>` — emit the source-file glob
     plus the standard exclude set.
   - `clamp_ratio` — bound `[0.0, 1.0]`.
2. **`plugins/towncrier/scorers/score-structured-logging-ratio.sh`** —
   per-language emit-site walk. Unit-test fixtures (distinct from
   2c3's dimension-level calibration set; lives under
   `plugins/towncrier/scorers/tests/fixtures/structured-logging/`):
   `python-structured` (full structlog use, ratio = 1.0),
   `python-mixed` (3 structured + 7 print, ratio = 0.30),
   `python-freeform` (all `print()`, ratio = 0.0),
   `ts-pino` (full pino), `ts-mixed` (the bait case — pino
   imported, half emit sites are `console.log`, ratio < 0.5),
   `go-zerolog`, `go-freeform`, `rust-tracing`, `empty`
   (no language detected → observation omitted).
3. **`plugins/towncrier/scorers/score-metrics-presence.sh`** —
   per-language config + call-site detection. Fixtures: one per
   language with full prometheus / OTel-metrics setup, one with
   library imported but zero call sites, one with no metrics at
   all, one empty-scope.
4. **`plugins/towncrier/scorers/score-trace-propagation.sh`** —
   per-language SDK detection + handler-shape walk + trace-context
   grep. Fixtures: `python-otel-full` (FastAPI handlers all
   instrumented), `python-otel-bare` (SDK installed but handlers
   don't reference trace context, ratio = 0.0), `ts-otel-handlers`
   (express handlers all instrumented), `ts-handler-no-trace`
   (express handlers, no trace), `go-otel`, `empty`.
5. **`plugins/towncrier/scorers/score-event-schema-consistency.sh`** —
   per-language emit-site parse with well-shaped extraction.
   Fixtures: `python-clean` (all emissions carry `event=`),
   `python-bait` (mixed — 3 well-shaped, 7 freeform-structured,
   ratio = 0.30), `ts-mixed`, `empty`.
6. **`plugins/towncrier/scorers/tests/*.test.sh`** — one test
   harness per scorer, all callable from a top-level
   `plugins/towncrier/scorers/tests/run-all.sh` for one-command
   verification. Triple-run byte-equivalence per scorer per
   fixture.
7. **No changes to `plugins/towncrier/skills/audit/SKILL.md` in
   2c2.** The skill keeps emitting the empty envelope. 2c3 wires
   the scorers into the envelope-build step via the orchestrator.

## Acceptance

- All four scorers exit 0 on a fresh clone of the repo (which
  empty-scopes most signals — quickstop has no language source
  tree at root, so detection returns `none`; all four scorers
  empty-scope-omit and exit 0).
- Each scorer's unit tests pass: byte-equivalent JSON output across
  three runs against the same fixture.
- Empty-scope branches omit the observation (no stdout pollution;
  no `ratio: 0` masquerading as a finding) and exit 0.
- `score-structured-logging-ratio.sh` correctly detects the
  bait-and-switch fixture: `ts-mixed` with pino imported + half
  the emit sites still `console.log` produces a ratio < 0.5
  (the case the plan-doc explicitly calls for).
- `score-metrics-presence.sh` correctly distinguishes
  "imported but unused" (`configured: 1, metrics_sites: 0`) from
  "not configured at all" (omitted).
- `score-trace-propagation.sh` empty-scopes when no
  request-handler-shaped files are detected (so a CLI tool
  doesn't get falsely faulted for lacking trace propagation).
- `score-event-schema-consistency.sh` produces deterministic
  counts on the bait fixture (`python-bait`: 3 well-shaped + 7
  freeform-structured → ratio 0.30 across three runs).
- No changes to `plugins/pronto/`, `plugins/inkwell/`,
  `plugins/lintguini/`, or any other plugin in this branch
  (verified via
  `git diff main..2c2-towncrier-scorers -- 'plugins/!(towncrier)/'`
  showing zero output, plus
  `git diff main..2c2-towncrier-scorers -- 'plugins/towncrier/!(scorers)/'`
  showing only 2c1's already-merged files).

## Three load-bearing invariants

A. **Every scorer is reproducible.** Same filesystem state →
byte-identical JSON output. Verified by triple-run on each scorer's
fixture under `tests/*.test.sh`.

B. **No language toolchain required.** Pure shell + grep + awk + jq.
No `python` / `node` / `go` / `cargo` binaries on PATH. Mirrors
2b2's invariant; the depth signals for event-emission are
extractable from source-file inspection alone (imports, call-site
patterns, trace-header references). Toolchain dispatch would buy
precision at the cost of CI portability and would re-introduce
the tool-absent-omit branch 2a2 had to ship explicitly. 2c2
sidesteps the whole concern by reading source rather than running
tools.

C. **Scorers are network-free and host-state-free.** No scorer hits
a remote, writes to `~/.claude/`, mutates the consumer's repo, or
depends on the host's installed plugin set. Verified by running
the scorer suite under `unshare -n` on Linux (or BSD equivalent
on macOS CI). ADR-006 §2 / §3 invariants hold at scorer level.

## ADR-006 conformance

Per ADR-006 §2 (no silent mutation of consumer artefacts) and §3
(hook invariants — vacuously satisfied for the audit skill since
it ships no hooks; towncrier's existing hook handler from 2c1 is
unchanged and remains §3-conformant), the scorers operate strictly
read-only on `<REPO_ROOT>`:

- Allowed tools: `Read`, `Glob`, `Grep`, `Bash` (matches the
  SKILL.md frontmatter declaration from 2c1).
- No writes outside the scorers' own scratch tempfiles (which live
  under `mktemp -t` and are cleaned by `trap`).
- No reads outside `<REPO_ROOT>` except for the scorer scripts
  themselves and their `_common.sh`. No `~/.claude/` reads, no host
  config reads, no `~/.towncrier/` reads (the audit path is
  decoupled from the hook-emission path's transport config).

This scorer-level non-mutation posture is documented at the top of
`_common.sh` and reiterated in 2c3's `build-envelope.sh` header.

## Out of scope

- **Multi-language aggregation.** Each scorer reports against the
  primary detected language. A polyglot repo (e.g. JS frontend +
  Python backend) gets one observation per scorer, scoped to the
  highest-priority detected language. Multi-language emission
  (one observation per detected language with aggregation in the
  orchestrator) is a follow-up; mirrors the same posture lintguini
  took in 2b2.
- **Rubric stanza in `rubric.md`.** Filed as 2c3 — calibrated
  against the multi-language fixture set.
- **Multi-language `low/mid/high` fixture set.** Filed as 2c3.
- **Variance harness ≤ 1.0 stddev / ≤ 5% grade-flip acceptance.**
  Filed as 2c3 (with the snapshots-triple-run deviation from the
  per-fixture N=10 brief, mirroring 2a3 / 2b3).
- **Orchestrator script and SKILL.md envelope-wiring.** Filed as
  2c3, mirroring 2a2's deferral.
- **Updating `recommendations.json`** beyond what 2c1 already
  carries. Filed as 2c3.
- **Per-rule depth scoring** (e.g. "OTel SDK is configured but
  the exporter points at localhost"). 2c2 detects presence and
  call-site cardinality only. Per-rule depth is a follow-up if
  2c3 fixtures show the cardinality signal undershoots.
- **Languages outside the first-class set.** Ruby, Crystal, Elixir,
  PHP, C#, Swift, Kotlin, Scala, Haskell, etc. — none have
  detection, dispatch, or fixtures in 2c2. Adding any of them is
  its own scoped decision sequenced with the 2c3 calibration
  harness if the need is real, not a 2c2 follow-up. Ruby is the
  most plausible add (real-world ruby shops use OTel + structlog
  patterns), but no in-tree fixture demands it today.
- **External-link / network-aware metrics scoring.** No scorer
  reaches out to a remote — pure source inspection only.
- **PII-mask detection.** `roll-your-own/event-emission.md`
  enumerates "sensitive data masked at emission" as a depth signal,
  but mechanizing it deterministically (without false positives on
  legitimate field names like `email_template_id`) is fixture-led
  work that hasn't been scoped. Out of scope for 2c2; revisit if
  2c3 fixtures suggest the signal is missable.
- **LLM-driven judgment scorer for any of the four signals.** The
  Variance harness deviation in 2c3 (snapshots triple-run replacing
  per-fixture N=10) holds **only** for fully-mechanical scorers.
  All four 2c2 scorers are mechanical. If during implementation a
  scorer is found to genuinely need LLM judgment (the
  consistency-ratio scorer is the most plausible candidate),
  surface it then — that scorer would re-introduce per-fixture
  N=10 calibration in 2c3 and the deviation would not hold for
  it.
- **`bin/build-envelope.sh`.** Filed as 2c3.
- **Native `--json` adoption sweep across legacy siblings.** Tracked
  separately under M1/M2/M3 follow-ups; not 2c2's concern.

## References

- `project/plans/active/phase-2-pronto.md` — PR 2c 2c2 paragraph.
- `project/tickets/open/phase-2-2c1-towncrier-audit-extension.md` —
  the scaffold these scorers slot into.
- `project/tickets/closed/phase-2-2a2-inkwell-scorers.md` — the
  canonical 2a2 pattern. 2c2 mirrors layout, observation table,
  empty-scope short-circuit, and per-scorer test convention; the
  SKILL.md / orchestrator deferral mirrors 2a2's posture (not
  2b2's lifted-forward posture).
- `project/tickets/closed/phase-2-2b2-lintguini-scorers.md` —
  secondary precedent for the per-language dispatch shape and the
  bait-and-switch handling pattern (2b2's `js-bait` / `ts-bait`
  fixtures map onto 2c2's `ts-mixed` for structured logging and
  `python-bait` for event-schema consistency).
- `plugins/pronto/references/rubric.md` `event-emission` row —
  weight 5, four composite categories.
- `plugins/pronto/references/roll-your-own/event-emission.md` —
  per-language depth-signal patterns these scorers operationalize
  ("What 'good' looks like" — structured logging, trace
  propagation, metrics, events for state transitions).
- `plugins/pronto/references/sibling-audit-contract.md` § `observations[]`
  entry — the shape each scorer's output is shaped to slot into.
- `plugins/pronto/agents/parsers/scorers/score-skillet.sh` — the
  reference shape for empty-scope short-circuit and the v2 envelope
  construction these scorers feed.
- `plugins/pronto/agents/parsers/scorers/observations-to-score.sh` —
  the helper an end-to-end smoke would pipe through; case-3
  passthrough branch is the verified path until 2c3.
- ADR-005 §1 / §3 — `:audit` skill convention and observations[]
  payload spec.
- ADR-006 §2 / §3 — non-mutation declaration and hook invariants.
