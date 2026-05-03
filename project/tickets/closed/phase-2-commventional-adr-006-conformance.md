---
id: commventional-adr-006-conformance
plan: phase-2-pronto
status: closed
updated: 2026-04-29
---

# commventional — ADR-006 conformance: remove plugin-installed PreToolUse + PostToolUse hooks

## Scope

Bring `plugins/commventional/` into ADR-006 conformance. The plugin
ships **two** plugin-installed hooks today
(`hooks/hooks.json`):

1. **`PreToolUse` → `enforce-ownership.sh`.** Intercepts every
   `git commit` / `gh pr create` Bash invocation Claude makes,
   returns `hookSpecificOutput.updatedInput` rewriting the bash
   command to strip `Co-Authored-By:` trailers and `Generated
   with/by Claude` footers from the commit message before Claude
   executes. **ADR-006 §3 invariant 1 violation** — payload
   mutation through `updatedInput` is the canonical violation
   shape the ADR cites.
2. **`PostToolUse` → `pr-ownership-check.sh`.** Fires after every
   Bash invocation, filters for `gh pr (create|edit)`, fetches the
   resulting PR's body via `gh pr view`, runs the same
   trailer-stripping perl regex, and writes the cleaned body back
   via `gh pr edit --body-file`. **ADR-006 §2 violation** — the
   hook is wired into Claude Code event hooks to act on events
   the consumer didn't direct it to act on, and the action is a
   side effect into the consumer's GitHub repo (a PR body
   rewrite via the GitHub API, performed without consumer
   invocation per call).

This ticket removes both hooks, preserves the trailer-stripping
behaviour as a capability skill, and ships a consumer-invoked
install-helper that writes the equivalent hooks into the consumer's
own surface at consumer invocation. Capability preserved; trigger
moves to the consumer.

## Why this work, why now

ADR-006 was accepted with commventional named as a known violator
and this ticket cited as the remediation path. The ADR's
"Known non-conformance and remediation timeline" subsection sets the
deadline: **conformance required by Phase 2 close**. Until the
migration lands, `commventional` ships two documented violations,
noted in its README.

Beyond the deadline, the practical pressure: every `/smith` scaffold
post-Q1 will surface ADR-006 in the questionnaire, and every `/hone`
audit post-Q2 will score against a Pronto Compliance category that
includes "does this plugin install hooks at install time" as a
signal. Commventional being non-conformant against its own
constellation's audit standards is awkward at minimum.

## Architecture

### Two violations, one capability

Both hooks strip the same patterns (`Co-Authored-By:` trailers,
`Generated with/by Claude` footers) — they differ only in *where*
they strip:

| Hook | Surface stripped | Mechanism |
|---|---|---|
| `enforce-ownership.sh` | bash command payload (the commit-message arg) | `updatedInput` return |
| `pr-ownership-check.sh` | GitHub PR body | `gh pr edit --body-file` |

The capability is one thing — pattern-strip a text blob. The two
hooks are two different consumer-side wirings of the same
capability. The migration reflects that: one capability skill, one
install-helper that targets either or both wirings.

### Migration shape

Three new skills replace the two hooks:

1. **`commventional:strip-trailers`** — the capability. Takes a
   text blob via stdin or `--text` arg, returns the trailer-stripped
   equivalent on stdout. Same regex as the two hook scripts ship
   today (one perl substitution chain handling both patterns).
   Idempotent — running twice on the same input produces identical
   output.

2. **`commventional:strip-pr-body`** — convenience capability for
   the PR-body case. Takes a `--pr-url` arg, fetches the body via
   `gh pr view`, calls `:strip-trailers` on it, writes the cleaned
   body back via `gh pr edit --body-file`. The capability is
   directly invocable by the consumer — `/commventional:strip-pr-body
   --pr-url <url>` strips a single PR's body on demand.

