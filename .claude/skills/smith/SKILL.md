---
name: smith
description: Scaffold a new Quickstop plugin with correct structure and conventions
disable-model-invocation: true
argument-hint: plugin-name
allowed-tools: Task, Read, Glob, Grep, Bash, Write, Edit, WebSearch, WebFetch, AskUserQuestion
---

# Smith: Plugin Scaffolder

You are the Smith orchestrator. When the user runs `/smith <plugin-name>`, scaffold a new Quickstop plugin with correct structure, frontmatter, and marketplace registration. Follow each phase in order.

> **Human-driven by design (Q3 §U1).** Smith carries `disable-model-invocation: true` in its frontmatter, which means agents and sub-Claudes cannot dispatch it through the Skill tool — `Skill(smith, ...)` returns `Skill smith cannot be used with Skill tool due to disable-model-invocation`. This is intentional, not an oversight. Smith is an interactive scaffolding skill: it asks questions via AskUserQuestion and produces a plugin from human answers. Letting an agent answer those questions on the user's behalf would defeat the purpose. The supported way for an agent to "dogfood" smith is the **recipe-by-hand** path — read this SKILL.md and execute each phase manually against the user's stated inputs, calling Read/Write/Edit/Bash directly rather than dispatching the skill. The 2b1 lintguini dogfood used exactly this path; Q3's U1 finding is the precedent.

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
Phase 1: Building expert context from official plugin documentation...
```

---

## Phase 1: Build Expert Context

### Step 1: Load Expert Context

Invoke `/claudit:knowledge ecosystem` to retrieve ecosystem knowledge.

**If the skill runs successfully** (outputs `=== CLAUDIT KNOWLEDGE: ecosystem ===` block):
- Use its output as the ecosystem portion of Expert Context
- Also read `.claude/skills/smith/references/plugin-spec.md` for plugin-authoring-specific detail (plugin.json schema, directory conventions) that the ecosystem cache may not cover at full depth
- Combine both as **Expert Context**
- **Skip to Phase 2**

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
Expert context assembled. Gathering requirements...
```

---

## Phase 2: Gather Requirements

Use AskUserQuestion for each question. Skip questions that don't apply based on previous answers.

> **Hook-mention detection.** Track whether the user has typed the word "hook" (case-insensitive) in any free-text answer. If detected for the first time, prepend the migration note to the next prompt (see top of this file). Only once — don't repeat.

### Question 1: Description
"What does this plugin do? (1-2 sentence description)"

### Question 2: Plugin Role
Use AskUserQuestion with options:
"What role does this plugin play?"
- **Tool plugin** — a stand-alone command/skill set (most plugins: claudit, towncrier, smith itself)
- **Pronto sibling** — audits a pronto rubric dimension; produces a wire-contract JSON envelope on `/<name>:audit --json`

Set `IS_SIBLING=true` if the user selects "Pronto sibling".

### Question 3: License
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

### Question 4: Sibling Dimension (if IS_SIBLING)
Read `plugins/pronto/references/recommendations.json`. Extract each key from `.recommendations` and present the `dimension_label` values as options, plus an escape hatch.

Use AskUserQuestion:
"Which pronto rubric dimension does this sibling audit?

(Options sourced from `plugins/pronto/references/recommendations.json`)"
- [One option per dimension from the JSON, displaying `dimension_label`]
- **Other (non-canonical)** — *Warning: pronto won't recognize this dimension automatically.*

Set `SIBLING_DIMENSION` to the slug of the chosen dimension (the JSON key, e.g. `code-documentation`), or to the user's custom string if "Other".

If "Other", warn: "Non-canonical dimensions are not in pronto's rubric. The sibling will scaffold correctly but pronto won't discover it automatically until the dimension is registered in `recommendations.json`."

### Question 5: Components
Use AskUserQuestion with options to ask:
"What components does this plugin need?"
Options (allow multiple selections):
- Skills (slash commands)
- Agents (sub-agents for parallel work)
- MCP servers (external tool integration)
- Reference files (heavy docs/schemas loaded on demand)

Note: hooks are not an option. If the user types "hooks" in the free-text follow-up, surface the migration note.

### Question 6: Skills (if selected)
"List the skills this plugin needs. For each, provide a name and brief description. Format: `name: description` (one per line)"

Note: if IS_SIBLING, an `audit` skill will be auto-created from the wire-contract template (even if not listed here) — you don't need to list it separately.

