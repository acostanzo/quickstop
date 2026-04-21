# Roll Your Own — AGENTS.md Scaffold

How to achieve the `agents-md` dimension's readiness without running `/pronto:init`.

Pronto *is* the recommended path for this dimension — the kernel scaffolds `AGENTS.md` automatically. This document is what to do if you prefer to author it by hand (which is also a valid path — AGENTS.md is a portable convention, not a pronto-specific artifact).

## What "good" looks like

A non-empty `AGENTS.md` at the repo root. It's the agent-facing equivalent of `CONTRIBUTING.md`: how agents (Claude Code, Aider, Cursor, Copilot, Codex, etc.) should behave in this codebase. Under 100 lines. Readable by humans too.

Key sections:

1. **Where work lives** — the folders that hold source of truth for plans, tickets, decisions, running journals.
2. **How to work** — the commit + review + test conventions an agent should follow.
3. **Repo-specific conventions** — the things that would surprise a newcomer. Domain terminology, test commands, deployment gotchas.
4. **See also** — pointers to deeper docs (`README.md`, `docs/`, `CLAUDE.md`, Claude Code docs).

## Minimum viable `AGENTS.md`

```markdown
# AGENTS.md

Conventions for agents working in this repo.

## Where work lives

- `README.md` — user-facing project overview
- `docs/` — deeper documentation
- `project/` — plans, tickets, ADRs, journal (when present)
- `.claude/` — Claude Code local config

## How to work

- **Atomic conventional commits.** `feat:`, `fix:`, `chore:`, etc. One logical change per commit.
- **Test before claiming done.** Run the relevant check (lint, type-check, test suite) before marking work complete.
- **Small PRs.** Under 200 lines of diff where possible.
- **No automated Co-Authored-By trailers.** Engineers own their work.

## Repo-specific conventions

<!-- Fill this in. Examples:
- Package manager: pnpm
- Test runner: `pnpm test`
- Deployment: GitHub Actions, triggered on tag push
- Secrets: managed via 1Password, never checked in
-->

## See also

- README.md
- Claude Code documentation: https://docs.anthropic.com/en/docs/claude-code
```

## Why AGENTS.md (and not CLAUDE.md)?

`CLAUDE.md` is Claude-Code-specific — it's loaded automatically by the Claude Code CLI as context. `AGENTS.md` is the vendor-neutral equivalent: any coding agent (Aider, Cursor, Copilot, Codex, etc.) can be configured to read it. If you have both, keep them thin and coherent; CLAUDE.md can `@import` from AGENTS.md to avoid duplication.

The portability matters because agents rotate. Teams using three different coding agents across three sessions benefit from one source of truth that each tool respects.

## Periodic audit checklist

- Is AGENTS.md under ~100 lines?
- Does it duplicate what `CONTRIBUTING.md` / `README.md` already say?
- Are the test / deploy commands current?
- Are the "repo-specific conventions" actually specific — or could they be dropped as universal practices?
- Any agent-vendor references baked in (e.g., "use Claude's Task tool") that wouldn't apply to other agents? Consider factoring those to `CLAUDE.md` or similar.

## Common anti-patterns

- **Empty AGENTS.md just to pass a presence check.** Worse than absent — now it's a dead file the agent will load every turn.
- **Vendor-specific tool names in AGENTS.md.** Keep those in `CLAUDE.md` (or `.aider.conf`, `.cursorrules`, etc.) so AGENTS.md stays portable.
- **Duplicating project/ conventions in AGENTS.md.** If avanti owns the `project/` layout, AGENTS.md just points at `project/README.md` rather than re-explaining it.

## Presence check pronto uses

Pronto's kernel presence check for this dimension is: `AGENTS.md` exists at repo root with ≥5 non-blank lines. The dimension is kernel-owned — source `kernel-owned` in the report, scoring directly from the kernel-check category (0 or 100, no presence cap).

## Concrete first step

Copy the "Minimum viable AGENTS.md" block above into your repo, fill in the "Repo-specific conventions" section with the three commands an arrival really needs (test, build, deploy), and commit. Takes five minutes, passes the dimension outright.
