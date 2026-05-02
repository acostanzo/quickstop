---
name: audit
description: Audit event-emission posture (structured logging, metrics, trace propagation, event-schema consistency) in a target codebase
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash
argument-hint: --json
---

# Towncrier:audit

Audit the target codebase for event-emission posture and emit a v2 wire-contract envelope.

## Output

Run the orchestrator and emit its stdout verbatim:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/build-envelope.sh" "<REPO_ROOT>"
```

`<REPO_ROOT>` is the absolute path to the target repository — typically the working directory when `/towncrier:audit` was invoked.

The orchestrator runs four deterministic shell scorers, one per rubric category in the `event-emission` dimension:

- `score-structured-logging-ratio.sh` — counts structured-logger emit sites vs free-form `print()` / `console.log` / `fmt.Println` per primary language; emits the structured fraction
- `score-metrics-presence.sh` — detects metrics-library imports (configured) and counts metrics-defining call sites (counters, histograms, gauges, statsd ops); emits the imported-but-unused branch when configured=1 and sites=0
- `score-trace-propagation.sh` — walks request-handler-shaped files (FastAPI / Flask / Express / Gin / Axum etc.) and counts the fraction that reference trace context (W3C headers, OTel span APIs); empty-scopes for CLI tools and library packages with no handlers
- `score-event-schema-consistency.sh` — for each structured emission line, checks for an `event=` / `event:` / `Event:` domain anchor; emits the well-shaped fraction (heuristic — well-shaped means a recognised domain-anchor field, not strict schema validation)

Each scorer's output (one observation entry, or empty for empty-scope) is `jq -s`'d into the envelope's `observations[]` array. `composite_score` is `null` — the `event-emission` translation rules stanza in `plugins/pronto/references/rubric.md` is the sole authority on dimension scoring.

Empty-scope short-circuits (language not detected, no emission sites, no handler-shaped files, no metrics infra) drop the affected observation rather than failing the audit. Empty `observations[]` triggers the translator's case-3 carve-out (passthrough back to the kernel presence check), preserving the "no scope" semantic.

The orchestrator is pure shell + grep + awk + jq — no language toolchain on `PATH` is required, no network calls, no consumer-state mutation. ADR-006 §2 (no silent mutation of consumer artefacts) and §3 (towncrier's hook surface lives under `bin/emit.sh` and `hooks/hooks.json`; the audit skill is a parallel entry point that does not interact with the hook handler) hold at scorer level.

Emit the orchestrator's stdout verbatim. Do not modify the JSON, do not add commentary — the orchestrator is the source of truth for the wire envelope.
