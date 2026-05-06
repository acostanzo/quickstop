---
name: lint
description: Run the lintguini-configured linter(s) in the target repo and surface findings as <path>:<line>:<rule>:<message> — one per line on stdout. Empty-scope cleanly when no lintguini-managed config is present. Polyglot repos are sectioned by language.
allowed-tools: Read, Bash, Glob
argument-hint: [--language <lang>]
---

# Lintguini:lint

Run the configured linter(s) for the target repo and surface their
findings in a stable, machine-readable shape:

```
<path>:<line>:<rule>:<message>
```

One finding per line on stdout. The shape is the **locked T3 contract**
downstream tooling depends on — most notably the M5
`score-lint-pass-rate.sh` scorer, which parses this output to grade
pass rate. Adding a column or reordering fields is a breaking change.

ADR-008 binds the dispatch to the rubric at
`plugins/pronto/references/roll-your-own/lint-posture.md`. The canonical
tool per language is fixed — there is no fallback to a "second-best"
linter, because falling back would mean grading a repo against a
different rubric than the one `/lintguini:configure` wrote it for.

## Inputs

- `--language <lang>` — optional. Scope to a single language
  (`python` | `javascript` | `typescript` | `rust` | `ruby` | `go`).
  Without it, every detected language with a lintguini-managed config
  gets linted.

The repo to lint is the working directory when `/lintguini:lint` is
invoked.

## Behaviour

### 1. Dispatch to the bin

The deterministic half of the skill lives at
`bin/lintguini-lint.sh`. Pass through the user's flag plus the
absolute path to the target repo:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/lintguini-lint.sh" \
    [--language <lang>] \
    "<REPO_ROOT>"
```

`<REPO_ROOT>` is the absolute path to the target repository — typically
the working directory when `/lintguini:lint` was invoked.

### 2. Surface the result verbatim

The bin's stdout is the contract. Echo it to the user without
re-formatting. Findings look like:

```
src/auth.py:42:E501:line too long (120 > 88 characters)
src/auth.py:67:F401:imported but unused: typing.Optional
```

When more than one configured language is being linted, stdout is
sectioned by language with a metadata header line:

```
# python — 3 findings
src/auth.py:42:E501:line too long (120 > 88 characters)
src/auth.py:67:F401:imported but unused: typing.Optional
src/api.py:12:E711:comparison to None should be 'is None'
# javascript — 1 finding
src/render.js:88:lint/suspicious/noConsole:Unexpected console statement
```

The header line begins with `# ` and is the only non-finding line on
stdout. Single-language runs (`--language <lang>` or only one
configured language) emit no header.

Stderr carries empty-scope and tool-missing diagnostics:

```
<language>: not configured (run /lintguini:configure --language <lang>)
<language>: <tool> not on PATH (install <tool>)
```

Surface those to the user too — they're part of the operational
signal, not noise to suppress.

### 3. Exit codes

The bin's exit code is the skill's exit code:

- `0` — no findings (or empty-scope on every in-scope language).
- `1` — one or more findings emitted (CI-friendly: lint failures
  fail the step).
- `2` — argument errors (unknown flag, unsupported `--language`,
  `--language` scoped to a language not detected in the repo).
- `3` — required tooling missing on PATH for an in-scope language.
- `4` — linter execution failure (tool crashed or emitted
  unparseable output).

If the bin exits non-zero, surface its stderr to the user without
re-interpretation.

## Per-language tool dispatch

| Language | Tool | Invocation | Source-format |
|---|---|---|---|
| python | `ruff check` | `ruff check --output-format=json .` | JSON array |
| javascript | `biome check` | `biome check --reporter=github` | GitHub annotations |
| typescript | `biome check` | `biome check --reporter=github` | GitHub annotations |
| rust | `cargo clippy` | `cargo clippy --message-format=json --quiet -- -D warnings` | NDJSON (compiler-message lines) |
| ruby (rubocop) | `rubocop` | `rubocop --format json .` | JSON object |
| ruby (standardrb) | `standardrb` | `standardrb --format json .` | JSON object (rubocop schema) |
| go | `golangci-lint` | `golangci-lint run --out-format=json ./...` | JSON object |

Ruby tool selection follows the provenance-marked config: `standard.yml`
with the lintguini provenance picks standardrb; otherwise rubocop.

## Findings-shape contract (pinned for downstream tooling)

```
<path>:<line>:<rule>:<message>
```

- `path` — repo-relative path to the source file. Tools that emit
  absolute paths get normalised in the bin.
- `line` — 1-indexed line number in the source file.
- `rule` — the linter's own rule code or rule path (e.g. `F401`,
  `lint/correctness/noUnusedVariables`, `clippy::needless_return`,
  `Style/FrozenStringLiteralComment`, `errcheck`). Verbatim from the
  tool — no normalisation, since the rule code is what consumers grep
  for in suppression comments.
- `message` — the human-readable diagnostic. Embedded newlines are
  collapsed to single spaces so each finding stays one line.

Findings are sorted by `(path, line, rule, message)` per language
section (column is used internally by some tools but not in the
contract). Triple-run determinism: same input → byte-equivalent
output across runs.

Section headers (polyglot only) match `^# `:

```
# <language> — <N> finding[s]
```

Singular form `1 finding` for a count of 1, otherwise `<N> findings`.

## What this skill does not do

- **Does not auto-fix.** That's `/lintguini:fix` (T4). Lint is read-only.
- **Does not write to the consumer's working tree.** ADR-006 §2 — lint
  is a capability surface invoked by the consumer, never a hook.
- **Does not install the linters.** If the canonical tool is missing,
  the bin exits 3 with a stderr hint naming the tool. Installing it is
  the consumer's job.
- **Does not fall back to an alternative linter.** Per ADR-008, the
  rubric pins one tool per language. Falling back would silently grade
  a repo against a different rubric.
- **Does not modify the audit's `score-*` logic.** The audit stays
  deterministic and unchanged by this skill.

## ADR pointers

- **ADR-008** (`project/adrs/008-lintguini-rubric-authority.md`) —
  the rubric pins canonical tool per language; this skill dispatches
  exactly that tool.
- **ADR-006** (`project/adrs/006-plugin-responsibility-boundary.md`)
  — `/lintguini:lint` is a capability surface invoked by the consumer,
  not a hook. The bin reads source files; it does not write.
