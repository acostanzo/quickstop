---
id: t2
plan: lintguini-expansion
status: closed
updated: 2026-05-06
---

# t2 — `/lintguini:configure`

## Context

The M2 milestone — first new skill. `/lintguini:configure` is the toolkit's bootstrap surface: it scaffolds or upgrades lint config in a target repo to match the rubric. Detects language(s) via the M1 helper, picks a strictness band (`--strict | --lenient | --minimal`, default `--strict`), and writes config files using the conventional shape per tool (ruff config in `pyproject.toml`, biome in `biome.json`, prettier in `.prettierrc`, eslint in `eslint.config.*`, rustfmt in `rustfmt.toml`, rubocop in `.rubocop.yml`, golangci in `.golangci.yml`). The `--ci` flag detects the consumer's CI surface and adds a lint step.

Implements the "Skill set" row for `/lintguini:configure` and the "Configuration model" + "CI wiring" sections of `project/plans/active/lintguini-expansion.md`. ADR-008 binds this work — every config configure writes is a mechanical projection of the rubric at `plugins/pronto/references/roll-your-own/lint-posture.md`.

## Acceptance criteria

- `plugins/lintguini/skills/configure/SKILL.md` exists with valid frontmatter and an `argument-hint` documenting `[--language <lang>] [--strict|--lenient|--minimal] [--ci]`.
- `plugins/lintguini/bin/lintguini-configure.sh` exists, is executable, and is the dispatch entry point the skill invokes.
- `/lintguini:configure --language python --strict` on a fresh fixture (with `*.py` files but no existing lint config) produces a `pyproject.toml` whose `[tool.ruff]` and `[tool.ruff.lint]` sections match the rubric's strict baseline; the first non-blank line is the ADR-008 self-describing comment.
- `--lenient` and `--minimal` produce demonstrably-different configs that still satisfy pronto's `lint-posture` presence check (per `plugins/pronto/references/roll-your-own/lint-posture.md` §"Presence check pronto uses").
- Without `--language`, configure detects all languages present in the repo (via M1's `lintguini-detect-language.sh`) and configures each.
- Idempotent: running configure with the same flags twice on a fresh fixture produces no working-tree diff between the first and second runs.
- When a config file already exists and diverges from the rubric baseline, configure surfaces the diff and asks before overwriting (no silent overwrites).
- `--ci` on a repo with `.github/workflows/` adds a lint step targeting the most-conventional surface for the detected language (GitHub Actions for most repos); CI surface detection reuses the set enumerated in `score-ci-lint-wired.sh`.
- Without `--ci`, configure writes only local config and does not touch CI surfaces.

## Notes

The "ask before overwriting" branch is the protection against silent mutation that ADR-006 calls out — `/lintguini:configure` is a capability surface invoked by the consumer, but it must not destroy author-edited config without asking.

GitHub Actions is the default CI surface only because it's the most-conventional. Repos that already have `.gitlab-ci.yml`, `lefthook.yml`, or `.pre-commit-config.yaml` configured get the lint step in their existing surface — rule of thumb is "where would a new contributor expect the lint step to live?"

## Links

- Plan: `project/plans/active/lintguini-expansion.md` (see "Skill set", "Configuration model", "CI wiring", and acceptance bar A1)
- ADR: `project/adrs/008-lintguini-rubric-authority.md`
- Rubric: `plugins/pronto/references/roll-your-own/lint-posture.md`
