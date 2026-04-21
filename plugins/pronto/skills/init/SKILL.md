---
name: init
description: Scaffold the pronto kernel (AGENTS.md, project/ container, .pronto/, .claude/ seed, .gitignore additions) into the current repo and propose installs for recommended sibling plugins
disable-model-invocation: true
argument-hint: "[--force]"
allowed-tools: Read, Glob, Bash, Write, Edit, AskUserQuestion
---

# Pronto: Init

You are the Pronto init skill. When the user runs `/pronto:init` (optionally `--force`), scaffold the kernel into the current repo, then offer to install each recommended sibling plugin that isn't already present.

## Arguments

Parse `$ARGUMENTS`:
- Contains `--force` → **FORCE = true**.
- Otherwise → **FORCE = false**.

## Phase 0: Resolve environment

1. **REPO_ROOT**: `git rev-parse --show-toplevel 2>/dev/null`. If this fails, tell the user `/pronto:init` must run inside a git repo and stop.
2. **PLUGIN_ROOT**: `${CLAUDE_PLUGIN_ROOT}` — pronto's own root, for reading `templates/` and `references/`.
3. **TEMPLATES_ROOT**: `${PLUGIN_ROOT}/templates`.

## Phase 1: Scan target

Build a collision report. For every template source path, check whether the target already exists:

| Source | Target | Collision rule |
|---|---|---|
| `${TEMPLATES_ROOT}/AGENTS.md` | `${REPO_ROOT}/AGENTS.md` | Refuse to overwrite without `--force` |
| `${TEMPLATES_ROOT}/project/**` | `${REPO_ROOT}/project/**` | Refuse on file-level collision unless `--force`; create missing subdirs regardless |
| `${TEMPLATES_ROOT}/.claude/**` | `${REPO_ROOT}/.claude/**` | Skip on file-level collision (never clobber existing `.claude/` content); add files the consumer lacks |
| `${TEMPLATES_ROOT}/.pronto/state.json` | `${REPO_ROOT}/.pronto/state.json` | Refuse without `--force` if present; the file is tool-state, never user-authored |
| `${TEMPLATES_ROOT}/gitignore-additions.txt` | `${REPO_ROOT}/.gitignore` | Append-and-dedupe (see Phase 3.5) |

Batch existence checks via a single Bash call where possible (e.g., `test -e` per path, collect results).

Build **COLLISIONS**, a list of `(source, target, action)` tuples where `action` is one of `write`, `skip`, `refuse`, `append`.

## Phase 2: Present the plan

Show the user exactly what will happen before doing anything. Format:

```
=== PRONTO INIT PLAN ===
Repo: <REPO_ROOT>
Force mode: <on|off>

Kernel scaffolding:
  + AGENTS.md                            (new)
  + project/README.md                    (new)
  + project/plans/.gitkeep               (new)
  + project/tickets/.gitkeep             (new)
  + project/adrs/.gitkeep                (new)
  + project/pulse/.gitkeep               (new)
  + .claude/README.md                    (new)
  + .pronto/state.json                   (new)
  ~ .gitignore                           (append: 4 lines)

Sibling recommendations:
  <enumerated in Phase 4>

Proceed? [run with --force to overwrite any file marked 'refuse']
```

Markers:
- `+` — new file to write.
- `~` — file to modify (append).
- `-` — file to skip (collision; preserving existing).
- `!` — refusal (collision without `--force`); this run will abort if any `!` appears.

If any `!` markers and `FORCE == false`, **stop here** and tell the user how to proceed:

```
Conflicts detected. Re-run with --force to overwrite, or resolve manually:
  - <path>: <reason>
```

## Phase 3: Copy templates

For each `(source, target, action)` in COLLISIONS where action is `write`:

1. Ensure target parent directory exists (`mkdir -p`).
2. Read source, Write target. Preserve file mode.
3. For `.gitkeep` files: `touch` the target rather than reading an empty source.

For action `skip`: log the skip, move on.