3. **`commventional:install-trailer-stripper`** — install-helper.
   Accepts `--target <choice>` where choice is one of:
   - `claude-settings-user` — writes a `PreToolUse` hook to
     `~/.claude/settings.json` (global). Equivalent to today's
     `enforce-ownership.sh` scope.
   - `claude-settings-project` — writes to `<repo>/.claude/settings.json`
     (per-repo).
   - `git-commit-msg-hook` — writes a `commit-msg` script to
     `<repo>/.git/hooks/commit-msg` (catches manual commits too,
     broader than today's behaviour).
   - `pr-cleanup-hook-user` — writes a `PostToolUse` hook to
     `~/.claude/settings.json` calling `:strip-pr-body` on
     `gh pr (create|edit)` Bash calls. Equivalent to today's
     `pr-ownership-check.sh` scope.
   - `pr-cleanup-hook-project` — same, in project-scoped settings.
   - `all` — writes both a Claude-Code Pre/Post pair into the
     consumer's chosen settings scope.

   All targets prompt for confirmation and refuse to overwrite an
   existing file without `--force`.

ADR-006 §1 explicitly permits a skill that writes a hook at
consumer invocation — the consumer typing the slash command is the
directing act. ADR-006 §3 is satisfied because no
plugin-installed hook remains; the consumer wrote (or asked the
helper to write) any hook that exists post-migration.

### What's removed, what's preserved untouched

**Removed:**
- `plugins/commventional/hooks/hooks.json`
- `plugins/commventional/hooks/enforce-ownership.sh`
- `plugins/commventional/hooks/pr-ownership-check.sh`
- The `plugins/commventional/hooks/` directory itself (no other
  files live in it).

**Preserved untouched:**
- `plugins/commventional/skills/commventional/SKILL.md` — the
  existing auto-invoking skill that runs commventional's three
  conventions during commit / PR / review work. Its frontmatter
  (`user-invocable: false`) is the older skill convention; its
  migration to the ADR-005 §1 / skillet pattern
  (`disable-model-invocation: true`, `:audit` skill at
  `skills/audit/SKILL.md`) is the **separate Phase-2.5 thread**
  parked in `phase-2-pronto.md` Out-of-scope. This ticket touches
  neither the skill's content nor its frontmatter.
- `plugins/pronto/agents/parsers/scorers/score-commventional.sh` —
  the pronto-side scorer for the `commit-hygiene` dimension. Its
  fixtures at `plugins/commventional/test-fixtures/snapshots/`
  remain the scorer's regression bar; the new trailer-stripping
  fixtures this ticket adds are a separate test surface.
- All agent definitions under `plugins/commventional/agents/` —
  `commit-crafter`, `review-formatter`, etc. None reference the
  hook scripts or assume their behaviour.

### Frontmatter convention for new skills

Per ADR-005 §1, new skills use the skillet pattern:
`disable-model-invocation: true`. The new skills are
consumer-invocable only — the consumer types `/commventional:strip-trailers`
(or one of the others) explicitly; Claude does not auto-invoke
them. `allowed-tools` scoped narrowly per skill:
- `:strip-trailers` — `Bash` (for the perl invocation), nothing else.
- `:strip-pr-body` — `Bash` (gh + perl pipeline).
- `:install-trailer-stripper` — `Read, Write, Bash, AskUserQuestion`
  (read existing settings, write the new hook, prompt for
  confirmation).

### Fixtures (new test surface)

Currently no test surface exercises the trailer-stripping logic
directly — `test-fixtures/snapshots/` is the scorer's. This ticket
introduces the missing surface:

`plugins/commventional/test-fixtures/strip-trailers/cases.json` —
JSON array of `{name, input, expected}` triples. Minimum cases:

1. Commit message with single `Co-Authored-By:` trailer.
2. Commit message with multiple `Co-Authored-By:` trailers.
3. Commit message with `Generated with Claude Code` footer.
4. Commit message with `Generated by Claude` footer.
5. Commit message with both trailer + footer.
6. Commit message with `Co-authored-by:` (lowercase) — confirm
   case-insensitive matching matches today's behaviour.
7. PR body with the same patterns embedded in markdown structure.
8. Already-clean commit message (no trailers/footers) — idempotent
   passthrough.
9. CRLF-line-endings input (a known edge case in the current
   regex; document whether the fixture asserts the bug or the
   fix; either is acceptable as long as the call is explicit).

Cases are derived by running each input through today's
`enforce-ownership.sh` regex chain and recording the output as the
expected value. The test suite invokes
`commventional:strip-trailers` on each input and asserts equality
against expected. Drift between the two implementations on any
case is a ship-blocker.

### Version + breaking-change handling

The plugin-installed hook removal is a breaking change for any
consumer who's relied on the implicit behaviour. Bump
`plugins/commventional/.claude-plugin/plugin.json` `version` from
`1.1.0` to `2.0.0`. The README documents the migration in a
"Breaking changes in v2.0" section linking to ADR-006 and to the
`:install-trailer-stripper` skill, with copy-pasteable
invocations for the four most common consumer scenarios:

- "I want today's PreToolUse stripping back, globally" → run
  `/commventional:install-trailer-stripper --target claude-settings-user`.
- "I want today's PostToolUse PR cleanup back, globally" →
  `--target pr-cleanup-hook-user`.
- "I want both, globally" → `--target all`.
- "I want stripping on every git commit (including manual ones)" →
  `--target git-commit-msg-hook`.

The ticket lands the breaking change in one PR. Half-migrations
(hook still ships but emits a deprecation warning) would mean
shipping the §3 + §2 violations longer, which is exactly what the
deadline exists to avoid.

### README rewrite

Existing README has sections that describe the hooks as features:
"How It Works" table, "Two layers of enforcement (skill +
deterministic hook)", "Hook (deterministic safety net)". These
sections are removed or rewritten to:

