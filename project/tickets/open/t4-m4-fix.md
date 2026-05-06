---
id: t4
plan: lintguini-expansion
status: open
updated: 2026-05-06
---

# t4 — `/lintguini:fix`

## Context

The M4 milestone — the auto-fix surface. `/lintguini:fix` wraps the configured linter/formatter's auto-fix mode behind a mechanical-vs-semantic split:

- **Default (no flag)** — read-only. Reports what `--apply` and `--apply-semantic` would do; writes nothing.
- **`--apply`** — performs only safe fixes (formatting normalization, import sort, trivial rule auto-fixes the linter's auto-fixer flags as safe — e.g., ruff's `--fix` minus `--unsafe-fixes`).
- **`--apply-semantic`** — emits a unified diff to stdout for rule-violations that could change behaviour (e.g., dead-code removal, exception-handling rewrites). Does not write to the working tree.

The split mirrors `/inkwell:tidy`'s `--apply` / `--apply-semantic` separation. Semantic changes never land without human review.

Implements the "Skill set" row for `/lintguini:fix` in `project/plans/active/lintguini-expansion.md`. ADR-006 frames why this matters: `/lintguini:fix` is a capability surface, not a hook — it runs only when the consumer asks for it, and even then `--apply-semantic` requires the consumer to apply the diff themselves.

## Acceptance criteria

- `plugins/lintguini/skills/fix/SKILL.md` exists with valid frontmatter and `argument-hint: [--language <lang>] [--apply | --apply-semantic]`.
- `plugins/lintguini/bin/lintguini-fix.sh` exists, is executable, and is the dispatch entry point.
- `/lintguini:fix` (no flag) on a fixture with mixed safe + semantic findings lists both categories distinctly and writes nothing (verified by `git status --porcelain` showing no changes after invocation).
- `/lintguini:fix --apply` resolves the safe findings (working-tree changes verifiable via `git diff`) and leaves the semantic findings untouched.
- `/lintguini:fix --apply-semantic` emits a unified diff for the semantic findings to stdout and does not write to the working tree.
- `/lintguini:fix` on a clean fixture exits 0 with no findings.
- `--language <lang>` scopes to a single language in polyglot repos.
- The classification of "safe" vs "semantic" is documented inline in the SKILL.md so the contract is greppable: which auto-fixer flags map to `--apply`, which require `--apply-semantic`.

## Notes

The "safe" / "semantic" boundary follows each linter's own conventions where possible — ruff's `--fix` (without `--unsafe-fixes`) is the safe set; biome's `--apply` (without `--apply-unsafe`) is similar. Where a tool doesn't expose the distinction, the skill makes a conservative choice (prefer `--apply-semantic` if uncertain) and documents it inline.

## Links

- Plan: `project/plans/active/lintguini-expansion.md` (see "Skill set" row for `/lintguini:fix`)
- ADR: `project/adrs/008-lintguini-rubric-authority.md`
- Precedent: `/inkwell:tidy` — the mechanical-vs-semantic split this skill mirrors
