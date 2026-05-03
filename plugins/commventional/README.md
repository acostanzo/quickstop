# Commventional

Enforce conventional commits, conventional comments, and engineering ownership for commits, PRs, and code reviews.

## What It Does

Commventional ships three conventions as **capabilities**:

1. **Conventional Commits** — commit messages and PR titles follow the [conventional commits](https://www.conventionalcommits.org/) spec
2. **Conventional Comments** — code review feedback uses [conventional comments](https://conventionalcomments.org/) labels and format
3. **Engineering Ownership** — engineers own their code; no automated `Co-Authored-By` trailers for AI tooling, no "Generated with/by Claude" footers

The first two are enforced by the auto-invoking `commventional` skill (it activates when Claude recognises a commit, PR, or review scenario). The third — engineering ownership — is offered as three consumer-invoked skills (`:strip-trailers`, `:strip-pr-body`, `:install-trailer-stripper`) so the consumer chooses when and where the trailer-stripping fires. See **Plugin surface** and **Example wirings** below.

| Scenario | What Happens |
|----------|-------------|
| You ask to commit | The `commventional` skill dispatches the `commit-crafter` agent to analyse staged diffs, determine the conventional type, and craft the message |
| You ask to create a PR | The `commventional` skill dispatches `commit-crafter` with the full branch diff to produce a conventional title and structured body |
| You review code | The `commventional` skill dispatches `review-formatter` to format feedback using conventional-comment labels |
| You want one-shot trailer cleanup | Run `/commventional:strip-trailers --text "..."` or `/commventional:strip-pr-body --pr-url <url>` |
| You want trailer-stripping wired into your own automation | Run `/commventional:install-trailer-stripper --target <choice>` — the helper writes the wiring into the surface you chose |

## Plugin surface

Per ADR-006 §1, this plugin ships:

- **Skills (4):**
  - `commventional` — the auto-invoking enforcer; orchestrates `commit-crafter` / `review-formatter` on commit / PR / review work.
  - `strip-trailers` — consumer-invoked. Strips `Co-Authored-By` trailers and "Generated with/by Claude" footers from a text blob. Read-only; output to stdout.
  - `strip-pr-body` — consumer-invoked. Fetches a GitHub PR body via `gh`, runs it through `:strip-trailers`, writes the cleaned body back via `gh pr edit --body-file`. Mutates only the PR body the consumer named in `--pr-url`.
  - `install-trailer-stripper` — consumer-invoked install helper. Writes a Claude Code hook entry (PreToolUse for trailer-stripping; PostToolUse for PR cleanup) into `~/.claude/settings.json` or `<repo>/.claude/settings.json`, **or** writes a `commit-msg` hook to `<repo>/.git/hooks/`. Refuses to overwrite existing files without `--force`; always confirms with the user before each write.
- **Commands:** none (each skill is invoked via its `/commventional:<skill>` slash).
- **Agents (2):**
  - `commit-crafter` — analyses diffs and produces conventional commit messages and PR bodies.
  - `review-formatter` — formats review feedback using conventional-comment labels.
- **Hooks:** none. Post-migration, commventional installs no Claude Code event hooks and no `.git/hooks/` scripts at plugin-install time.
- **Opinions:** when the auto-invoking skill activates, it enforces engineering-ownership in commit messages and PR bodies it crafts (no `Co-Authored-By`, no `Generated with/by Claude`). When the consumer wires `:install-trailer-stripper` into their own automation, the installed wiring strips those patterns from anything matching its trigger — but the trigger is the consumer's, not commventional's.

ADR-006 §2 conformance (no silent mutation of consumer artefacts): no plugin-installed hooks; no consumer state mutation at install time. Every consumer write commventional performs is the result of a slash command the consumer typed (`/commventional:strip-pr-body`, `/commventional:install-trailer-stripper`) with explicit arguments naming the target.

ADR-006 §3 conformance (hook invariants): vacuously satisfied — no plugin-installed Claude Code hooks remain. Hooks the consumer installs via `:install-trailer-stripper` live in the consumer's surface and the consumer owns their conformance.

## Installation

### From Marketplace

```bash
/plugin marketplace add acostanzo/quickstop
/plugin install commventional@quickstop
```

### From Source

```bash
claude --plugin-dir /path/to/quickstop/plugins/commventional
```

That's it — installation drops in the four skills above and two agents. Nothing fires automatically until you commit, open a PR, review code, or invoke a consumer-side skill.

## Example wirings

Per ADR-006 §6, capabilities ship without triggers; the consumer composes the trigger. Copy-pasteable starting points:

### Restore v1.x's PreToolUse trailer-stripping (globally)

```bash
/commventional:install-trailer-stripper --target claude-settings-user
```

Writes a self-contained hook script under `~/.claude/scripts/` and merges a `PreToolUse` entry into `~/.claude/settings.json`. Equivalent to the v1.x `enforce-ownership.sh` scope (every Claude Bash call to `git commit` / `gh pr create`).

### Restore v1.x's PostToolUse PR-body cleanup (globally)

```bash
/commventional:install-trailer-stripper --target pr-cleanup-hook-user
```

Writes a self-contained `commventional-pr-cleanup.sh` under `~/.claude/scripts/` and a `PostToolUse` entry into `~/.claude/settings.json`. Equivalent to the v1.x `pr-ownership-check.sh` scope.

### Restore both (globally)

```bash
/commventional:install-trailer-stripper --target all
```

The helper asks whether to install into user-scope or project-scope settings, then writes both standalone scripts and merges both PreToolUse + PostToolUse entries into the chosen settings.json.

### Strip on every git commit (manual commits too)

```bash
/commventional:install-trailer-stripper --target git-commit-msg-hook
```

Writes `<repo>/.git/hooks/commit-msg` — broader than v1.x's behaviour because it catches commits made outside Claude as well.

### One-shot cleanup of a single PR

```bash
/commventional:strip-pr-body --pr-url https://github.com/owner/repo/pull/123
```

No installation; cleans this one PR's body and exits.

### Pipe text through the capability directly

```bash
/commventional:strip-trailers --text "fix: bug

Co-Authored-By: Claude <noreply@anthropic.com>"
```

Returns the cleaned text on stdout. Useful for ad-hoc cleanups, scripting, or feeding through your own pipeline.

## Breaking changes in v2.0

v2.0 removes the two plugin-installed hooks (`PreToolUse` → `enforce-ownership.sh`, `PostToolUse` → `pr-ownership-check.sh`) that v1.x shipped. The trailer-stripping behaviour is preserved as the four skills above; the **trigger** moves from plugin-install to consumer-invocation per ADR-006 (`project/adrs/006-plugin-responsibility-boundary.md`).

If you upgrade from v1.x and want today's behaviour back, pick the install target from **Example wirings** above:

| You want… | Run |
|---|---|
| Today's PreToolUse stripping back, globally | `/commventional:install-trailer-stripper --target claude-settings-user` |
| Today's PostToolUse PR cleanup back, globally | `/commventional:install-trailer-stripper --target pr-cleanup-hook-user` |
| Both back, globally | `/commventional:install-trailer-stripper --target all` |
| Stripping on every git commit (including manual) | `/commventional:install-trailer-stripper --target git-commit-msg-hook` |

The installed hook scripts are self-contained — they ship the same perl substitution chain v1.x used. Future updates to commventional's `bin/strip-trailers.sh` are not picked up automatically; re-run the install helper to refresh.

## Agents

| Agent | Role | Dispatched When |
|-------|------|----------------|
| `commit-crafter` | Analyses diffs, crafts conventional commit messages and PR titles | Commits and PRs |
| `review-formatter` | Formats review feedback with conventional comment labels | Code reviews |

## Commit Types

| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Restructuring without behavior change |
| `docs` | Documentation |
| `test` | Tests |
| `chore` | Maintenance |
| `style` | Formatting |
| `perf` | Performance |
| `ci` | CI/CD |
| `build` | Build system |

## Review Labels

| Label | Blocking? |
|-------|-----------|
| `praise` | No |
| `nitpick` | No |
| `suggestion` | No |
| `issue` | Yes |
| `question` | No |
| `thought` | No |
| `chore` | Yes |
| `typo` | Yes |

## Requirements

- Claude Code CLI
- `perl` (for the trailer-stripping substitution chain in `:strip-trailers`)
- `jq` (for `:install-trailer-stripper`'s settings.json merging and the installed hook scripts)
- `gh` (only required for `:strip-pr-body` and the installed PR-cleanup hook)
