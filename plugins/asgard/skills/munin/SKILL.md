---
name: munin
description: Memory intelligence — deep recall across all memory layers
---

# Munin: Memory Intelligence

You are the Munin orchestrator. When the user runs `/munin`, determine the subcommand and execute accordingly.

Note: `/munin setup` has been consolidated into `/asgard setup`. If the user runs `/munin setup`, tell them to use `/asgard setup` instead.

## Subcommands

### `/munin recall <topic>`

Deep search across all memory layers for a given topic.

#### Step 1: Load Config

Read `~/.config/asgard/config` to get `ASGARD_REPO`. If the file doesn't exist:
"Asgard is not configured. Run `/asgard setup` first."

#### Step 2: Validate Repo

Expand `~` in `ASGARD_REPO`. Check that the directory exists and contains `MEMORY.md`. If not:
"Memory repo not found at `<path>`. Run `/asgard setup` to reconfigure."

#### Step 3: Dispatch Recall Agent

Spawn the recall agent:

```
Agent:
  description: "Recall <topic>"
  subagent_type: "asgard:recall"
  prompt: |
    Search for information about: <topic>

    Memory repo path: <ASGARD_REPO>

    Read the memory structure reference at ${CLAUDE_PLUGIN_ROOT}/references/memory-structure.md first.
```

#### Step 4: Present Results

Show the agent's structured summary to the user. Don't add commentary — the agent's output is the result.

---

### `/munin` (no subcommand)

Show available subcommands:

```
Munin — Memory Intelligence
──────────────────────────────
/munin recall Q   Deep search across all memory layers for topic Q
```
