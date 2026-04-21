---
name: pulse
description: Append a timestamped entry to today's pulse day-file in project/pulse/
disable-model-invocation: true
argument-hint: <message>
allowed-tools: Read, Write, Edit, Bash, Glob, AskUserQuestion
---

# /avanti:pulse — Append a pulse entry

You are the `/avanti:pulse` orchestrator. When the user runs `/avanti:pulse <message>`, append a timestamped entry to today's `project/pulse/YYYY-MM-DD.md`. Create the day-file from `templates/pulse-day.md` if it does not yet exist. Pulse is append-only — never edit prior entries.

See `${CLAUDE_PLUGIN_ROOT}/references/sdlc-conventions.md#pulse-structure` for the shape.

## Phase 0: Parse and locate

### Step 1: Read the message

`$ARGUMENTS` is the entry body — free-form markdown, one paragraph is the norm.

- If `$ARGUMENTS` is non-empty → use it verbatim as **MESSAGE**.
- If `$ARGUMENTS` is empty or whitespace-only → use AskUserQuestion to prompt: "What should this pulse entry say?" Capture the response as MESSAGE.

Do not rewrite, summarize, or clean up the message. Pulse entries are the user's voice.

### Step 2: Locate the repo root and pulse directory

Run `git rev-parse --show-toplevel 2>/dev/null`. Abort on failure. Store as **REPO_ROOT**.

**PULSE_DIR** = `${REPO_ROOT}/project/pulse/`.

If PULSE_DIR does not exist, abort with a pointer to `/pronto:init`:

```
project/pulse/ does not exist. Run /pronto:init to scaffold the container,
then re-run /avanti:pulse.
```

### Step 3: Resolve today's date and time

Run `date +%Y-%m-%d` → **TODAY**.
Run `date +%H:%M` → **NOW**.

**DAY_FILE** = `${PULSE_DIR}${TODAY}.md`.

## Phase 1: Ensure the day-file exists

### Step 1: Check for the day-file

Use Glob or Bash `test -f` to check whether DAY_FILE exists.

### Step 2: Create from template if missing

If DAY_FILE does not exist:

1. Read `${CLAUDE_PLUGIN_ROOT}/templates/pulse-day.md` as **TEMPLATE**.
2. Render: replace `TODO-DATE` with `${TODAY}`. Do **not** pre-fill a first entry from the template body — overwrite the entire template body below the header with the fresh entry in Phase 2. The template's example entry is for authors reading the template directly; once a day-file exists for real, only real entries live in it.

   Concretely, the new day-file after creation is:

   ```markdown
   # Pulse — ${TODAY}
   ```

3. Write the day-file to DAY_FILE.

If DAY_FILE already exists, no creation is needed — proceed to Phase 2.

## Phase 2: Append the entry

### Step 1: Read the day-file's current content

Read DAY_FILE as **CURRENT**.

### Step 2: Build the new entry

The entry shape is two blank-line-separated sections:

```markdown


## ${NOW}

${MESSAGE}
```

(Two newlines before the `## HH:MM` header — one blank line separator from the prior content, one ensuring the header has space. The trailing newline of MESSAGE is fine either way; writers normalize.)

### Step 3: Append

Append the new entry to CURRENT and Write the result back to DAY_FILE. Never edit or remove prior content — only grow the file.

If the file ends without a trailing newline, add one before appending. If it already has trailing whitespace, preserve it — append the new block after.

## Phase 3: Report

Tell the user — one short line, since pulse is meant to be frictionless:

```
Pulse logged: project/pulse/${TODAY}.md @ ${NOW}
```

If the day-file was created in this invocation, note it:

```
Pulse logged: project/pulse/${TODAY}.md @ ${NOW} (day-file created)
```

## Error handling

- **Empty message after prompt**: abort rather than log an empty entry. Pulse entries exist to convey something; empty ones are noise.
- **Pulse directory missing**: do not auto-create. Point to `/pronto:init` and abort.
- **Write fails**: report the error; if DAY_FILE was newly created but the append failed, leave the file intact (the header-only file is harmless) so the next pulse picks up where this one left off.
- **Clock drift / duplicate HH:MM**: two pulses in the same minute is fine — both land under the same timestamp, in the order they were written. The appended entry just comes below the prior one with its own `## HH:MM` header; if both happen to be the same minute the reader sees two identical headers, which is accurate.
