---
id: t3
plan: lintguini-expansion
status: closed
updated: 2026-05-06
---

# t3 — `/lintguini:lint` and `/lintguini:format`

## Context

The M3 milestone — the daily-run surface. Two skills land together because they share the dispatch shape (detect configured tools → invoke them → surface output) and because most consumers will wire both into the same CI step. `/lintguini:lint` runs the configured linter(s) and emits structured findings as `path:line:rule:message`; `/lintguini:format` runs the configured formatter(s), with `--check` for diff-only output and the default applying changes in place.

Implements the "Skill set" rows for `/lintguini:lint` and `/lintguini:format` in `project/plans/active/lintguini-expansion.md`. After this milestone lands, the writer/runner surface is real and the README full rewrite (deferred from M1 per the plan's "Out of scope") becomes feasible — though it ships as its own follow-up, not as part of this ticket.

## Acceptance criteria

- `plugins/lintguini/skills/lint/SKILL.md` exists with valid frontmatter and `argument-hint: [--language <lang>]`.
- `plugins/lintguini/bin/lintguini-lint.sh` exists, is executable, and is the dispatch entry point.
- `plugins/lintguini/skills/format/SKILL.md` exists with valid frontmatter and `argument-hint: [--language <lang>] [--check]`.
- `plugins/lintguini/bin/lintguini-format.sh` exists, is executable, and is the dispatch entry point.
- After `/lintguini:configure --language python --strict` on a fresh fixture, `/lintguini:lint` against a Python file with a deliberate violation (unused import + line too long) returns at least one finding per violation in `path:line:rule:message` shape; the rule name and line number are correct.
- `/lintguini:lint` on a repo without a lintguini-managed config exits 0 and prints an empty-scope message that includes a pointer to `/lintguini:configure`. The message is greppable for downstream tooling.
- `/lintguini:format --check` on an unformatted file prints a unified diff to stdout and exits non-zero (CI-friendly).
- `/lintguini:format` (no flag) on the same file rewrites it in place and exits 0; running again on the now-formatted file exits 0 with no diff.
- `--language <lang>` in a polyglot repo runs only the named language's tool — verifiable by configuring two languages, deliberately breaking files in both, and observing that `--language python` returns only Python findings.
- Both skills' findings shape is documented inline in the SKILL.md files so downstream tooling (including the M5 `score-lint-pass-rate.sh` scorer) can wire against the contract without re-deriving it.

## Notes

The structured `path:line:rule:message` shape is load-bearing for M5 — `score-lint-pass-rate.sh` parses lint output to compute pass rate. Locking the shape at M3 means M5 doesn't need to re-decide how findings serialize.

`--check` exits non-zero when diffs exist because CI typically runs `format --check` as a gate; non-zero exit is the only signal CI reads.

## Links

- Plan: `project/plans/active/lintguini-expansion.md` (see "Skill set" rows for `/lintguini:lint` and `/lintguini:format`, and acceptance bars A2 and A3)
- ADR: `project/adrs/008-lintguini-rubric-authority.md` (templates the skills run against)
- Rubric: `plugins/pronto/references/roll-your-own/lint-posture.md`
