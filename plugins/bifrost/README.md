# Bifrost

Memory bridge for AI agents — portable context that persists across sessions and machines.

## What It Does

Bifrost connects your Claude Code sessions to a shared memory repository. Every session starts with your agent's accumulated knowledge (preferences, project context, recent history) and ends with the session transcript captured for future processing.

**The bridge, not the brain.** Bifrost is a thin client — it reads memory and dumps transcripts. It doesn't process, consolidate, or organize memory. That's the job of an orchestrator (your own automation, a cron job, or a manual process).

## How It Works

```
Session Start                          Session End
     |                                      |
     v                                      v
+---------+                          +-------------+
| git pull |                          | Dump session |
| Read:    |                          | transcript   |
| MEMORY.md|                          | to inbox/    |
| journal/ |                          | git commit   |
| procedures/|                        | git push     |
+---------+                          +-------------+
     |                                      |
     v                                      v
 Context injected                    Raw transcript saved
 into session                        for later processing
```

**Bootstrap (SessionStart):** Pulls the latest memory repo, reads MEMORY.md + procedure index + recent journal entries, and injects them as context via `additionalContext`. Runs on startup, resume, and after context compaction — so memory is re-injected when the context window is compressed mid-session.

**Capture (SessionEnd):** Copies the session transcript to the memory repo's `inbox/` directory with a metadata header (machine name, timestamp, working directory), commits, and pushes. Runs async — zero blocking, zero noise.

## Getting Started

### 1. Install the plugin

```
/plugin install bifrost@quickstop
```

### 2. Run setup

```
/bifrost setup
```

The setup skill walks you through everything:

- **Dependencies** — checks that Git and Python 3 are available
- **Memory repo** — points to an existing one or creates a new one from scratch with the right directory structure and starter files
- **Machine name** — identifies this machine in transcript filenames
- **Configuration** — writes `~/.config/bifrost/config`
- **Verification** — confirms everything is wired up

### 3. You're done

Every Claude Code session now:
- **Starts** with your memory loaded as context
- **Ends** with the transcript captured in `inbox/`

## Memory Repo Structure

Bifrost expects a Git repository with this layout:

```
your-memory-repo/
  MEMORY.md              # Stable facts, preferences, identity (200-line cap)
  procedures/
    procedures.md        # Index of learned workflows
  journal/
    YYYY-MM-DD.md        # Daily logs (today + yesterday loaded)
  inbox/                 # Raw session transcripts land here
```

`/bifrost setup` will create this structure for you if you're starting from scratch.

## Processing the Inbox

Bifrost captures raw transcripts — it doesn't process them into memory. You need something to read `inbox/` files and update MEMORY.md, journal, and procedures. Options:

- **Manual:** Periodically review inbox files and update memory yourself
- **Script:** Write a consolidation script that extracts key observations
- **Orchestrator:** An AI agent (like a cron job running Claude Code) that processes inbox items automatically

The inbox model means all intelligence lives in one place (your processing pipeline), not distributed across every machine. This produces more consistent results and means Bifrost itself stays simple.

## Commands

| Command | Description |
|---------|-------------|
| `/bifrost setup` | Guided setup — dependencies, memory repo, configuration |
| `/bifrost status` | Show memory bridge status and diagnostics |

## Configuration

Config lives at `~/.config/bifrost/config`:

```bash
BIFROST_REPO=~/projects/your-memory-repo
BIFROST_MACHINE=personal-laptop
```

- `BIFROST_REPO` — Path to your memory git repo
- `BIFROST_MACHINE` — Identifier for this machine (used in inbox filenames)

## Requirements

- Claude Code CLI
- Git (for repo sync)
- Python 3 (for JSON escaping in hooks)

`/bifrost setup` checks for these and will warn you if anything is missing.

## Security & Privacy

Session transcripts captured to `inbox/` may contain sensitive information — API keys in error messages, discussed credentials, or confidential project details. These transcripts are automatically committed and pushed to the memory repo's git remote. Ensure your memory repo is private and hosted on a service you trust.

## Installation

From the quickstop marketplace:

```bash
/plugin install bifrost@quickstop
```

Or directly:

```bash
claude --plugin-dir /path/to/quickstop/plugins/bifrost
```
