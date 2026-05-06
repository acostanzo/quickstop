---
name: fix
description: Wrap each language's auto-fix mode behind a uniform read-only / --apply / --apply-semantic surface. Default mode previews safe fixes as a unified diff; --apply mutates the working tree and emits `fixed <path>` per touched file; --apply-semantic previews unsafe fixes as a diff but never writes — the consumer reviews and applies it themselves.
allowed-tools: Read, Bash, Glob
argument-hint: [--language <lang>] [--apply | --apply-semantic]
---

# Lintguini:fix

Wrap each rubric-pinned linter's auto-fix mode behind one surface,
mirroring `/inkwell:tidy`'s mechanical-vs-semantic split. Mechanical
fixes (whitespace normalisation, import sorting, rule auto-fixes the
linter itself flags as safe) are silent and applied by `--apply`;
semantic fixes (anything that could change behaviour — dead-code
removal, exception-handling rewrites) are diff-only via
`--apply-semantic` and never land without human review.

ADR-008 binds the dispatch to the rubric at
`plugins/pronto/references/roll-your-own/lint-posture.md`. The
canonical tool per language is fixed.

## Modes

| Mode | Flag | Behaviour | Writes? |
|---|---|---|---|
| **Read-only** (default) | (no flag) | Run the linter's safe-fix mode in preview form; surface what *would* change as a unified diff. Exit 1 if anything to fix (CI-friendly), 0 if clean. | No |
| **Apply** | `--apply` | Run the linter's safe-fix mode for real; mutate files in place. One line per touched file: `fixed <path>`. Exit 0 on success. | Yes (working tree) |
| **Apply-semantic** | `--apply-semantic` | Run the linter's *unsafe*-fix mode in preview form; emit a diff but never write. The user reviews and pipes into `git apply` if right. Exit 1 if any diff emitted, 0 otherwise. | No |

`--apply` and `--apply-semantic` are mutually exclusive (exit 2).

## Inputs

- `--language <lang>` — optional. Scope to a single language
  (`python` | `javascript` | `typescript` | `rust` | `ruby` | `go`).
  Without it, every detected language with a lintguini-managed config
  gets fixed.
- `--apply` — apply safe fixes in place.
- `--apply-semantic` — preview unsafe fixes as a diff.

The repo to fix is the working directory when `/lintguini:fix` is
invoked.

## Behaviour

### 1. Dispatch to the bin

The deterministic half of the skill lives at
`bin/lintguini-fix.sh`. Pass through the user's flags plus the
absolute path to the target repo:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/lintguini-fix.sh" \
    [--language <lang>] \
    [--apply | --apply-semantic] \
    "<REPO_ROOT>"
```

`<REPO_ROOT>` is the absolute path to the target repository — typically
the working directory when `/lintguini:fix` was invoked.

### 2. Surface the result verbatim

The bin's stdout is the contract. Echo it to the user without
re-formatting.

**Read-only / `--apply-semantic`** — unified diff:

```
--- a/src/auth.py
+++ b/src/auth.py
@@ -1,3 +1,2 @@
-import os, sys
-import json
+import json
+import os
```

The `--- a/<path>` / `+++ b/<path>` headers are normalised so the
output pipes directly into `git apply` regardless of which underlying
tool emitted the diff.

**`--apply`** — one line per touched file:

```
fixed src/auth.py
fixed src/api.py
```

When more than one configured language is being processed in a single
run, stdout is sectioned with a metadata header line:

```
# python — 2 files with fixes available
--- a/src/auth.py
...
# javascript — 1 file with semantic fixes available
--- a/src/render.js
...
```

In `--apply` mode the verb in the header changes:

```
# python — 2 files fixed
fixed src/auth.py
fixed src/api.py
# javascript — 1 file fixed
fixed src/render.js
```

The header line begins with `# ` (which is a unified-diff no-op when
piped into `git apply`). Single-language runs (`--language <lang>` or
only one configured language) emit no header.

Stderr carries empty-scope and tool-missing diagnostics:

```
<language>: not configured (run /lintguini:configure --language <lang>)
<language>: <tool> not on PATH (install <tool>)
<language>: --apply-semantic empty-scope (<tool> has no safe/unsafe split)
```

### 3. Exit codes

The bin's exit code is the skill's exit code:

- `0` — read-only / `--apply-semantic` emitted nothing; or `--apply`
  succeeded.
- `1` — read-only / `--apply-semantic` emitted at least one diff
  (CI-friendly: "this branch has unfixed issues").
- `2` — argument errors (mutually-exclusive flags, unknown
  `--language`, `--language` scoped to a non-detected language,
  missing `REPO_ROOT`).
- `3` — required tooling missing on PATH for an in-scope language.
- `4` — fix execution failure (apply tool crashed, copy-and-diff
  snapshot failed).

