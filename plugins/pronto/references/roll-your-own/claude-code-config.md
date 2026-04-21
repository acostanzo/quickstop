# Roll Your Own — Claude Code Config Health

How to achieve the `claude-code-config` dimension's readiness without installing `claudit`.

The recommended path is `/plugin install claudit@quickstop`. This document covers the manual equivalent. You give up automated audit runs and the knowledge cache, but you keep full control.

## What "healthy" looks like

- A `CLAUDE.md` or `AGENTS.md` at the repo root that tells an agent (a) what the project is, (b) how to run tests, (c) how commits are structured, (d) where to find more detail. Under 50 lines if possible.
- A `.claude/settings.json` (or `settings.local.json`) with explicit permission mode — not the default `plan` mode in perpetuity.
- Skills, agents, hooks used only where they do something the built-in behavior doesn't already cover.
- No duplicate instructions between `CLAUDE.md` and `.claude/rules/*.md` or between project config and `~/.claude/`.
- No MCP servers that aren't reachable, aren't used, or duplicate a built-in tool.

## Minimum viable setup

```bash
mkdir -p .claude
touch CLAUDE.md
cat > .claude/settings.json <<'JSON'
{
  "permissions": {
    "allow": ["Read(*)", "Glob(*)", "Grep(*)", "Bash(pnpm test:*)"]
  }
}
JSON
```

Then write `CLAUDE.md` with the five questions an agent arrives with:

1. What is this project?
2. What language / framework / runtime?
3. How do I run tests?
4. What conventions matter? (commits, branches, PRs)
5. Where do I find the rest?

Answer each in 1–3 sentences. Link to details rather than inlining.

## Periodic audit checklist

Run this every month or after material config changes:

- `CLAUDE.md` still under ~50 lines? Anything duplicated from default Claude behavior?
- `.claude/settings.json` permissions still match the actual workflow? Any rule that fires 0 times per month?
- `.claude/rules/*.md` — any rule with stale path frontmatter (glob matches nothing)?
- Are you still using every skill in `.claude/skills/`? Every agent in `.claude/agents/`?
- MCP servers: each one reachable? Each one still used?
- Hooks: each fires on something meaningful? Any that duplicate a feature Claude now ships natively?
- `~/.claude/CLAUDE.md` — anything project-specific leaked there? Move it.

## Common anti-patterns

- **Restating Claude's built-in behavior in `CLAUDE.md`.** "Use the Read tool to read files" is dead weight.
- **One-off rules that never trigger.** A rule that's only useful once belongs in a comment at the call site, not a persistent instruction.
- **Hooks that duplicate commit-message enforcement.** Pre-commit hooks should be in `.git/hooks/` or a hook manager like Lefthook, not Claude's hook system — unless the hook is specifically about Claude's tool calls.
- **MCP sprawl.** Every server adds tokens to every turn. Three MCPs that each solve one narrow problem are worse than one MCP that solves a category.

## Presence check pronto uses

Pronto's kernel presence check for this dimension is the existence of a `.claude/` directory. That caps the score at 50 until you install `claudit` or reach the same depth manually. There is no way for pronto-without-claudit to know the difference between a healthy `.claude/` and a neglected one — the depth measurement is what's delegated.

## Concrete first step

If you don't have `CLAUDE.md` yet: create it now with a five-question skeleton and fill it in. That alone bumps this dimension from `presence-cap:50` territory to real config-health territory once you install a sibling auditor — or, to a perceived baseline if you stay roll-your-own.