- Describe the plugin's three conventions and the
  conventional-commit / conventional-comments skills as the
  primary surface.
- Add the **Example wirings** section per ADR-006's
  marketplace-wide deliverable, showing the three new skills and
  the four canonical install-helper invocations above.
- Add the **Breaking changes in v2.0** section.

The "Two layers of enforcement" framing is gone — there is one
layer (capabilities), and triggers belong to the consumer.

## Acceptance

- `git ls-files plugins/commventional/hooks/` returns empty (the
  directory is gone).
- `plugins/commventional/.claude-plugin/plugin.json` `version` is
  `2.0.0`.
- `plugins/commventional/skills/strip-trailers/SKILL.md` exists.
  Frontmatter: `name: strip-trailers`, `description: ...`,
  `disable-model-invocation: true`, `allowed-tools: Bash`,
  `argument-hint: --text <text> | < stdin`.
- `plugins/commventional/skills/strip-pr-body/SKILL.md` exists.
  Frontmatter: same shape, `allowed-tools: Bash`.
- `plugins/commventional/skills/install-trailer-stripper/SKILL.md`
  exists. Frontmatter: same shape,
  `allowed-tools: Read, Write, Bash, AskUserQuestion`.
- `plugins/commventional/skills/commventional/SKILL.md` exists
  unchanged from main (verify with `git diff main..<branch> --
  plugins/commventional/skills/commventional/`).
- `plugins/commventional/test-fixtures/strip-trailers/cases.json`
  exists with ≥ 9 cases as enumerated above. A test runner
  (`plugins/commventional/test-fixtures/strip-trailers/cases.test.sh`
  or similar shape matching the existing snapshot test pattern)
  invokes `:strip-trailers` on each case and asserts byte-identical
  match against expected. All cases pass.
- `plugins/commventional/README.md` no longer contains the
  strings "Two layers of enforcement", "deterministic hook",
  "deterministic safety net", or any other phrasing that
  describes plugin-installed hooks as a feature. README has an
  "Example wirings" section with the three new skills documented
  and the four install-helper invocations copy-pasteable. README
  has a "Breaking changes in v2.0" section referencing ADR-006.
