# Bifrost

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

## How It Works

| Layer | Skill | Role |
|-------|-------|------|
| Transport | Hooks | Pulls memory at session start, captures transcripts at session end |
| Processing | `/heimdall` | Extracts observations from transcripts, consolidates into structured memory |
| Intelligence | `/recall` | Deep cross-layer recall across all memory layers |

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

Periodically run `/heimdall process` to consolidate captured transcripts into structured memory.

## Commands

| Command | Description |
|---------|-------------|
| `/setup` | Full setup wizard — config, repo, rules |
| `/status` | System health dashboard |
| `/heimdall` | Consolidate inbox transcripts into structured memory |
| `/recall <topic>` | Deep agent-powered search across all memory layers |
| `/search <query>` | Quick grep across all memory files |
| `/archive` | Archive old journals, report cap pressure |

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

## Requirements

- Claude Code CLI
- Git (for repo sync)
- Python 3 (for JSON escaping in hooks)

`/setup` checks for these and warns if anything is missing.

## Security & Privacy

Session transcripts captured to `inbox/` contain the full conversation and tool output from each session. This may include:

- **API keys and credentials** that appeared in error messages, config files, or environment variables
- **Confidential project details** discussed during the session
- **File contents** read by the agent (source code, configs, data files)
- **Command output** including git logs, environment state, and system information

These transcripts are automatically committed and pushed to the memory repo's git remote. **Your memory repo should be private** — use a private repository on a service you trust. Do not use a public repository for your memory repo.

If you use a shared machine, be aware that `~/.config/bifrost/config` contains the repo path and the transcript capture runs on every session end.
