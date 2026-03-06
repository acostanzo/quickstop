# Heimdall

Memory consolidation plugin — the gatekeeper that processes inbox transcripts into structured memory.

## What It Does

Heimdall reads raw session transcripts from a memory repo's `inbox/` directory and consolidates them into organized memory: MEMORY.md facts, journal entries, and procedure files. It's the processing half of the Bifrost + Heimdall memory system.

**The brain, not the bridge.** Bifrost captures raw transcripts. Heimdall reads them, extracts what matters, and writes it into the right memory layers.

## How It Works

```
/heimdall process
     |
     v
+-----------+     +-------------+     +--------------+
| Read inbox | --> | Extract     | --> | Consolidate  |
| transcripts|     | observations|     | into memory  |
+-----------+     +-------------+     +--------------+
     |                  |                     |
  Oldest-first     Read-only agent      Read-write agent
  processing       (comprehension)      (merging/writing)
                                              |
                                    +---------+---------+
                                    |         |         |
                                 MEMORY.md  journal  procedures
```

**Two-agent pipeline:**
1. **Extractor** (read-only) — reads each transcript, outputs structured observations
2. **Consolidator** (read-write) — merges observations into MEMORY.md, journal, and procedures

Extraction and consolidation are separated so the extractor isn't biased by existing memory content, and the consolidator has a clean, structured input to work with.

## Getting Started

### 1. Install the plugin

```
/plugin install heimdall@quickstop
```

### 2. Navigate to your memory repo

Heimdall operates on a memory repo (the kind Bifrost creates). `cd` into it.

### 3. Process your inbox

```
/heimdall process
```

## Commands

| Command | Description |
|---------|-------------|
| `/heimdall process` | Process all unprocessed inbox transcripts into memory |
| `/heimdall status` | Memory health dashboard — line counts, inbox size, staleness |
| `/heimdall search <query>` | Cross-layer search across all memory files |
| `/heimdall archive` | Archive old journals, report MEMORY.md cap pressure |

## Memory Repo Structure

Heimdall expects this layout (created by `/bifrost setup`):

```
your-memory-repo/
  MEMORY.md              # Stable facts, preferences, identity (200-line cap)
  procedures/
    procedures.md        # Index of learned workflows
  journal/
    YYYY-MM-DD.md        # Daily logs
    archive/             # Journals older than 7 days
      YYYY-MM/
  inbox/                 # Raw session transcripts (from Bifrost)
    processed/           # Transcripts after consolidation
  context-trees/
    projects.md          # Project status tracker
```

## Companion Plugin

Heimdall is designed to work with [Bifrost](../bifrost/), which captures session transcripts into `inbox/`. Together they form a complete memory system:

- **Bifrost** = capture (session start/end hooks)
- **Heimdall** = consolidation (user-invoked processing)

You can use Heimdall standalone if you populate `inbox/` files yourself.

## Installation

From the quickstop marketplace:

```bash
/plugin install heimdall@quickstop
```

Or directly:

```bash
claude --plugin-dir /path/to/quickstop/plugins/heimdall
```