If the bin exits non-zero, surface its stderr to the user without
re-interpretation.

## Per-language tool dispatch

| Language | Read-only preview | Apply | Semantic preview |
|---|---|---|---|
| python | `ruff check --fix --diff .` (native) | `ruff check --fix .` | `ruff check --fix --unsafe-fixes --diff .` (native) |
| javascript | copy-and-diff `[biome check --write .]` | `biome check --write .` | copy-and-diff `[biome check --write --unsafe .]` |
| typescript | same as javascript | same as javascript | same as javascript |
| rust | copy-and-diff `[cargo clippy --fix --allow-dirty]` | `cargo clippy --fix --allow-dirty` | empty-scope (clippy has no safe/unsafe split) |
| ruby (rubocop) | copy-and-diff `[rubocop -a .]` | `rubocop -a .` | copy-and-diff `[rubocop -A .]` (autocorrect-all) |
| ruby (standardrb) | copy-and-diff `[standardrb --fix .]` | `standardrb --fix .` | empty-scope (standardrb has no safe/unsafe split) |
| go | `gofmt -d .` (native) | `gofmt -w .` | empty-scope (gofmt is formatter-only; golangci-lint --fix dry-run is patchy) |

Ruby tool selection follows the provenance-marked config: `standard.yml`
with the lintguini provenance picks standardrb; otherwise rubocop.

## Safe vs semantic — the contract

- **Safe** = whatever each linter's own auto-fixer flags as safe to
  apply without review. For ruff that's `--fix` *without* `--unsafe-fixes`.
  For biome it's `--write` *without* `--unsafe`. For rubocop it's `-a`
  (autocorrect, safe-only) as opposed to `-A` (autocorrect-all,
  including unsafe). The skill defers to the tool's own definition,
  not a parallel notion.
- **Semantic** = whatever the same linter flags as *unsafe* — fixes
  that could change behaviour. Shown as a diff only, because they
  warrant human review.
- **Empty-scope** = the linter exposes no safe/unsafe distinction
  (clippy, standardrb, gofmt). The skill prefers conservative — empty
  stderr message and exit 0 for `--apply-semantic`, rather than
  guessing.

## Copy-and-diff fallback

Tools without a native preview / unsafe-diff mode (biome, rubocop's
autocorrect-all, standardrb across versions, cargo clippy's --fix
--dry-run reliability) get the same preview shape via a snapshot:

1. Snapshot `REPO_ROOT` into a tempdir, skipping `.git`,
   `node_modules`, `vendor`, `target`, `dist`, `build`.
2. Run the fix command against the copy.
3. `diff -u --label "a/<path>" --label "b/<path>"` each file in the
   original against the copy.
4. Discard the tempdir.

The fallback's contract is identical to native diff modes — unified
diff on stdout, working tree untouched, `--- a/<path>` / `+++ b/<path>`
headers. A future contributor adding a new language reaches for the
fallback when (a) the tool can't preview without writing, or (b) the
tool's preview mode is too version-fragile to depend on.

## Idempotency on `--apply`

Running `/lintguini:fix --apply` twice on the same tree yields zero
`fixed <path>` lines on the second run — the pre-pass diff (which
enumerates touched files) returns empty because the first apply
already fixed everything fixable. Mirrors `/lintguini:format`'s
idempotency contract.

## What this skill does not do

- **Does not lint.** That's `/lintguini:lint` (T3 sibling). Lint
  reports findings; fix tries to resolve them.
- **Does not format-only.** That's `/lintguini:format` (T3 sibling).
  Format normalises whitespace; fix wraps the linter's broader
  auto-fix surface (which often *includes* formatting plus rule
  auto-fixes).
- **Does not invent rule fixers.** The skill wraps each tool's native
  auto-fix mode — it doesn't reinvent fixes that the tool can't do
  itself.
- **Does not install the tools.** If the canonical tool is missing,
  the bin exits 3 with a stderr hint naming the tool.
- **Does not fall back to an alternative tool.** Per ADR-008, the
  rubric pins one tool per language. Falling back would mean fixing
  a repo against a different rubric than the one
  `/lintguini:configure` wrote it for.
- **Does not auto-apply semantic fixes.** Mirrors `/inkwell:tidy`'s
  contract: semantic changes never land without human review.

## ADR pointers

- **ADR-008** (`project/adrs/008-lintguini-rubric-authority.md`) —
  the rubric pins canonical tool per language.
- **ADR-006** (`project/adrs/006-plugin-responsibility-boundary.md`)
  — `/lintguini:fix` is a capability surface invoked by the consumer,
  not a hook. Read-only and `--apply-semantic` write nothing;
  `--apply` mutates only because the consumer asked.
