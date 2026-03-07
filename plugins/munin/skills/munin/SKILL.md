---
name: munin
description: Memory intelligence — setup memory awareness, deep recall across all memory layers
---

# Munin: Memory Intelligence

You are the Munin orchestrator. When the user runs `/munin`, determine the subcommand and execute accordingly.

## Subcommands

### `/munin setup`

Configure memory repo path and plant awareness rules.

#### Step 1: Check Existing Config

Check if `~/.config/munin/config` exists. If it does:
- Read it and show the current `MUNIN_REPO` value
- Ask: "Munin is already configured. Reconfigure?" (AskUserQuestion, single-select: Yes / No)
- If No, stop

#### Step 2: Find Memory Repo Path

Check if `~/.config/bifrost/config` exists:
- If yes: read it, extract the repo path, and offer it as default:
  "Found Bifrost config pointing to `<path>`. Use the same repo?" (AskUserQuestion, single-select: Yes / Enter a different path)
  - If "Enter a different path": ask for the path (AskUserQuestion, text)
- If no: ask for the memory repo path (AskUserQuestion, text):
  "Enter the path to your memory repo (the directory containing MEMORY.md):"

#### Step 3: Validate

Confirm the path:
1. Directory exists — if not: "Directory not found: `<path>`"
2. Contains `MEMORY.md` — if not: "No MEMORY.md found in `<path>`. Is this the right directory?"

If validation fails, ask for the path again.

#### Step 4: Write Config

Create `~/.config/munin/` if needed, then write `~/.config/munin/config`:

```
MUNIN_REPO=<path>
```

#### Step 5: Choose Rules Scope

Ask where to plant the rules file (AskUserQuestion, single-select):
- **Global (recommended)** — `~/.claude/rules/munin.md` — active in all projects
- **Project only** — `.claude/rules/munin.md` — active only in current project

#### Step 6: Write Rules File

Write the rules file to the chosen location with the repo path baked in:

```markdown
# Munin: Memory Awareness

You have persistent memory stored at `<MUNIN_REPO>`.

## Session Start

At the beginning of any substantive task (not trivial lookups), read
`<MUNIN_REPO>/MEMORY.md`. This contains your stable knowledge: identity,
preferences, active projects, technical environment, and key people.

## Memory Layers

| Layer | Path | Use |
|-------|------|-----|
| Core memory | `<MUNIN_REPO>/MEMORY.md` | Stable facts — read first |
| Procedures | `<MUNIN_REPO>/procedures/` | Learned workflows — check when doing multi-step tasks |
| Journal | `<MUNIN_REPO>/journal/` | Recent events and decisions — grep for temporal context |
| Context trees | `<MUNIN_REPO>/context-trees/` | Project status and relationships |

## When to Recall

Before planning or making decisions that could benefit from historical context:
- Use Read on MEMORY.md for quick reference
- Use Grep on `journal/` and `procedures/` for specific topics
- For deep searches across all layers, use `/munin recall <topic>`

## Corrections

When the user corrects you about something memory should know, note the
correction explicitly: "Noted correction: <what changed>." This flags it
for future consolidation.

## Constraints

- Memory files are **read-only during sessions** — never edit them directly
- Don't recite memory to the user — use it silently to inform your behavior
```

#### Step 7: Report Success

```
Munin configured successfully.
──────────────────────────────
Memory repo: <path>
Rules file:  <location>
Config:      ~/.config/munin/config

Claude will now read MEMORY.md at the start of substantive tasks.
Use /munin recall <topic> for deep memory search.
```

---

### `/munin recall <topic>`

Deep search across all memory layers for a given topic.

#### Step 1: Load Config

Read `~/.config/munin/config` to get `MUNIN_REPO`. If the file doesn't exist:
"Munin is not configured. Run `/munin setup` first."

#### Step 2: Validate Repo

Check that `MUNIN_REPO` directory exists and contains `MEMORY.md`. If not:
"Memory repo not found at `<path>`. Run `/munin setup` to reconfigure."

#### Step 3: Dispatch Recall Agent

Spawn the recall agent:

```
Agent:
  description: "Recall <topic>"
  subagent_type: "munin:recall"
  prompt: |
    Search for information about: <topic>

    Memory repo path: <MUNIN_REPO>

    Read the memory structure reference at ${CLAUDE_PLUGIN_ROOT}/skills/munin/references/memory-structure.md first.
```

#### Step 4: Present Results

Show the agent's structured summary to the user. Don't add commentary — the agent's output is the result.

---

### `/munin` (no subcommand)

Show available subcommands:

```
Munin — Memory Intelligence
──────────────────────────────
/munin setup      Configure memory repo and plant awareness rules
/munin recall Q   Deep search across all memory layers for topic Q
```