### Question 7: Agents (if selected)
"List the agents this plugin needs. For each, provide a name and brief description. Format: `name: description` (one per line)"

Note: if IS_SIBLING, a transitional parser agent `parse-<name>` will be auto-created.

### Question 8: Agent Model (if agents selected)
Use AskUserQuestion with options:
"What model should agents default to?"
- `haiku` — fast and cheap, good for research/fetch tasks
- `inherit` — use parent's model, good for analysis tasks
- `sonnet` — balanced, good for complex analysis

### Question 9: Keywords
"What keywords describe this plugin? (comma-separated, for marketplace discovery)"

---

## Phase 3: Scaffold

Using Expert Context and the user's answers, create all files. Use the official spec from Expert Context to ensure correct frontmatter and structure.

### Phase 3.0: Hook Surface (ADR-006 §3 boundary)

Smith does **not** scaffold a `hooks/` directory or `hooks/hooks.json`. This is the load-bearing non-default — authors who need a pure-observability hook surface follow towncrier's pattern by hand.

If the user mentioned hooks anywhere in Phase 2, note this once in Phase 5 as a "next steps" reminder. Do not create any file under `hooks/`.

### 3.1: plugin.json

Create `plugins/<name>/.claude-plugin/plugin.json`.

**For role = tool:**
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

**For role = sibling:**

Read `plugins/pronto/.claude-plugin/plugin.json` → extract `version` as `PRONTO_VERSION`.
Read `plugins/pronto/references/rubric.md` → find the row for `SIBLING_DIMENSION`, extract its weight integer, divide by 100 → `WEIGHT_HINT` (e.g. `15` → `0.15`). If parsing fails, omit `weight_hint`.

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
  "keywords": [<user's keywords>],
  "pronto": {
    "compatible_pronto": ">=<PRONTO_VERSION>",
    "audits": [
      {
        "dimension": "<SIBLING_DIMENSION>",
        "command": "/<name>:audit --json",
        "weight_hint": <WEIGHT_HINT>
      }
    ]
  }
}
```

**License field handling:**
- MIT → `"license": "MIT"`
- Apache-2.0 → `"license": "Apache-2.0"`
- No LICENSE → omit the `license` field entirely
- Other → `"license": "<SPDX-identifier>"` if one was given, otherwise omit

### 3.2: Skills (user-listed)

For each skill the user listed that is NOT `audit` (or not a sibling), create `plugins/<name>/skills/<skill-name>/SKILL.md`:

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

### 3.2a: skills/audit/SKILL.md (sibling only, auto-created)

When IS_SIBLING, always create `plugins/<name>/skills/audit/SKILL.md` with the wire-contract emission shape. If the user listed `audit` as a skill in Question 6, this template supersedes the generic TODO stub.

```yaml
---
name: audit
description: Audit the `<SIBLING_DIMENSION>` dimension in a target codebase
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash
argument-hint: --json
---
```

Body (the skill emits this wire-contract-valid JSON envelope on stdout when invoked with `--json`):

~~~markdown
# <Name>:audit

Audit the target codebase for <SIBLING_DIMENSION_LABEL> and emit a v2 wire-contract envelope.

## Output

Emit exactly one JSON object to stdout:

```json
{
  "$schema_version": 2,
  "plugin": "<name>",
  "dimension": "<SIBLING_DIMENSION>",
  "categories": [],
  "observations": [],
  "composite_score": null,
  "recommendations": []
}
```

<!-- TODO: Fill in `observations[]` entries when scorers are wired up. Until then,
the empty array exercises the translator's case-3 passthrough — the dimension scores
by presence-only fallback. Each observation needs: id (stable string), kind (ratio |
count | presence | score), evidence (object), summary (string). See
plugins/pronto/references/sibling-audit-contract.md for the full field reference. -->
~~~

### 3.3: Agents (user-listed)

For each agent the user listed (excluding the auto-created `parse-<name>` for siblings), create `plugins/<name>/agents/<agent-name>.md`:

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

### 3.3a: Transitional parser agent (sibling only, auto-created)

When IS_SIBLING, create `plugins/<name>/agents/parse-<name>.md`:

```yaml
---
name: parse-<name>
description: "Transitional parser agent for <name>. Forwards /<name>:audit --json output to pronto unchanged. Remove after step-1 discovery verifies in production."
deprecated: true
tools:
  - Bash
