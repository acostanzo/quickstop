---
name: configure
description: Detect language(s) in the target repo and write rubric-projected lint/format config — ruff/biome/clippy/rubocop/standardrb/golangci — at the conventional location for each tool. Picks a strictness band (--strict | --lenient | --minimal) and optionally wires a lint step into the detected CI surface.
allowed-tools: Read, Write, Edit, Bash, Glob
argument-hint: [--language <lang>] [--strict|--lenient|--minimal] [--ruby-tool rubocop|standardrb] [--ci] [--dry-run]
---

# Lintguini:configure

Bootstrap (or upgrade) lint posture in the target repo. Detects which
of the rubric's six languages — Python, JavaScript, TypeScript, Rust,
Ruby, Go — are present, picks a strictness band, and materialises the
matching templates from `plugins/lintguini/templates/<lang>/<band>/`
at the conventional location for each tool's ecosystem.

ADR-008 binds the templates to the rubric at
`plugins/pronto/references/roll-your-own/lint-posture.md`. Configure
writes mechanical projections of the rubric, never parallel definitions.
Every config file the skill touches carries the lintguini provenance
comment so a future author lands on the rubric when they read the file.

## Inputs

- `--language <lang>` — optional. Scope to a single language
  (`python` | `javascript` | `typescript` | `rust` | `ruby` | `go`).
  Without it, every detected language is configured.
- `--strict` | `--lenient` | `--minimal` — optional. Strictness band.
  Mutually exclusive. Default: `--strict`.
- `--ruby-tool rubocop|standardrb` — optional. Ruby tool selection.
  Without it, the skill auto-detects from `Gemfile`: a line matching
  `gem "standard"` picks standardrb; otherwise rubocop. The flag
  overrides auto-detection.
- `--ci` — optional. Wire a lint step into the consumer's most-
  conventional CI surface. Detection priority:
  1. `.github/workflows/` (writes `lintguini-lint.yml`)
  2. `.gitlab-ci.yml` (appends `lintguini-lint` job)
  3. `Makefile` (appends `lintguini-lint` target)
  4. `lefthook.yml` (appends a `pre-commit` command)
  5. `.pre-commit-config.yaml` (appends a hook)
  
  No CI surface present → warning to stderr; the skill does **not**
  invent a CI shape from scratch.
- `--dry-run` — optional. Print what *would* be written without
  modifying any files. Mirrors the test-surface knob `/inkwell:tidy`
  uses.

## Behaviour

### 1. Dispatch to the bin

The deterministic half of the skill lives at
`bin/lintguini-configure.sh`. Pass through every argument the user
supplied, plus the absolute path to the target repo:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/lintguini-configure.sh" \
    [--language <lang>] \
    [--strict|--lenient|--minimal] \
    [--ruby-tool rubocop|standardrb] \
    [--ci] \
    [--dry-run] \
    "<REPO_ROOT>"
```

`<REPO_ROOT>` is the absolute path to the target repository — typically
the working directory when `/lintguini:configure` was invoked.

### 2. Surface the result

The bin emits one line per file on stdout, in one of these shapes:

| Shape | Meaning |
|---|---|
| `wrote <path>` | Destination did not exist; new file. |
| `updated <path>` | Destination existed; content changed (merge or rewrite). |
| `skipped <path> (already configured)` | Destination is byte-equivalent to what configure would write. |
| `would wrote <path>` / `would updated <path>` / `would skipped <path>` | `--dry-run` preview. |
| `warning <message>` (stderr) | Non-fatal diagnostic — e.g. no CI surface detected. |

Echo the bin's output to the user. Add a one-line summary on top
naming the languages configured and the band used (e.g. *"Configured
Python at the strict band; Ruby auto-detected as rubocop"*). Don't
re-format the bin's per-file lines — they're the contract.

### 3. Exit codes

The bin's exit code is the skill's exit code:

- `0` — success (or dry-run completed cleanly).
- `2` — argument errors (mutually-exclusive flags, unknown language,
  `--language` scoped to a language not detected, malformed flags).
- `3` — required tooling missing (`jq`, or `python3` < 3.11 — tomllib).
- `4` — write failure (permission, mv, etc.).

If the bin exits non-zero, surface its stderr to the user without
re-interpretation; the bin is the source of truth for diagnostics.

## Per-language file map

What the skill writes, by language and band:

| Language | Files written | Merge or copy |
|---|---|---|
| Python | `pyproject.toml` (`[tool.ruff]`, `[tool.ruff.lint]`, `[tool.ruff.format]`) | merge (preserves non-ruff sections) |
| JavaScript | `biome.json` | merge (preserves non-`linter`/`formatter` keys) |
| TypeScript | `biome.json`, `tsconfig.json` | merge (compilerOptions managed) |
| Rust | `rustfmt.toml`, `Cargo.toml` (`[lints.*]` fragment, strict/lenient bands only) | rustfmt.toml direct; Cargo.toml merge at bottom |
| Ruby (rubocop) | `.rubocop.yml` | direct copy |
| Ruby (standardrb) | `standard.yml` | direct copy (band-agnostic — standardrb rejects rule-by-rule debate) |
| Go | `.golangci.yml` | direct copy |

Rust's minimal band is rustfmt-only — no `Cargo.lints.toml` fragment
exists in `templates/rust/minimal/`, so configure does not touch
`Cargo.toml` in that band. This is intentional: minimal means
"presence-only, no opinion".

## What this skill does not do

- **Does not run the linter or formatter.** Configuration only.
  Running tools is `/lintguini:lint` and `/lintguini:format` (T3).
- **Does not auto-fix lint findings.** That's `/lintguini:fix` (T4).
- **Does not modify devDependencies.** Configure writes config files;
  installing the tools (`npm install @biomejs/biome`, `gem install
  rubocop`, `pip install ruff`, etc.) is the consumer's job.
- **Does not invent a CI surface.** `--ci` only writes when an
  existing CI surface is present; otherwise it warns and proceeds.
- **Does not delete prior tool selections.** If a previous run wrote
  `.rubocop.yml` and a later run picks standardrb, the stale
  `.rubocop.yml` is left in place. The consumer can `rm` it.
- **Does not modify the audit's score-* logic.** The audit stays
  deterministic (ADR-007 mirror) and unchanged by this skill.

## ADR pointers

- **ADR-008** (`project/adrs/008-lintguini-rubric-authority.md`) —
  the rubric is the authority; templates are projections. Every
  config the skill writes carries the provenance comment per §1.4.
- **ADR-006** (`project/adrs/006-plugin-responsibility-boundary.md`)
  — `/lintguini:configure` is a capability surface invoked by the
  consumer, not a hook. The skill only touches files documented in
  the per-language file map.
