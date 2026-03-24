# Bifrost

Memory system for AI agents — capture, consolidate, and recall knowledge across sessions and machines.

## Why Bifrost?

There are several Claude Code memory systems available. Here's what makes Bifrost different:

**No infrastructure.** No databases, no running services, no vector stores. Bifrost is just git and markdown files. Other systems require SQLite + Chroma + a background worker ([claude-mem](https://github.com/thedotmack/claude-mem)), Redis or a cloud account ([Recall](https://github.com/joseairosa/recall)), or SQLite with vector extensions ([claude-memory](https://github.com/codenamev/claude_memory)). Bifrost needs git and a text editor.

**Multi-machine by default.** Memory lives in a git repo. Push from your laptop, pull from your desktop — memory follows you. Most alternatives are machine-local (Claude's native auto-memory, [Total Recall](https://github.com/davegoldblatt/total-recall)) or require cloud infrastructure to sync (Recall).

**Explicit consolidation.** Transcript capture is passive and automatic. But consolidation — the act of turning raw transcripts into structured memory — is deliberate. You run `/heimdall` when you're ready. This means you control when and how memory evolves, unlike systems that consolidate automatically and may promote noise.

**Human-auditable.** Every piece of memory is a markdown file you can read, edit, diff, and version control. Core memory is `MEMORY.md`. Daily events are in `journal/`. Learned workflows are in `procedures/`. There are no opaque databases to query.

**Read-only during sessions.** Memory files are loaded at session start but never written during a session. All writes happen through the consolidation pipeline. This prevents corruption from crashes, race conditions, or concurrent sessions on different machines.

**Structured extraction pipeline.** Consolidation uses two separated agents: a read-only Extractor that analyzes transcripts and outputs observations, and a read-write Consolidator that merges those observations into memory. Observations carry confidence levels — low-confidence observations go to the journal for context but don't touch core memory.

**Budget-aware context loading.** At session start, Bifrost loads memory using a priority system (core memory first, then procedures, then recent journal) within a configurable character budget. Files that don't fit entirely are skipped rather than truncated — preventing hallucination from partial content.

## Comparison

| System | Type | Storage | Cross-machine | Consolidation | Infrastructure | Search |
|--------|------|---------|---------------|---------------|----------------|--------|
| **Bifrost** | Plugin | Git + Markdown | Yes (git sync) | Explicit (`/heimdall`) | None | Grep → agent escalation |
| [Native auto-memory](https://code.claude.com/docs/en/memory) | Built-in | Local files | No | Automatic | None | Context injection only |
| [claude-mem](https://github.com/thedotmack/claude-mem) | Hooks | SQLite + Chroma | No | Automatic | Worker service (Bun) | Semantic + keyword |
| [memsearch](https://github.com/zilliztech/memsearch) | Plugin | Markdown + index | Manual (copy folder) | Automatic | Background watcher | Semantic |
| [episodic-memory](https://github.com/obra/episodic-memory) | MCP | SQLite | No | Automatic | None | Semantic |
| [Recall](https://github.com/joseairosa/recall) | MCP | Redis / Cloud | Yes (cloud) | Automatic | Redis or cloud account | Semantic |
| [Total Recall](https://github.com/davegoldblatt/total-recall) | Plugin | Markdown | No | Manual (write gates) | None | Index only |
| [claude-memory](https://github.com/codenamev/claude_memory) | Hooks + MCP | SQLite-vec | No | Automatic | None | KNN vectors |

*Last reviewed: March 2026. These projects evolve — check their repos for current capabilities.*

## When to Use Something Else

Bifrost optimizes for transparency, control, and zero infrastructure. That's not always what you need:

- **You want zero setup** — Claude's native auto-memory works out of the box with no configuration
- **You want semantic search** — claude-mem, memsearch, and claude-memory use vector embeddings for similarity-based recall; Bifrost uses grep and agent-based search
- **You want fully automatic consolidation** — claude-mem captures and consolidates without manual steps
- **You want cloud-managed memory** — Recall offers a hosted option with automatic clustering

## The Memory Loop

```
Session Start                                              Session End
     |                                                          |
     v                                                          v
[Bootstrap]                                              [Capture]
  git pull memory repo                                    Dump transcript
  Inject MEMORY.md + journal                              to inbox/
  as session context                                      git commit + push
     |                                                          |
     v                                                          v
 Agent has memory                                      Raw transcript saved
 from previous sessions                                for later processing
     |                                                          |
     |              /heimdall                                   |
     |    +--------------------------------------------+        |
     |    |  Extractor (read-only)     Consolidator    |        |
     |    |  Analyze transcripts  -->  Write to:       |        |
     |    |  Extract observations      - MEMORY.md     |        |
     |    |                            - journal/      |        |
     |    |                            - procedures/   |        |
     |    +--------------------------------------------+        |
     |                    |                                     |
     +--------------------+-------------------------------------+
              Memory grows session over session
```

## How It Works

| Layer | Component | Role |
|-------|-----------|------|
| Transport | Hooks | Pulls memory at session start, captures transcripts at session end |
| Processing | `/heimdall` | Extracts observations from transcripts, consolidates into structured memory |
| Intelligence | `/odin` | Searches memory — sends Huginn (quick grep), then Munin (deep agent search) if needed |

## Getting Started

### 1. Install

```bash
/plugin install bifrost@quickstop
```

Or from source:

```bash
claude --plugin-dir /path/to/quickstop/plugins/bifrost
```

### 2. Setup

```
/setup
```

The setup wizard walks you through:
- **Dependencies** — Git, Python 3
- **Memory repo** — create new or point to existing
- **Machine name** — identifies this machine in transcripts
- **Rules file** — plants memory awareness instructions for Claude
- **Config** — writes `~/.config/bifrost/config`

### 3. Use

Every session now automatically:
- **Starts** with your memory loaded as context
- **Ends** with the transcript captured in `inbox/`

Periodically run `/heimdall` to consolidate captured transcripts into structured memory. This can be run manually or on a cron. Journal archival (moving journals older than 7 days to `journal/archive/`) happens automatically during consolidation.

## Commands

| Command | Auto | Description |
|---------|------|-------------|
| `/setup` | No | Full setup wizard — config, repo, rules |
| `/status` | No | System health dashboard |
| `/heimdall` | No | Consolidate inbox transcripts into structured memory |
| `/odin <topic>` | Yes | Search memory — sends Huginn (quick grep), then Munin (deep search) if needed |

Commands marked **Auto: Yes** can be invoked proactively by Claude when it needs context. The others only run when you explicitly call them.

## Agents

| Agent | Type | Dispatched by |
|-------|------|--------------|
| Extractor | Read-only | `/heimdall` — analyzes transcripts, extracts observations |
| Consolidator | Read-write | `/heimdall` — merges observations into MEMORY.md, journal, procedures |
| Munin | Read-only | `/odin` — deep cross-layer search with synonym expansion and cross-referencing |

## Memory Repo Structure

```
your-memory-repo/
  MEMORY.md              # Core memory — stable facts, 200-line cap
  procedures/
    procedures.md        # Index of learned workflows
    *.md                 # Individual procedure files
  journal/
    YYYY-MM-DD.md        # Daily logs
    archive/YYYY-MM/     # Archived journals (>7 days)
  context-trees/
    projects.md          # Project status tracker
  inbox/                 # Raw session transcripts
    processed/           # After consolidation
```

See `references/memory-structure.md` for full details.

## Configuration

Config lives at `~/.config/bifrost/config`:

```bash
BIFROST_REPO=~/projects/your-memory-repo
BIFROST_MACHINE=personal-laptop
BIFROST_JOURNAL_DAYS=2
```

| Variable | Description | Default |
|----------|-------------|---------|
| `BIFROST_REPO` | Path to memory git repo | (required) |
| `BIFROST_MACHINE` | Machine identifier for transcripts | (required) |
| `BIFROST_JOURNAL_DAYS` | Number of journal days to load at session start | `2` |
| `BIFROST_CONTEXT_CHARS` | Max characters injected as context | `12000` |

## Safety

### Feedback Loop Prevention

Both hooks detect when a session is running inside the memory repo and silently skip. This prevents a loop where editing memory generates a transcript that gets consolidated back into memory.

### Transcript Privacy

Session transcripts captured to `inbox/` contain the full conversation and tool output from each session. This may include:

- **API keys and credentials** that appeared in error messages, config files, or environment variables
- **Confidential project details** discussed during the session
- **File contents** read by the agent (source code, configs, data files)
- **Command output** including git logs, environment state, and system information

These transcripts are automatically committed and pushed to the memory repo's git remote. **Your memory repo should be private** — use a private repository on a service you trust. Do not use a public repository for your memory repo.

If you use a shared machine, be aware that `~/.config/bifrost/config` contains the repo path and the transcript capture runs on every session end.

## Requirements

- Claude Code CLI
- Git (for repo sync)
- Python 3 (for JSON escaping in hooks)

`/setup` checks for these and warns if anything is missing.