For action `refuse` (only present if `FORCE == true`): overwrite per `write`.

### Phase 3.5: Append gitignore additions

Special handling for `${TEMPLATES_ROOT}/gitignore-additions.txt`:

1. Read source lines into **ADDITIONS**.
2. If `${REPO_ROOT}/.gitignore` does not exist → Write with ADDITIONS as the full file.
3. Else:
   - Read existing `.gitignore` lines into **EXISTING**.
   - Deduplicate: append only lines from ADDITIONS not already present in EXISTING (exact match, stripping trailing whitespace).
   - If any new lines to append → append with a blank-line separator before the new block.
   - If all lines already present → log as no-op, move on.

## Phase 4: Sibling recommendations

Load `${PLUGIN_ROOT}/references/recommendations.json`.

Filter to `plugin_status == "shipped"` OR `plugin_status == "phase-1b"` (phase-2-plus plugins don't exist yet — don't propose installs for them).

For each qualifying dimension:

1. Check whether its `recommended_plugin` is already installed. Consult:
   - `${REPO_ROOT}/.claude-plugin/marketplace.json` (if pronto is being run from within quickstop itself) for local availability.
   - `~/.claude/plugins/installed_plugins.json` for globally-installed plugins.
2. If installed → mark as `present`; do nothing further for this dimension.
3. If not installed → mark as `recommend-install`; record the `install_command` for proposal.

## Phase 5: Propose installs

If any dimensions have `recommend-install`:

Use AskUserQuestion (multiSelect) to let the user choose which sibling plugins to install:

```
question: "Which recommended sibling plugins should we install?"
header: "Sibling installs"
options (one per recommend-install entry):
  label: "<plugin-name> — <dimension_label>"
  description: "<one-sentence value prop>  (install: <install_command>)"
options additionally:
  label: "Skip all — no installs"
```

For each selected plugin, tell the user to run the install command (or invoke it via Bash if the CLI supports it): `/plugin install <name>@quickstop`. Pronto does not install programmatically; Claude Code's normal install path runs with the user in the loop.

If the user selects "Skip all" → skip Phase 5's action; proceed to summary.

## Phase 6: Summary

Print a final summary:

```
=== PRONTO INIT COMPLETE ===
Kernel scaffolded at <REPO_ROOT>:
  <list of files written, one per line>

.gitignore: <appended N lines | already current>

Siblings recommended:
  ✓ <installed or just-installed plugin>
  ⊘ <not installed> — /plugin install <name>@quickstop

Next steps:
  1. Review AGENTS.md and fill in repo-specific conventions.
  2. Run /pronto:audit for your baseline score.
  3. Run /pronto:improve to walk the weakest dimensions.
=== END ===
```

## Idempotency

Running `/pronto:init` twice on the same repo without `--force` should:

- Report zero new files written on the second run (everything already present).
- Report `.gitignore` as already current.
- Re-evaluate sibling presence and propose only missing installs.

This is the test for A1's "run in empty dir produces full kernel; run again without `--force` is a no-op with clear output" acceptance.

## Error handling

- `git rev-parse` fails → abort with a clear message.
- A Write call fails (permissions, disk full) → report the specific failure, continue with remaining files, surface a partial-success summary.
- `recommendations.json` parse failure → skip Phase 4/5 silently, continue with the kernel scaffolding (don't block scaffolding on registry issues).
- User refuses every install option → that's fine; the kernel still scaffolded.

## Notes

- **Never clobber user content outside templates.** The init skill only writes at paths listed in the templates tree. If a consumer has `CLAUDE.md`, `LICENSE`, `package.json`, etc., init leaves them alone.
- **Dotfiles use literal names in templates.** The template tree has `.claude/` and `.pronto/` as literal hidden directories; the copy routine doesn't need a rename map — paths are 1:1 with the target.
- **`--force` is coarse.** There's no per-path `--force`. If the user needs to reset only `.pronto/state.json`, they can `rm` it and re-run `/pronto:init` without `--force`.
