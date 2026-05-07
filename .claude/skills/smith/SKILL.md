---
name: smith
description: Scaffold a new Quickstop plugin with correct structure and conventions
disable-model-invocation: true
argument-hint: plugin-name
allowed-tools: Task, Read, Glob, Grep, Bash, Write, Edit, WebSearch, WebFetch, AskUserQuestion
---

# Smith: Plugin Scaffolder

You are the Smith orchestrator. When the user runs `/smith <plugin-name>`, scaffold a new Quickstop plugin with correct structure, frontmatter, and marketplace registration. Follow each phase in order.

> **Human-driven by design.** Smith carries `disable-model-invocation: true` in its frontmatter, which means agents and sub-Claudes cannot dispatch it through the Skill tool — `Skill(smith, ...)` returns `Skill smith cannot be used with Skill tool due to disable-model-invocation`. This is intentional, not an oversight. Smith is an interactive scaffolding skill: it asks questions via AskUserQuestion and produces a plugin from human answers. Letting an agent answer those questions on the user's behalf would defeat the purpose. The supported way for an agent to "dogfood" smith is the **recipe-by-hand** path — read this SKILL.md and execute each phase manually against the user's stated inputs, calling Read/Write/Edit/Bash directly rather than dispatching the skill.

> **Hook note (ADR-006 §3).** Smith does not scaffold a `hooks/` directory. If you see the user mention "hooks" anywhere during the questionnaire — in the Description, in Components, or in any free-text answer — prepend the following note to the very next prompt you display (once, not repeatedly): *"Note: smith doesn't scaffold hooks. See ADR-006 §3 / towncrier `bin/emit.sh` for the by-hand pattern."* Then continue normally.

## Phase 0: Validation

### Step 1: Parse Plugin Name

Extract the plugin name from `$ARGUMENTS`. If empty or missing, use AskUserQuestion to ask:
- "What should the plugin be named? (kebab-case, e.g. `my-plugin`)"

### Step 2: Validate Name

1. **Kebab-case**: Name must match `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`. If not, reject and ask for a valid name.
2. **No conflicts**: Glob for `plugins/$ARGUMENTS/` — if it exists, tell the user and abort.
3. **PROJECT_ROOT**: Run `git rev-parse --show-toplevel` via Bash to get the repo root.

Tell the user:
```
Scaffolding plugin: <name>
Gathering requirements...
```

---

## Phase 1: Build Expert Context (lazy)

> **Default: skip this phase.** Phase 1's output rarely influences the scaffolded files for a standard plugin — Phase 3's templates contain no Expert-Context substitution slots. Substitutions come from user answers (Phase 2); none flow from Expert Context. The expert-context fanout is a defensive measure, sunk cost on the standard path.
>
> Run Phase 1 only when one of the trigger conditions below fires during Phase 2, and then run it **between Phase 2 and Phase 3** (not before Phase 2 — you need the questionnaire answers to know whether a trigger applies). For the common case, jump straight from Phase 0 to Phase 2.

### Trigger conditions

Run Phase 1 if any of these surface during Phase 2:

- **A free-text answer (description, component follow-up, skill/agent descriptions) names a capability the templates don't cover** — e.g. hook-only plugins (smith doesn't scaffold hooks; redirect to towncrier's pattern), LSP/monitor servers, or anything outside the Skills / Agents / MCP / References component classes the questionnaire lists. Load Expert Context if you're unsure how to scaffold the request.
- **You explicitly need to verify frontmatter details that aren't already in `.claude/skills/smith/references/plugin-spec.md`** — e.g. a recently-added `claude-plugin/plugin.json` field. Lean conservative: when in doubt, load.

If none of these fire, skip directly to Phase 3.

### Step 1: Load Expert Context (only if a trigger fired)

Invoke `/claudit:knowledge ecosystem` to retrieve ecosystem knowledge.

**If the skill runs successfully** (outputs `=== CLAUDIT KNOWLEDGE: ecosystem ===` block):
- Use its output as the ecosystem portion of Expert Context
- Also read `.claude/skills/smith/references/plugin-spec.md` for plugin-authoring-specific detail (plugin.json schema, directory conventions) that the ecosystem cache may not cover at full depth
- Combine both as **Expert Context**
- Continue to Phase 3

**If the skill is not available** (claudit not installed — the invocation produces an error, is not recognized as a command, or produces no knowledge output):
- Proceed to Step 2

### Step 2: Dispatch Research Agents (Fallback)

Dispatch **2 research subagents in parallel** using the Task tool. Both must be foreground.

In a single message, dispatch both Task tool calls:

**Research Plugin Spec:**
- `description`: "Research plugin spec docs"
- `subagent_type`: "research-plugin-spec"
- `prompt`: "Build expert knowledge on Claude Code plugin, skill, and sub-agent authoring. Read the baseline from .claude/skills/smith/references/plugin-spec.md first, then fetch official Anthropic documentation. Return structured expert knowledge including any Quickstop Conventions section from your research."

**Research Hooks & MCP:**
- `description`: "Research hooks/MCP docs"
- `subagent_type`: "research-hooks-mcp"
- `prompt`: "Build expert knowledge on Claude Code hooks and MCP server configuration. Fetch official Anthropic documentation. Return structured expert knowledge."

