# AGENTS.md

Conventions and context for coding agents (Claude Code, Aider, Cursor, Copilot, Codex, etc.) working in this repo. Humans are welcome to read this too — it's the plain-text map of how work happens here.

## Where work lives

| Folder | Contents |
|---|---|
| `project/plans/` | Plans — one markdown file per initiative, states reflected in subdirs (`draft/`, `active/`, `done/`) |
| `project/tickets/` | Tickets — plan-scoped units of work (`open/`, `closed/`) |
| `project/adrs/` | Architecture decision records — flat dir, zero-padded numeric sequence, status in frontmatter |
| `project/pulse/` | Append-only journal — one markdown file per day (`YYYY-MM-DD.md`) |
| `.claude/` | Claude Code local configuration: skills, agents, rules, settings |
| `.pronto/` | Pronto tool state (cached audit results, etc.) — hidden and never user-authored |

See `project/README.md` for the detail on artifact conventions and lifecycle states.

## How to work

1. If an initiative needs multiple commits, start with a plan under `project/plans/active/`.
2. If a change requires a decision with long-term consequences, record it as an ADR under `project/adrs/`.
3. Track execution with tickets under `project/tickets/open/`. Every ticket belongs to a plan.
4. Log meaningful progress, context, and surprises to today's `project/pulse/YYYY-MM-DD.md`.
5. Keep commits atomic, conventional, and small enough to review in under five minutes.

## Repo-specific conventions

<!-- Override this section with anything repo-specific: testing, deployment, domain terminology, languages, dependency expectations, etc. -->

- **Test-then-review after every edit.** Run the relevant check (parser, type-check, test suite) before claiming a change is done, then read-through for what automated checks don't catch.
- **Don't delegate understanding.** When handing work to a subagent or a colleague, include the file paths, the line numbers, and the specific thing to change — not just the task name.

## See also

- `README.md` — human-facing project overview.
- Claude Code documentation: https://docs.anthropic.com/en/docs/claude-code
