---
name: audit
description: Audit code-documentation depth (README quality, docs coverage, staleness, internal link health) in a target codebase
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash
argument-hint: --json
---

# Inkwell:audit

Audit the target codebase for Code documentation and emit a v2 wire-contract envelope.

## Output

Run the orchestrator and emit its stdout verbatim:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/build-envelope.sh" "<REPO_ROOT>"
```

`<REPO_ROOT>` is the absolute path to the target repository — typically the working directory when `/inkwell:audit` was invoked.

The orchestrator runs four deterministic shell scorers, one per rubric category in the `code-documentation` dimension:

- `score-readme-quality.sh` — counts answered arrival questions in `README.md` (project intent, audience, install, status, next-step pointers)
- `score-docs-coverage.sh` — per-language tool dispatch (`interrogate` / `eslint-jsdoc` / `revive` / `cargo doc`) for public-API docstring coverage
- `score-doc-staleness.sh` — `git log` mtimes for source files vs the latest docs touch, counts files modified more than 90 days after docs
- `score-link-health.sh` — `lychee --offline` over `README.md` and `docs/`, counts broken on-disk and within-document anchor links

Each scorer's output (one observation entry, or empty for empty-scope) is `jq -s`'d into the envelope's `observations[]` array. `composite_score` is `null` — the `code-documentation` translation rules stanza in `plugins/pronto/references/rubric.md` is the sole authority on dimension scoring.

Tool absence (no `interrogate`, no `lychee`) and empty-scope short-circuits (no `README.md`, no language detected, not a git repo) drop the affected observation rather than failing the audit. Empty `observations[]` triggers the translator's case-3 carve-out (passthrough back to the kernel presence check), preserving the "no scope" semantic.

The orchestrator is pure shell + grep + awk + jq — no language toolchain on `PATH` is required for the orchestrator itself, no network calls, no consumer-state mutation. ADR-006 §2 (no silent mutation of consumer artefacts) and §3 (vacuously satisfied: inkwell ships no hooks) hold at scorer level.

Emit the orchestrator's stdout verbatim. Do not modify the JSON, do not add commentary — the orchestrator is the source of truth for the wire envelope.
