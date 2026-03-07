# Munin

Memory intelligence plugin — makes Claude memory-aware during sessions.

Named after Odin's raven of memory: flies out, gathers information, brings it back.

## What It Does

Munin plants a persistent rules file that tells Claude where memory lives and how to use it. Claude then reads MEMORY.md at the start of substantive tasks and uses Read/Grep to look up memory as needed throughout the session.

**The intelligence, not the transport or the processing.** Bifrost captures transcripts. Heimdall consolidates them. Munin makes Claude actually use the resulting memory.

## How It Works

```
/munin setup
     |
     v
+----------------+     +------------------+
| Write config   | --> | Plant rules file |
| ~/.config/munin|     | ~/.claude/rules/ |
+----------------+     +------------------+
                              |
                    Claude reads this at
                    instruction-level priority
                    every session
                              |
                              v
                    Claude reads MEMORY.md
                    at start of substantive tasks
                    Uses Read/Grep for lookups
```

**No hooks, no scripts.** The rules file is planted once and persists forever. Claude's built-in Read and Grep tools handle all memory access.

## The Memory Loop

```
Session Start
     |
[Bifrost]         git pull memory repo
     |
[Munin rules]     Claude reads MEMORY.md (instruction-level priority)
     |
--- session ---   Claude uses memory silently
     |            /munin recall for deep searches
     |
[Bifrost]         Capture transcript → inbox/ → git push
     |
[Heimdall]        /heimdall process → consolidate into memory
     |
(next session, loop repeats)
```

## Getting Started

### 1. Install the plugin

```
/plugin install munin@quickstop
```

### 2. Run setup

```
/munin setup
```

This asks for your memory repo path (auto-detects from Bifrost if installed) and plants the rules file.

### 3. Start a new session

Claude will now read MEMORY.md at the start of substantive tasks. Use `/munin recall <topic>` for deep memory searches.

## Commands

| Command | Description |
|---------|-------------|
| `/munin setup` | Configure memory repo path and plant awareness rules |
| `/munin recall <topic>` | Deep search across all memory layers for a topic |

## Companion Plugins

Munin works best with the full memory system:

- **Bifrost** — transport (git pull/push, transcript capture)
- **Heimdall** — consolidation (inbox processing into structured memory)
- **Munin** — intelligence (memory awareness during sessions)

Each plugin works independently. Munin only needs a memory repo with MEMORY.md.

## Installation

From the quickstop marketplace:

```bash
/plugin install munin@quickstop
```

Or directly:

```bash
claude --plugin-dir /path/to/quickstop/plugins/munin
```
