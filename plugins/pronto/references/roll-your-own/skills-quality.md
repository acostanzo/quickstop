# Roll Your Own — Skills Quality

How to achieve the `skills-quality` dimension's readiness without installing `skillet`.

The recommended path is `/plugin install skillet@quickstop`. This document covers the manual equivalent. You give up the scoring rubric and the audit loop, but you can still hand-author skills that hold up to the same standard.

## What "good" looks like

A skill directory under `.claude/skills/<name>/` or `plugins/<plugin>/skills/<name>/` with:

- **`SKILL.md`** that carries correct YAML frontmatter — `name`, `description`, optional `disable-model-invocation`, optional `argument-hint`, `allowed-tools` (scoped to what the skill actually needs, not the full universe).
- **A single, clear purpose.** Anything that tries to be "the general-purpose helper" is too broad.
- **Phased instructions** when the skill is non-trivial. A skill that does five things in sequence writes them as five phases, not one mushy narrative.
- **Research-first architecture** when the skill operates against a moving target (docs, specs, APIs). Dispatch a research agent, cache the result, use the result.
- **Tool allowance scoped to need.** If the skill only reads and greps, don't allow Write/Edit/Bash.

## Frontmatter skeleton

```yaml
---
name: <kebab-case>
description: <one sentence — what it does, for whom, when>
disable-model-invocation: true
argument-hint: "<optional-syntax-hint>"
allowed-tools: Read, Glob, Grep
---
```

- `description` should be specific enough that Claude can decide when to invoke the skill. "Help with code" is useless; "Refactor a file using safe rename across cross-file references" is usable.
- `disable-model-invocation: true` means the skill only runs on explicit user invocation (`/<plugin>:<skill>`). Default it to `true` unless you *want* Claude auto-invoking the skill heuristically.
- `allowed-tools` is the allowlist of tool names the skill body may call. Keep it tight.

## Directory conventions

```
skills/
└── my-skill/
    ├── SKILL.md
    ├── references/             # heavy docs loaded on demand
    │   └── schema.md
    └── agents/                 # skill-scoped subagents (rare)
        └── helper.md
```

- One skill per directory. Subdir name becomes the skill name.
- `references/` for anything that would bloat SKILL.md — schemas, long reference tables, domain primers.
- `agents/` only if the skill dispatches its own subagents and they're clearly skill-scoped (not reusable across the plugin).

## Periodic audit checklist

For each skill:

- Does the `description` accurately capture when to invoke it, or is it aspirational?
- Is `allowed-tools` tighter than "the full list"?
- Does the body reference files that no longer exist?
- Are there sections of the body that describe "what the skill does" that duplicate `description`?
- Is there a research phase that should cache to `~/.cache/<plugin>/` instead of re-fetching each run?

## Common anti-patterns

- **Kitchen-sink skills.** A skill that does five unrelated things is five skills.
- **Implicit shelling to external binaries.** If the skill needs `gh`, `jq`, or a custom script, declare it in a precondition block — don't `Bash` your way into a traceback.
- **Model-invocation unset.** Without `disable-model-invocation: true`, Claude may auto-invoke the skill when the description partially matches — usually unwanted.
- **Copy-pasted boilerplate across skills.** If three skills share a preamble, extract it into a reference file and link.

## Presence check pronto uses

Pronto's kernel presence check for this dimension passes if at least one `SKILL.md` exists under `.claude/skills/`, `plugins/*/skills/`, or `~/.claude/skills/`. Presence-cap is 50 until a depth auditor (skillet or a hand-audit) confirms the skills are any good.

## Concrete first step

Pick the most useful shell alias you have and convert it to a skill. The conversion exercise surfaces almost every convention listed above — frontmatter, tool scoping, description specificity — and leaves you with one skill that's audit-ready.
