---
id: t6
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# T6 — /pronto:init skill

## Context

`plugins/pronto/skills/init/SKILL.md` — the kernel scaffolder. Drops `templates/` contents into the target repo, detects existing files (refuse on collision unless `--force`), proposes installs for recommended siblings not already present, and is idempotent on re-run. The user-facing entry point to start using pronto in a new repo.

## Acceptance

- Frontmatter: `name: init`, `description`, `disable-model-invocation: true`, `argument-hint: "[--force]"`, `allowed-tools: Read, Glob, Bash, Write, Edit, AskUserQuestion`.
- Six phases: env resolution → collision scan → present plan → copy templates (with per-path collision rules) → sibling recommendations → propose installs via AskUserQuestion → summary.
- Per-path collision rules documented:
  - `AGENTS.md` / `project/**` / `.pronto/state.json` — refuse without `--force`.
  - `.claude/**` — skip file-level collisions (consumer may already have `.claude/`); add files consumer lacks.
  - `gitignore-additions.txt` — append-and-dedupe into target `.gitignore`.
- Sibling recommendations filter out `phase-2-plus` statuses (those plugins don't exist yet to install).
- Idempotency: a second run without `--force` reports zero new files and `.gitignore already current`; sibling presence re-evaluated on every run.

## Decisions recorded

- **Plan-then-act.** Always show the collision plan before writing anything. No silent overwrites, no hidden behavior.
- **`--force` is coarse.** No per-path force flag. Consumers needing to reset a single file can `rm` and re-run; simpler than a menu of knobs.
- **`.claude/` is skip-on-collision, not refuse.** Consumers often arrive with an existing `.claude/` — pronto shouldn't require `--force` to accept it. Other targets are refuse-on-collision to prevent surprise overwrites of authored content.
- **Installs run via AskUserQuestion, not programmatically.** Pronto doesn't shell to `/plugin install ...` autonomously; it proposes and the user confirms. Keeps Claude Code's install path in the loop.
- **Phase-2+ siblings intentionally skipped from recommendations.** `recommendations.json` lists them, but init doesn't propose installs for plugins that aren't shipped yet. They'll show up in `/pronto:status` output as "recommended sibling not yet available."
- **Kernel scaffolding never depends on sibling presence.** Init writes the kernel regardless of what siblings are installed; it proposes installs *after* scaffolding. This keeps the minimum-viable state (just kernel, no siblings) coherent.
