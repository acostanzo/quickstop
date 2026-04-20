# Towncrier

A Claude Code plugin that emits a structured JSON event for **every** hook event to a configurable transport. Pure observability — strictly pass-through, never alters Claude's behavior.

```jsonl
{"id":"a1b2…","ts":"2026-04-20T08:42:11Z","source":"claude-hook","type":"hook.PreToolUse","host":"laptop","session_id":"…","pid":12345,"cwd":"/repo","data":{…raw payload…}}
```

## Use cases

- **Local dashboards** — tail `events.jsonl` and render live activity
- **Cross-session coordination** — multiple Claude sessions publish to the same fifo or HTTP endpoint, a coordinator reacts
- **Observability and audit** — long-term archive of what tools ran, what prompts were submitted, what permissions were requested
- **Eval dataset capture** — record `(prompt, tool_calls, outcome)` tuples for evaluation harnesses
- **Session replay** — reconstruct a session from its event stream
- **Trigger workflows** — POST events to your own service that fans out to chat, ticketing, CI, etc.

## What it covers

Every documented Claude Code hook event (currently 26): `SessionStart`, `SessionEnd`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`, `Notification`, `Stop`, `StopFailure`, `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `ConfigChange`, `CwdChanged`, `FileChanged`, `InstructionsLoaded`, `PreCompact`, `PostCompact`, `WorktreeCreate`, `WorktreeRemove`, `Elicitation`, `ElicitationResult`.

Each one is wrapped in the same envelope and dispatched through the same transport.

## Installation

### From marketplace

```bash
/plugin marketplace add acostanzo/quickstop
/plugin install towncrier@quickstop
```

### From source

```bash
claude --plugin-dir /path/to/quickstop/plugins/towncrier
```

That's it. The default transport writes to `~/.towncrier/events.jsonl` — install and start tailing.

```bash
tail -F ~/.towncrier/events.jsonl | jq .
```

## Event envelope

```json
{
  "id": "<uuid-v4>",
  "ts": "<ISO-8601 with timezone>",
  "source": "claude-hook",
  "type": "hook.<EventName>",
  "host": "<hostname>",
  "session_id": "<claude session id>",
  "pid": <claude process pid>,
  "cwd": "<session cwd>",
  "data": { /* raw hook payload from Claude */ }
}
```

`data` is the unmodified hook stdin from Claude — schema varies per event. See the [Claude Code hooks reference](https://docs.anthropic.com/en/docs/claude-code/hooks) for per-event payload details.

## Transports

Pluggable via config or environment. Built-in transports:

| Scheme | Example | Behavior |
|--------|---------|----------|
| `file:` | `file:/var/log/claude/events.jsonl` | Append-only JSON Lines. Parent directory auto-created. |
| `fifo:` | `fifo:/tmp/claude.fifo` | Write to a named pipe (you create it; you run the reader). |
| `http://` / `https://` | `https://example.com/ingest` | `POST` envelope as JSON body. |

If a transport fails or times out, the envelope is appended to the **default fallback file** at `~/.towncrier/events.jsonl`. Events are never silently dropped.

## Configuration

Two ways, in priority order:

**1. Environment variable (highest priority)**

```bash
export TOWNCRIER_TRANSPORT="http://localhost:9090/events"
```

**2. Config file at `~/.towncrier/config.json`**

```json
{
  "transport": "fifo:/tmp/claude.fifo",
  "skip_events": ["PreToolUse", "PostToolUse"]
}
```

If neither is set, the default is `file:~/.towncrier/events.jsonl`.

### Filtering noisy events

Add event names to `skip_events` to mute them without uninstalling. The hook still fires (Claude still calls the script), but the script returns immediately without dispatching.

## Robustness

The non-negotiables, enforced in `bin/emit.sh`:

- **2-second hard timeout** on every transport call. Claude hooks never hang.
- **Automatic fallback to the default file** if the configured transport fails (pipe has no reader, HTTP unreachable, file unwritable, timeout).
- **Pass-through always.** The script writes nothing to stdout and exits `0`. `PermissionRequest` and other decision-affecting events are unaffected; Claude's default flow runs unchanged.
- **Silent failures.** Transport errors don't print to your terminal — they fall back instead.

## Building a consumer

Towncrier ships only the producer. Consumers are out of scope for v0.1.0 — but the contract is simple:

- **`file:` consumers** — `tail -F` and parse with `jq`. Each line is one envelope.
- **`fifo:` consumers** — `cat <fifo>` in a long-running process. Read line-delimited.
- **`http://` consumers** — accept `POST application/json`, body is one envelope.

Filter on `type` (e.g. `hook.PreToolUse`) and dispatch on `data` shape. The envelope is stable across all events; only `data` varies.

## Dependencies

- `bash`
- `jq`
- `curl` (only required for HTTP transport)
- `uuidgen` (preferred), `/proc/sys/kernel/random/uuid` (fallback), or RNG-based UUID

## License

MIT — see [LICENSE](./LICENSE).
