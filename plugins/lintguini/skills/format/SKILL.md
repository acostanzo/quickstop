---
name: format
description: Run the lintguini-configured formatter(s) in the target repo. Default mode mutates files in place and prints `formatted <path>` per modified file. `--check` mode is read-only — prints `would format <path>` per file and exits non-zero when any file would change (CI-friendly).
allowed-tools: Read, Bash, Glob
argument-hint: [--language <lang>] [--check]
---

# Lintguini:format

Run the configured formatter(s) for the target repo. Two modes:

- **Default (apply)** — mutate files in place. One line per modified
  file on stdout: `formatted <path>`. Exit 0 on success.
- **`--check`** — diff-only / read-only. One line per file that
  would change: `would format <path>`. Exit non-zero (1) when at
  least one file would change. CI-friendly — non-zero exit is the
  signal CI gates on.

ADR-008 binds the dispatch to the rubric at
`plugins/pronto/references/roll-your-own/lint-posture.md`. The canonical
formatter per language is fixed.

## Inputs

- `--language <lang>` — optional. Scope to a single language
  (`python` | `javascript` | `typescript` | `rust` | `ruby` | `go`).
  Without it, every detected language with a lintguini-managed config
  gets formatted.
- `--check` — optional. Read-only mode. Surface what would change to
  stdout, exit 1 if any file would change. Default: apply changes.

## Behaviour

### 1. Dispatch to the bin

The deterministic half of the skill lives at
`bin/lintguini-format.sh`. Pass through the user's flags plus the
absolute path to the target repo:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/lintguini-format.sh" \
    [--language <lang>] \
    [--check] \
    "<REPO_ROOT>"
```

`<REPO_ROOT>` is the absolute path to the target repository — typically
the working directory when `/lintguini:format` was invoked.

### 2. Surface the result verbatim

The bin's stdout is the contract. Echo it to the user without
re-formatting.

**Apply mode** — one line per modified file:

```
formatted src/auth.py
formatted src/render.ts
```

**`--check` mode** — one line per file that would change:

```
would format src/auth.py
would format src/render.ts
```

When more than one configured language is being processed in a single
run, stdout is sectioned with a metadata header line:

```
# python — 3 files formatted
formatted src/auth.py
formatted src/main.py
formatted tests/test_auth.py
# javascript — 1 file formatted
formatted src/render.js
```

In `--check` mode the verb in the header changes:

```
# python — 3 files would be reformatted
would format src/auth.py
...
```

The header line begins with `# `. Single-language runs (`--language
<lang>` or only one configured language) emit no header.

Stderr carries empty-scope and tool-missing diagnostics:

```
<language>: not configured (run /lintguini:configure --language <lang>)
<language>: <tool> not on PATH (install <tool>)
```

### 3. Exit codes

The bin's exit code is the skill's exit code:

- `0` — apply mode succeeded; or `--check` found nothing to change.
- `1` — `--check` mode found at least one file that would change.
- `2` — argument errors (unknown flag, unsupported `--language`,
  `--language` scoped to a language not detected in the repo).
- `3` — required tooling missing on PATH for an in-scope language.
- `4` — formatter execution failure (tool crashed or returned an
  unrecognised exit code).

If the bin exits non-zero, surface its stderr to the user without
re-interpretation.

## Per-language tool dispatch

| Language | Apply | Check |
|---|---|---|
| python | `ruff format .` | `ruff format --check .` |
| javascript | `biome format --write .` | `biome check --formatter-enabled=true --linter-enabled=false --reporter=github .` |
| typescript | `biome format --write .` | same as javascript |
| rust | `cargo fmt` | `cargo fmt -- --check` |
| ruby (rubocop) | `rubocop -A .` | `rubocop --format json .` (read-only) |
| ruby (standardrb) | `standardrb --fix .` | `standardrb --format json .` (read-only) |
| go | `gofmt -w .` | `gofmt -l .` |

Ruby tool selection follows the provenance-marked config: `standard.yml`
with the lintguini provenance picks standardrb; otherwise rubocop.

## Output-shape contract

**Apply mode**, one per modified file (sorted, deterministic):

```
formatted <path>
```

**`--check` mode**, one per file that would change (sorted, deterministic):

```
would format <path>
```

Section headers (polyglot only) match `^# `:

```
# <language> — <N> file[s] formatted
# <language> — <N> file[s] would be reformatted
```

Singular form `1 file ...` for a count of 1, otherwise `<N> files ...`.

## Apply-mode mechanics

The bin runs the per-tool check pass first to enumerate which files
would change, then runs the apply pass. The pre-apply file list is the
contract for the `formatted <path>` lines on stdout. Two tool
invocations per language is the cost of providing a tool-agnostic
per-file output contract — formatters are idempotent, so the second
run (the apply) is bounded.

Idempotency: running `/lintguini:format` twice in a row on the same
tree yields zero `formatted ...` lines on the second run (the file
list from the second pre-apply check is empty).

## What this skill does not do

- **Does not lint.** That's `/lintguini:lint` (T3 sibling). Format
  rewrites; lint reports.
- **Does not auto-fix lint findings.** That's `/lintguini:fix` (T4).
  Format only normalises whitespace / style; semantic fixes are out
  of scope here.
- **Does not install the formatters.** If the canonical tool is missing,
  the bin exits 3 with a stderr hint naming the tool.
- **Does not fall back to an alternative formatter.** Per ADR-008, the
  rubric pins one tool per language.

## ADR pointers

- **ADR-008** (`project/adrs/008-lintguini-rubric-authority.md`) —
  the rubric pins the canonical formatter per language.
- **ADR-006** (`project/adrs/006-plugin-responsibility-boundary.md`)
  — `/lintguini:format` is a capability surface invoked by the
  consumer. In apply mode the skill mutates the working tree, but
  the mutation is bounded to source files the formatter recognises
  and the consumer invoked the skill explicitly (capability surface,
  not a hook).
