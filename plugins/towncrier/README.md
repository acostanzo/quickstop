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

## Plugin surface

This plugin ships:
- Skills: `audit`
- Commands: none
- Agents: none
- Hooks: 26 — one per documented Claude Code hook event, each dispatching through `bin/emit.sh` to the configured transport (`file:` / `fifo:` / `http(s):`)
- Opinions: writes the event envelope to the configured transport (default: `~/.towncrier/events.jsonl`); falls back to the same default file if the configured transport fails. The `bin/emit.sh` script always exits 0 and emits nothing on stdout — the hook flow is pass-through.

The hook handlers respect the ADR-006 §3 invariants: no `hookSpecificOutput` payload-shaping, no persistent host state mutation at hook time (writes are confined to the configured event sink the consumer opted into), no undeclared writes outside the declared transport target.

The audit skill operates strictly read-only on `<REPO_ROOT>` — no consumer-config edits, no auto-installation of dependencies, no cross-plugin automation. Consumers compose automation against this plugin's capabilities per ADR-006 §6.

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

## Privacy

The `data` field of every event envelope contains the **raw hook payload from Claude**. Depending on the event, this includes:

- **`PreToolUse`** — full Bash command strings, file paths, tool arguments
- **`UserPromptSubmit`** — verbatim user prompts, exactly as typed
- **`PostToolUse` / `FileChanged`** — tool outputs and file contents

For the default `file:` transport, data stays local to your machine. This is generally benign.

For `http://` or `https://` transports, **every hook event is POSTed to the configured endpoint in plaintext JSON**, including the above. If you point an HTTP transport at a third-party service — logging aggregator, webhook relay, observability SaaS — that service receives your Bash commands, prompts, and file contents. This happens silently on every Claude action; there is no per-event confirmation.

Before configuring an HTTP transport, verify that:
1. You trust and control the receiving service.
2. Your organization's data classification policy permits sending that data externally.
3. The endpoint is not accidentally public (misconfigured S3 pre-signed URL, unauthenticated webhook, etc.).

The local JSONL default is intentionally conservative. The HTTP transport is powerful but makes data exfiltration trivially easy if misconfigured.

## License

MIT — see [LICENSE](./LICENSE).
