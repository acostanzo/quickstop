---
id: t4
plan: inkwell-expansion
status: open
updated: 2026-05-05
---

# t4 — M4: `/inkwell:tidy`

## Context

Implements milestone M4 of the inkwell expansion plan. Lands `/inkwell:tidy` — read-only by default, `--apply` for mechanical fixes, `--apply-semantic` for diff-emitting semantic operations. The skill catches the things authors otherwise drift on: duplicates, dead links, stale docs, template non-compliance, missing `## Related` blocks. Mechanical fixes happen in place; semantic rewrites emit diffs for human review rather than writing.

Plan section implemented: "Skill set" row for `/inkwell:tidy` in `project/plans/active/inkwell-expansion.md`.

## Acceptance criteria

- `plugins/inkwell/skills/tidy/SKILL.md` exists. Default invocation (`/inkwell:tidy`) is read-only and lists findings by file path + rule violated.
- `plugins/inkwell/bin/inkwell-tidy.sh` carries the actual logic; the skill is a thin wrapper.
- Findings detected: duplicates (title + content-overlap heuristic), dead links, stale docs (git mtime drift past the staleness threshold), template non-compliance, missing or empty `## Related` blocks.
- `/inkwell:tidy --apply` resolves the **mechanical** findings: link rewriting, frontmatter `updated:` bumps, archiving, near-identical dedup. Mechanical-only — no semantic edits without the explicit flag.
- `/inkwell:tidy --apply-semantic` produces unified diffs for every semantic rewrite and does **not** write to the working tree. Human review consumes the diff and applies it manually if desired.
- `/inkwell:tidy` on a clean tree exits 0 with no findings printed.
- Findings cite the rule by name (e.g. "missing `## Related`", "stale: mtime drift > 90d") so authors can reason about which rule fired.
- The staleness threshold is configurable via the existing audit-thresholds reference shape; tidy reuses the audit's thresholds rather than inventing a parallel knob.

## Notes

The `--apply` / `--apply-semantic` split is deliberate: a writer running `/inkwell:tidy --apply` after a refactor wants the mechanical churn (renamed-file link rewrites, freshness bumps) handled silently, but not surprise rewordings of body prose. Semantic operations always come with a diff so they are reviewed, not trusted.

## Links

- Plan: `project/plans/active/inkwell-expansion.md`
