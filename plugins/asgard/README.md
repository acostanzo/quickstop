# Asgard

Memory system for AI agents — capture, consolidate, and recall knowledge across sessions and machines.

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
     |              /heimdall process                           |
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

## Three Layers, One Plugin

| Layer | Component | Role |
|-------|-----------|------|
| Transport | **Bifrost** | Pulls memory at session start, captures transcripts at session end |
| Processing | **Heimdall** | Extracts observations from transcripts, consolidates into structured memory |
| Intelligence | **Munin** | Deep cross-layer recall, memory-aware rules for sessions |

Each layer was previously a separate plugin. Asgard unifies them into a single plugin with shared config, shared references, and coordinated skills.

## Getting Started

### 1. Install

```bash
/plugin install asgard@quickstop
```

Or from source:

```bash
claude --plugin-dir /path/to/quickstop/plugins/asgard
```

### 2. Setup

```
/asgard setup
```

The setup wizard walks you through:
- **Dependencies** — Git, Python 3
- **Memory repo** — create new or point to existing
- **Machine name** — identifies this machine in transcripts
- **Rules file** — plants memory awareness instructions for Claude
- **Config** — writes `~/.config/asgard/config`

### 3. Use

Every session now automatically:
- **Starts** with your memory loaded as context
- **Ends** with the transcript captured in `inbox/`

Periodically run `/heimdall process` to consolidate captured transcripts into structured memory.

## Commands

| Command | Description |
|---------|-------------|
| `/asgard setup` | Full setup wizard — config, repo, rules |
| `/asgard status` | System health dashboard |
| `/heimdall process` | Process inbox transcripts into memory |
| `/heimdall status` | Memory health dashboard |
| `/heimdall search <query>` | Cross-layer search across all memory files |
| `/heimdall archive` | Archive old journals, report cap pressure |
| `/munin recall <topic>` | Deep search across all memory layers |

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

Config lives at `~/.config/asgard/config`:

```bash
ASGARD_REPO=~/projects/your-memory-repo
ASGARD_MACHINE=personal-laptop
ASGARD_JOURNAL_DAYS=2
```

| Variable | Description | Default |
|----------|-------------|---------|
| `ASGARD_REPO` | Path to memory git repo | (required) |
| `ASGARD_MACHINE` | Machine identifier for transcripts | (required) |
| `ASGARD_JOURNAL_DAYS` | Number of journal days to load at session start | `2` |
| `ASGARD_CONTEXT_CHARS` | Max characters injected as context | `12000` |

## Requirements

- Claude Code CLI
- Git (for repo sync)
- Python 3 (for JSON escaping in hooks)

`/asgard setup` checks for these and warns if anything is missing.

## Security & Privacy

Session transcripts captured to `inbox/` contain the full conversation and tool output from each session. This may include:

- **API keys and credentials** that appeared in error messages, config files, or environment variables
- **Confidential project details** discussed during the session
- **File contents** read by the agent (source code, configs, data files)
- **Command output** including git logs, environment state, and system information

These transcripts are automatically committed and pushed to the memory repo's git remote. **Your memory repo should be private** — use a private repository on a service you trust. Do not use a public repository for your memory repo.

If you use a shared machine, be aware that `~/.config/asgard/config` contains the repo path and the transcript capture runs on every session end.