model: haiku
---
```

Body:

~~~markdown
# Parser Agent: <name> (transitional)

<!-- Transitional. Satisfies ADR-005 §5 step-2 discovery while the audit ramps up;
remove after step-1 discovery (plugins/<name>/skills/audit/SKILL.md) verifies in
production. When /<name>:audit --json is confirmed stable, delete this file and
remove the matching parser entry from plugins/pronto/references/recommendations.json
(if one exists). -->

You are a pass-through parser agent. Your only job is to forward the output of
`/<name>:audit --json` to the caller unchanged. Do not interpret, summarize, or
restructure the output.

## Inputs

From the dispatching prompt:

- `REPO_ROOT` — absolute repo-root path.

## What to do

Run exactly one Bash command and print its stdout verbatim as your final message:

```bash
# Invoke the native audit skill (step-1 path)
# This agent exists only until step-1 discovery is confirmed stable in production.
echo "Passthrough: invoke /<name>:audit --json against ${REPO_ROOT}"
```

<!-- TODO: Replace the echo above with the actual invocation once the audit skill
is wired up. Until then, this agent satisfies the step-2 registration requirement
from ADR-005 §5. -->

## Output

Exactly one JSON object — whatever `/<name>:audit --json` emits. No prose, no
markdown fences, no leading or trailing text.
~~~

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

Create `plugins/<name>/README.md`. Every plugin, whether tool or sibling, opens with a **"Plugin surface"** section per ADR-006 §1.

~~~markdown
# <Name>

<description>

## Plugin surface

This plugin ships:
- Skills: <list from Question 6 — include `audit` for siblings; "none" if empty>
- Commands: <list, or "none">
- Agents: <list from Question 7 — include `parse-<name>` for siblings; "none" if empty>
- Hooks: none
- Opinions: <reference files and rules, or "none">

This plugin does not ship: cross-plugin automation, consumer config edits, or any
flow that silently mutates artefacts the consumer owns. Consumers compose automation
against this plugin's capabilities per ADR-006 §6.
~~~

**For sibling plugins**, append after the Plugin surface section:

~~~markdown
## What this sibling audits

This plugin audits the **<SIBLING_DIMENSION_LABEL>** dimension of pronto's readiness rubric.

## Standalone invocation

```bash
/<name>:audit --json
```

Emits a v2 wire-contract JSON envelope to stdout. The `observations[]` field
carries entries pronto's rubric translates into a dimension score.

## Pronto handshake

This plugin declares `compatible_pronto: ">=<PRONTO_VERSION>"` in `plugin.json`.
Pronto checks this at dispatch time — if the installed pronto is outside the declared
range, pronto skips this sibling's audit and scores the dimension by presence only.
~~~

Then for all plugins, add:

~~~markdown
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

Read `.claude-plugin/marketplace.json`, add a new entry to the `plugins` array:

```json
{
  "name": "<name>",
  "version": "0.1.0",
  "description": "<description>",
  "source": "./plugins/<name>",
  "keywords": [<user's keywords>]
}
```

Use Edit to add the entry — do not overwrite the entire file.

### 4.2: Root README

Read `README.md` and add a new plugin section following the existing format (look at Claudit and Skillet entries for the pattern). Add as the last plugin entry.

---

## Phase 5: Summary

Present the created files:

```
=== SMITH COMPLETE ===
Plugin: <name> v0.1.0
Role: <Tool plugin | Pronto sibling (dimension: <SIBLING_DIMENSION>)>
License: <MIT | Apache-2.0 | No LICENSE | Other>

Created:
  plugins/<name>/.claude-plugin/plugin.json
  plugins/<name>/skills/<skill>/SKILL.md        (per user-listed skill)
  plugins/<name>/skills/audit/SKILL.md          (sibling: auto-created)
  plugins/<name>/agents/<agent>.md               (per user-listed agent)
  plugins/<name>/agents/parse-<name>.md          (sibling: transitional parser)
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
  3. If sibling: wire up observations[] in skills/audit/SKILL.md
  4. If sibling: run /hone <name> to verify Pronto Compliance ≥85
  5. Test: claude --plugin-dir plugins/<name>
  6. Run ./scripts/check-plugin-versions.sh to verify versions
  7. Bump to v1.0.0 when ready for release
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
- If `plugins/pronto/references/recommendations.json` can't be read for the Sibling Dimension question, present a text input instead of a list
- If `plugins/pronto/references/rubric.md` can't be parsed for the weight hint, omit `weight_hint` from `plugin.json` (do not block scaffolding)
- Never leave a half-scaffolded plugin — if a critical step fails, clean up created files