- `/commventional:install-trailer-stripper --target
  claude-settings-user` against a clean `~/.claude/settings.json`
  produces a settings file that, when sourced by Claude Code,
  reproduces today's `enforce-ownership.sh` trailer-stripping
  behaviour on `git commit` and `gh pr create` Bash calls.
  Verified by running the same fixture-set Bash invocations
  through Claude Code with the new settings and observing
  byte-identical commit messages to today's behaviour.
- The pronto `commit-hygiene` dimension scorer
  (`score-commventional.sh`) and its fixtures
  (`test-fixtures/snapshots/`) are unchanged from main. Snapshot
  test suite passes unmodified.

## Three load-bearing invariants

A. **Behaviour-preservation, not behaviour-erasure.** A consumer
who relied on the hook behaviour today can fully restore it
post-upgrade by running the install-helper. The trailer-stripping
capability, the PR-body cleanup capability, and the regex itself
all survive the migration; only the plugin-installed *trigger*
moves to the consumer.

B. **No half-state.** The PR removes both hooks AND adds the three
skills AND the new fixtures in one merge. There is no
intermediate commit on the branch where the plugin claims ADR-006
conformance while still shipping either hook, and no commit where
the new skills exist without the test surface that proves they
work.

C. **The new fixtures are derived from the old hook's actual
behaviour, not from a hand-written specification.** Each case's
`expected` value is recorded by piping the case's `input` through
today's `enforce-ownership.sh` perl-regex chain and capturing the
output. This means the migration provably preserves the existing
behaviour rather than approximating it from spec — a divergence on
any case is a ship-blocker, not an acceptable design choice.

## Out of scope

- **Migrating the existing `skills/commventional/SKILL.md` to the
  ADR-005 §1 / skillet pattern** (`disable-model-invocation: true`,
  `:audit` skill at canonical path, `observations[]` emission).
  That's the Phase-2.5 migration thread parked in
  `phase-2-pronto.md` Out-of-scope. Both migrations land on
  commventional eventually; whichever lands first is fine.
- **Generalizing `install-trailer-stripper`'s wiring helper into
  a shared library.** ADR-006 §6 defers consumer-side
  organization to a future plan. If lintguini or other plugins
  later need similar install-helper skills, a shared library may
  emerge then; for now commventional ships a one-off.
- **Auto-detection of an already-installed hook before
  re-installing.** The v2.0 install-helper warns and asks for
  confirmation if the target file already exists. Idempotent
  re-runs are a v2.1 nicety.
- **Fixing the trailer-stripping regex's known edge cases**
  (CRLF line endings, attribution embedded in code blocks). The
  v2.0 capability ships the regex unchanged from today's
  behaviour. Improvements are filed separately.
- **The phase-2-pronto.md plan-roster update** to acknowledge
  this ticket. Small follow-up; not in this ticket's scope to
  avoid blowing up the PR.

## References

- `project/adrs/006-plugin-responsibility-boundary.md` — the ADR
  this ticket is the remediation for. §3 invariant 1
  (`enforce-ownership.sh`) and §2 (`pr-ownership-check.sh`) are
  the specific clauses violated.
- `project/plans/active/phase-2-pronto.md` — Phase 2 plan; this
  ticket is a Phase-2-close prerequisite per ADR-006's deadline.
- `plugins/commventional/hooks/enforce-ownership.sh` — removed by
  this ticket.
- `plugins/commventional/hooks/pr-ownership-check.sh` — removed
  by this ticket.
- `plugins/commventional/hooks/hooks.json` — removed by this
  ticket.
- `plugins/commventional/skills/commventional/SKILL.md` — preserved
  unchanged; its migration is separate Phase-2.5 work.
- `plugins/skillet/skills/audit/SKILL.md` — frontmatter convention
  for the new skills (`disable-model-invocation: true`).
- `project/adrs/005-sibling-skill-conventions.md` §1 — skill name
  + path convention; the new `:strip-trailers`,
  `:strip-pr-body`, and `:install-trailer-stripper` follow it.
