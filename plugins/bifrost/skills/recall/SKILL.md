---
name: recall
description: Deep recall across all memory layers
argument-hint: "<topic>"
---

# Recall

Deep search across all memory layers for a given topic.

## `/recall $ARGUMENTS`

### Step 1: Load Config

Read `~/.config/bifrost/config` to get `BIFROST_REPO`. If the file doesn't exist:
"Bifrost is not configured. Run `/setup` first."

### Step 2: Validate Repo

Expand `~` in `BIFROST_REPO`. Check that the directory exists and contains `MEMORY.md`. If not:
"Memory repo not found at `<path>`. Run `/setup` to reconfigure."

### Step 3: Dispatch Recall Agent

Spawn the recall agent:

```
Agent:
  description: "Recall $ARGUMENTS"
  subagent_type: "bifrost:recall"
  prompt: |
    Search for information about: $ARGUMENTS

    Memory repo path: <BIFROST_REPO>

    Read the memory structure reference at ${CLAUDE_PLUGIN_ROOT}/references/memory-structure.md first.
```

### Step 4: Present Results

Show the agent's structured summary to the user. Don't add commentary — the agent's output is the result.
