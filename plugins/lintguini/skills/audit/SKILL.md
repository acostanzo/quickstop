---
name: audit
description: Audit lint-posture (linter strictness, formatter presence, CI enforcement, rule-suppression count) in a target codebase
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash
argument-hint: --json
---

# Lintguini:audit

Audit the target codebase for Lint / format / language rules and emit a v2 wire-contract envelope.

## Output

Run the orchestrator and emit its stdout verbatim:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/build-envelope.sh" "<REPO_ROOT>"
```

`<REPO_ROOT>` is the absolute path to the target repository — typically the working directory when `/lintguini:audit` was invoked.

The orchestrator runs four deterministic shell scorers, one per rubric category in the `lint-posture` dimension:

- `score-linter-presence.sh` — counts configured linter rules against the per-language baseline
- `score-formatter-presence.sh` — checks for a configured formatter
- `score-ci-lint-wired.sh` — greps CI surfaces for lint invocations
- `score-suppression-count.sh` — counts suppression markers across source files

Each scorer's output (one observation entry, or empty for empty-scope) is `jq -s`'d into the envelope's `observations[]` array. Composite_score is computed by a transitional formula until the rubric stanza lands in 2b3.

The orchestrator is pure shell + grep + awk + jq — no language toolchain on `PATH` is required, no network calls, no consumer-state mutation. ADR-006 §2 (no silent mutation of consumer artefacts) and §3 (vacuously satisfied: lintguini ships no hooks) hold at scorer level.

Emit the orchestrator's stdout verbatim. Do not modify the JSON, do not add commentary — the orchestrator is the source of truth for the wire envelope.