### Assemble Expert Context

Once both return, combine their results:

```
=== EXPERT CONTEXT ===

## Plugin System Knowledge
[Results from research-plugin-spec]

## Hooks & MCP Knowledge
[Results from research-hooks-mcp]

=== END EXPERT CONTEXT ===
```

Tell the user:
```
Expert context assembled. Continuing to scaffold...
```

---

## Phase 2: Gather Requirements

Use AskUserQuestion for each question. Skip questions that don't apply based on previous answers.

> **Hook-mention detection.** Track whether the user has typed the word "hook" (case-insensitive) in any free-text answer. If detected for the first time, prepend the migration note to the next prompt (see top of this file). Only once — don't repeat.

### Question 1: Description
"What does this plugin do? (1-2 sentence description)"

### Question 2: License
Use AskUserQuestion with options (pre-highlight MIT for marketplace plugins, No LICENSE for internal use — pre-highlighting is a UX hint, not a silent default; the user must affirm):

"Which license should this plugin carry?

Decision guide (from `.claude/rules/license-selection.md`):
• MIT — marketplace plugins; maximises adoption, no patent clause (recommended for plugins under `plugins/`)
• Apache-2.0 — projects with patent concerns or core developer tooling
• No LICENSE — internal/private; plugin not intended for marketplace
• Other — BSD, AGPL, etc. (you will paste the SPDX identifier or full text)

Options:"
- **MIT** (recommended for marketplace plugins)
- **Apache-2.0**
- **No LICENSE** (internal/private)
- **Other** — ask for SPDX identifier or path

Set `LICENSE_CHOICE` to the user's answer. If "Other", ask a follow-up: "Provide the SPDX identifier (e.g. `BSD-3-Clause`) or the full license text."

### Question 3: Components

Use AskUserQuestion:

"What components does this plugin need?"

Options (allow multiple selections):
- Skills (slash commands)
- Agents (sub-agents for parallel work)
- MCP servers (external tool integration)
- Reference files (heavy docs/schemas loaded on demand)

Note: hooks are not an option. If the user types "hooks" in the free-text follow-up, surface the migration note.

### Question 4: Skills

Ask only if Q3 selected Skills:

"List the skills this plugin needs. For each, provide a name and brief description. Format: `name: description` (one per line)"

### Question 5: Agents

Ask only if Q3 selected Agents:

"List the agents this plugin needs. For each, provide a name and brief description. Format: `name: description` (one per line)"

### Question 6: Agent Model (if agents selected)
Use AskUserQuestion with options:
"What model should agents default to?"
- `haiku` — fast and cheap, good for research/fetch tasks
- `inherit` — use parent's model, good for analysis tasks
- `sonnet` — balanced, good for complex analysis

### Question 7: Keywords
"What keywords describe this plugin? (comma-separated, for marketplace discovery)"

---

## Phase 3: Scaffold

Using the user's answers, create all files according to the templates below. The templates are self-contained — every substitution slot is filled from a Phase 2 answer or `date +%Y`. If Phase 1 was triggered, also use Expert Context to verify any frontmatter details the templates don't already cover.

### 3.0: Hook Surface (ADR-006 §3 boundary)

Smith does **not** scaffold a `hooks/` directory or `hooks/hooks.json`. This is the load-bearing non-default — authors who need a pure-observability hook surface follow towncrier's pattern by hand.

If the user mentioned hooks anywhere in Phase 2, note this once in Phase 5 as a "next steps" reminder. Do not create any file under `hooks/`.

### 3.1: plugin.json

Create `plugins/<name>/.claude-plugin/plugin.json`:

```json
{
  "name": "<name>",
  "version": "0.1.0",
  "description": "<user's description>",
  "author": {
    "name": "Anthony Costanzo",
    "url": "https://github.com/acostanzo"
  },
  "license": "<LICENSE_SPDX or omit if No LICENSE>",
  "keywords": [<user's keywords>]
}
```

**License field handling:**
- MIT → `"license": "MIT"`
- Apache-2.0 → `"license": "Apache-2.0"`
- No LICENSE → omit the `license` field entirely
- Other → `"license": "<SPDX-identifier>"` if one was given, otherwise omit

### 3.2: Skills

For each skill the user listed, create `plugins/<name>/skills/<skill-name>/SKILL.md`:

```yaml
---
name: <skill-name>
description: <user's description for this skill>
disable-model-invocation: true
allowed-tools: Task, Read, Glob, Grep, Bash, Write, Edit
---
```

Body should include:
- A header comment: `# <Skill Name>: <description>`
- A TODO section prompting the author to fill in instructions
- If the plugin has agents, include a skeleton Phase structure showing how to dispatch them

### 3.3: Agents

For each agent the user listed, create `plugins/<name>/agents/<agent-name>.md`:

```yaml
---
name: <agent-name>
description: "<user's description for this agent>"
tools:
  - Read
  - Glob
  - Grep
model: <user's chosen model>
---
```

Body should include:
- A header: `# Agent: <name>`
- A purpose section
- A TODO section for instructions
- An output format skeleton

