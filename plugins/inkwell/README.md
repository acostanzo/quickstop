# Inkwell (v0.2.0)

Automatic documentation-as-code engine for Claude Code projects. Inkwell works automatically via hooks, but also provides commands for manual control.

## How It Works

Inkwell uses a **queue-based architecture** to separate detection from generation:

```
git commit → PostToolUse hook → .inkwell-queue.json → Stop hook → doc-writer agent → docs/ committed
```

1. **Detect** (PostToolUse hook on `Bash`): After any `git commit`, a lightweight hook analyzes what changed and appends doc tasks to `.inkwell-queue.json`. This runs in <2s and never blocks your workflow.

2. **Queue** (`.inkwell-queue.json`): Tasks accumulate during a session. Each task records the commit hash, message, changed files, and what type of documentation is needed.

3. **Process** (Stop hook): When Claude's turn ends, the Stop hook checks the queue. If tasks are pending, it instructs Claude to dispatch the doc-writer agent to process them.

4. **Write** (doc-writer agent): Reads source changes, writes documentation, commits with `docs:` prefix, and clears the queue.

### What Gets Documented

| Type | Trigger | Output |
|------|---------|--------|
| `api-reference` | Files changed in `src/`, `lib/`, `app/` | `docs/reference/<module>.md` |
| `api-contract` | Route/API files changed or contain route patterns | `docs/reference/api.md` endpoint table |
| `env-config` | `.env`/config files changed, or new `process.env`/`os.environ`/`Deno.env` references | `docs/reference/configuration.md` variable table |
| `domain-scaffold` | New model/entity/type files added | `docs/reference/domain.md` skeleton with TODOs |
| `changelog` | `feat:`, `fix:`, `refactor:` commits | `CHANGELOG.md` entry |
| `architecture` | New modules, major restructuring | `docs/ARCHITECTURE.md` section |
| `index` | Any doc file added or removed | `docs/INDEX.md` rebuild |

### Queue Format

```json
[
  {
    "type": "changelog",
    "commit": "abc1234",
    "message": "feat(auth): add OAuth2 support",
    "files": ["src/auth.ts", "src/oauth.ts"],
    "timestamp": "2026-04-01T10:00:00Z"
  }
]
```

## Commands

| Command | Description |
|---------|-------------|
| `/inkwell:capture` | Scan recent commits and generate missing documentation |
| `/inkwell:adr <title>` | Create a numbered Architecture Decision Record |
| `/inkwell:changelog` | Generate or update CHANGELOG.md from conventional commits |
| `/inkwell:index` | Rebuild docs/INDEX.md to match files on disk |
| `/inkwell:stale` | Find docs that are out of date relative to code changes |

## Agents

| Agent | Role | Dispatched By |
|-------|------|---------------|
| `doc-writer` | Reads source changes, writes documentation, commits | Stop hook, `/inkwell:capture` |
| `index-builder` | Scans doc directories, rebuilds INDEX.md | `/inkwell:index` |

## Examples

### Automatic documentation (no commands needed)

```
You: "Add OAuth2 support to the auth module"
Claude: [writes code, commits with 'feat(auth): add OAuth2 support']
         ↓ PostToolUse hook fires
         ↓ Queue: [{type: "changelog", ...}, {type: "api-reference", ...}]
         ↓ Stop hook fires → doc-writer processes queue
         ↓ CHANGELOG.md updated, docs/reference/auth.md updated
         ↓ Committed: 'docs: update documentation from recent changes'
```

### Manual capture of recent work

```
/inkwell:capture 10        # scan last 10 commits
/inkwell:capture           # scan since last capture
```

### Create an ADR

```
/inkwell:adr Use PostgreSQL for session storage
→ Created ADR #0003: Use PostgreSQL for session storage
  → docs/decisions/0003-use-postgresql-for-session-storage.md
```

### Check for stale docs

```
/inkwell:stale
→ Very Stale: docs/reference/auth.md (src/auth.ts changed 64 days after doc)
→ Fresh: docs/decisions/0001-use-postgresql.md
→ Summary: 5 docs checked, 1 very stale, 4 fresh
```

## Bundled Rules

Inkwell ships rules that apply automatically to matching files when the plugin is installed.

| Rule | Globs | Purpose |
|------|-------|---------|
| `code-comments` | `*.ts`, `*.js`, `*.py`, `*.go`, `*.rs`, `*.java`, `*.rb` | Enforces meaningful comments — no narration, no commented-out code, TODOs must be actionable |

Rules are in `rules/` and follow the Claude Code [bundled rules](https://docs.anthropic.com/en/docs/claude-code/plugins) format.

## Requirements

- `jq` — JSON processing in hook scripts
- `git` — commit analysis and doc commits

## Installation

### From Marketplace

```bash
/plugin marketplace add acostanzo/quickstop
/plugin install inkwell@quickstop
```

### From Source

```bash
git clone https://github.com/acostanzo/quickstop.git
claude --plugin-dir /path/to/quickstop/plugins/inkwell
```

## Safety

- Hook scripts exit cleanly on missing dependencies (jq, git) — never block
- `docs:` commits from inkwell are detected and skipped to prevent feedback loops
- The Stop hook only suggests processing — Claude decides whether to act
- Queue file (`.inkwell-queue.json`) is plain JSON, human-readable, and safe to delete at any time
- Skills are `disable-model-invocation: true` — they only run when explicitly invoked

**Gitignore:** Inkwell creates runtime files in your project root that should not be committed:

```bash
echo -e '.inkwell-queue.json\n.inkwell-last-capture' >> .gitignore
```

## License

MIT