### 3.4: MCP Config

If MCP was selected, create `plugins/<name>/.mcp.json`:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "TODO",
      "args": [],
      "env": {}
    }
  }
}
```

### 3.5: LICENSE / NOTICE files

Based on `LICENSE_CHOICE`:

**MIT:**
Create `plugins/<name>/LICENSE` (substitute `<YEAR>` with the output of `date +%Y` before writing):
~~~
MIT License

Copyright (c) <YEAR> Anthony Costanzo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
~~~
No NOTICE file.

**Apache-2.0:**
Create `plugins/<name>/LICENSE` with the canonical Apache 2.0 text (the full unmodified license text from apache.org).
Create `plugins/<name>/NOTICE` (substitute `<YEAR>` with the output of `date +%Y` before writing):
~~~
<Name>
Copyright (c) <YEAR> Anthony Costanzo

This product includes software developed by Anthony Costanzo
(https://github.com/acostanzo).
~~~

**No LICENSE:** Create neither file.

**Other:** Use the author-supplied text for `plugins/<name>/LICENSE`. No NOTICE unless the license requires it.

Use the current year from `date +%Y` in all copyright notices.

### 3.6: README

Create `plugins/<name>/README.md`. Every plugin opens with a **"Plugin surface"** section per ADR-006 §1.

~~~markdown
# <Name>

<description>

## Plugin surface

This plugin ships:
- Skills: <list from Question 4 — "none" if empty>
- Commands: <list, or "none">
- Agents: <list from Question 5 — "none" if empty>
- Hooks: none
- Opinions: <reference files and rules, or "none">

This plugin does not ship: cross-plugin automation, consumer config edits, or any
flow that silently mutates artefacts the consumer owns. Consumers compose automation
against this plugin's capabilities per ADR-006 §6.

## Installation

### From marketplace

```bash
/plugin install <name>@quickstop
```

### From source

```bash
claude --plugin-dir /path/to/quickstop/plugins/<name>
```

## Architecture

[Brief overview: N skills, N agents, etc. Fill in.]
~~~

When `license != none`, end the README with:

~~~markdown
## License

<License name>. See [LICENSE](LICENSE).
~~~

---

## Phase 4: Register

### 4.1: Marketplace Entry

Read `.claude-plugin/marketplace.json`, then use Edit to insert a new entry at the end of the `plugins` array. **Do not overwrite the entire file.**

**Anchor on the structural close, not on the last plugin's content.** The closing brace of the last plugin entry, the closing bracket of the `plugins` array, and the closing brace of the root object always appear together at the bottom of the file regardless of which plugin is currently last:

```
    }
  ]
}
```

That trailing block (4-space indent for the plugin's `}`, 2-space indent for `]`, 0-space indent for `}`) is unique in the file and survives any reordering. Use it as the Edit anchor — *not* the last plugin's `"name"` line, `"keywords"` array, or any other content that shifts every time a plugin is added.

Edit pattern:

- `old_string`:
  ```
      }
    ]
  }
  ```
- `new_string`:
  ```
      },
      {
        "name": "<name>",
        "version": "0.1.0",
        "description": "<description>",
        "source": "./plugins/<name>",
        "keywords": [<user's keywords>]
      }
    ]
  }
  ```

Note the comma added to the previous last entry's closing brace, and the new entry inserted at the same 4-space indent level as the existing entries.

### 4.2: Root README

Read `README.md` and add a new plugin section following the existing format (look at existing plugin entries for the pattern). Add as the last plugin entry.

---

## Phase 5: Summary

Present the created files:

```
=== SMITH COMPLETE ===
Plugin: <name> v0.1.0
License: <MIT | Apache-2.0 | No LICENSE | Other>

Created:
  plugins/<name>/.claude-plugin/plugin.json
  plugins/<name>/skills/<skill>/SKILL.md        (per user-listed skill)
  plugins/<name>/agents/<agent>.md               (per user-listed agent)
  plugins/<name>/.mcp.json                       (if MCP selected)
  plugins/<name>/LICENSE                         (if MIT or Apache-2.0)
  plugins/<name>/NOTICE                          (if Apache-2.0)
  plugins/<name>/README.md

Registered:
  .claude-plugin/marketplace.json   ✓
  README.md                         ✓

Next steps:
  1. Fill in skill instructions (the TODO sections)
  2. Fill in agent instructions
  3. Test: claude --plugin-dir plugins/<name>
  4. Run ./scripts/check-plugin-versions.sh to verify versions
  5. Bump to v1.0.0 when ready for release
=== END ===

If the user mentioned hooks during the questions, append this note to the report:

  Note: hooks were mentioned during scaffolding but are not scaffolded.
        See ADR-006 §3 and towncrier bin/emit.sh for the by-hand pattern.

Otherwise omit the note entirely.
```

---

## Error Handling

- If a research agent fails, continue with the local baseline from `plugin-spec.md`
- If file creation fails, report the error and continue with remaining files
- If marketplace.json can't be read, create the entry and tell the user to add it manually
- Never leave a half-scaffolded plugin — if a critical step fails, clean up created files
