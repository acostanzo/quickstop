---
id: 006
status: accepted
superseded_by: null
updated: 2026-04-29
---

# ADR 006 — Plugin responsibility boundary: capabilities, not automation

## Context

Quickstop's plugins encode opinionated tooling for plugin development, audit, code documentation, commit hygiene, and event observability. The marketplace is growing, and a pattern has been surfacing where authors are tempted to extend a plugin beyond its capability surface into the consumer's automation surface — scheduling itself, auto-installing hooks into the consumer's repo, wrapping its own cadences.

This conflates two surfaces that want to be separable:

1. **The capability surface** — what the plugin knows how to do. Skills, agents, references, scoring tools, scaffolding tools.
2. **The trigger surface** — when those capabilities run. On demand, on commit, on `Stop`, on a schedule, in CI, on save.

The current marketplace mixes both. Most plugins are clean: pronto, skillet, claudit, and avanti expose capabilities and let the consumer trigger them. A shipped violation lives in commventional, which installs a `PreToolUse` hook (`hooks/hooks.json`, `enforce-ownership.sh`) that intercepts every `git commit` / `gh pr create` invocation to strip `Co-Authored-By` trailers and `Generated with/by Claude` footers — automation that runs without the consumer asking for it on the current session, and that does so by mutating the bash payload via `hookSpecificOutput.updatedInput` before Claude executes it. Towncrier installs a `SessionStart` / `PreToolUse` / etc. hook bundle, but its hook script (`emit.sh`) is pure pass-through observability — reads the event payload from stdin, emits it to a configurable transport, exits without `hookSpecificOutput`. That shape is distinct from behaviour-modifying automation and wants explicit recognition rather than being lumped with the violation.

Without naming the boundary, three pressures push every new plugin toward the wrong side of it:

- **"Out-of-the-box magic" expectation.** Authors want `/plugin install foo` to do something visible immediately. Capability-only plugins look inert until invoked.
- **Composability lost.** When a plugin owns its trigger, the consumer can't compose it differently — can't disable it on one repo, can't move it from local to CI, can't sequence it after another plugin.
- **Plugin sprawl into daemons.** Once one plugin schedules itself, the next one must too, or it feels less polished. The marketplace becomes a collection of background processes the consumer didn't sign up for.

Phase 2 introduces several capability-shaped plugins (inkwell for documentation audit, lintguini for lint posture, the towncrier audit extension) where this question is live: should each plugin own its own scan cadence, hook installation, or PR gating? The answer needs to be written down before the ticket roster expands further.

## Decision

Quickstop adopts the principle: **plugins ship capabilities; consumers compose automation.**

### 1. The capability surface is what a plugin is for

A plugin's published surface is its skills, agents, references, and tools — invocable by the consumer (via slash command, sub-agent dispatch, or another plugin importing the capability). The plugin author's job is to make each capability:

- **Useful in isolation.** Runnable on demand without other plugins or specific consumer wiring.
- **Composable.** Consumable by another plugin (e.g. pronto importing a sibling's `:audit`) and by user-built automation (CI scripts, hooks, scheduled tasks the consumer owns).
- **Idempotent under normal use.** Calling the same capability twice with the same inputs should be safe — the consumer may compose the capability into multiple triggers.

Skills are bounded in what they may do at invocation time:

- **No persistent host state.** A skill does not write cron entries, install launchd / systemd units, start background daemons, or otherwise create state that outlives the invocation. A skill MAY *emit* a configuration file or script the consumer can install themselves — emitting a wiring artefact is capability-shaped; executing it is consumer-shaped.
- **No undeclared writes.** Side effects from a skill are scoped to channels the consumer chose: stdout/stderr, paths the consumer passed as arguments, or directories the skill's documentation names explicitly. A skill does not write into `.claude/`, `.git/hooks/`, or other repo paths the consumer didn't direct it to.

A skill that *installs* a hook at consumer invocation (writes a `commit-msg` script into `.git/hooks/` because the consumer ran `/foo:install-commit-hook`) is permitted — that's the consumer directing the wiring. The plugin is not permitted to install the same hook as a side effect of `/plugin install`.

### 2. The trigger surface belongs to the consumer

Decisions about *when* a capability runs — on every commit, nightly, in CI, on demand only — are the consumer's. Quickstop plugins do not:

- Install hooks into the consumer's repo (`commit-msg`, `pre-commit`, `post-merge`, etc.) as a side effect of plugin installation.
- Schedule themselves via cron, launchd, or any other host-level scheduler at plugin-install time.
- Wire themselves into Claude Code event hooks to act on events the consumer didn't direct them to act on (except as permitted by §3).
- Auto-trigger one of their own capabilities from another capability's run inside the same plugin.

The consumer decides triggers in their own surface: a script in their repo, a CI workflow, a `.claude/settings.json` they wrote, a scheduled task they own.

### 3. Pure-observability hooks are a permitted exception

A plugin MAY register Claude Code event hooks if and only if the hook is **pure observability**, defined by three runtime invariants the implementation must hold on every release:

1. **No payload mutation, no flow control.** The hook MUST exit cleanly without emitting `hookSpecificOutput` containing `updatedInput`, `updatedOutput`, `decision`, `behavior`, `permissionDecision`, or any other field the Claude Code hook spec defines as a return path into Claude's flow. The hook surface is exclusively a one-way emission *out* of Claude — never a return path *into* Claude's flow.
2. **No persistent host state established at hook time.** §1's host-state prohibition applies equally at hook time — no cron entries, daemons, or launchd units.
3. **No undeclared writes.** Any artefact the hook produces is written to a channel the consumer explicitly configured — a fifo, file path, or HTTP endpoint the consumer named in their plugin or environment configuration. The hook does not write into the consumer's repo, `.claude/`, or any path the consumer didn't direct it to.

The acid test, applied at code-review time: **does this hook return data that alters Claude's flow, or write anywhere the consumer didn't tell it to?** If either, it's automation and belongs in the consumer's surface. If neither — the hook only emits to a consumer-chosen channel and exits — it's permitted.

**Registered surface vs implemented behaviour.** §3 applies at the implementation level on every release, not at the registration level. A plugin that registers a `PermissionRequest` hook is not automatically a violation; a plugin whose `PermissionRequest` hook returns `behavior: allow` is. A future release that grows payload mutation behind a previously-clean hook is a release-time regression and a violation of this ADR. Plugin review verifies conformance per release, not just at first publication.

Towncrier's `emit.sh` is the canonical example of the carve-out. Commventional's `enforce-ownership.sh` is the canonical violation: it returns `hookSpecificOutput.updatedInput` to rewrite the bash command before Claude runs it.

### 4. Cross-plugin composition is allowed; intra-plugin auto-triggering is not

A plugin invoking another plugin's capability is allowed and expected: pronto invokes a sibling's `:audit`, hone audits smith-scaffolded output, a future learned answers questions another plugin's research agent asks. The constraint is direction-of-call: the consumer (or composing plugin) calls *into* the capability. The capability does not reach back out to dictate when the consumer runs other things.

The reconciliation with §2's "no auto-trigger from another capability" rule: cross-plugin composition is **consumer-composed**. By installing both plugins, the consumer has authorized the composing plugin to invoke the composed plugin's capability. Pronto invoking `claudit:audit` is the consumer running `/pronto:audit` (which the consumer typed), and pronto's job description (orchestrator) is exactly to dispatch siblings. Within a single plugin, by contrast, one capability calling another at run-time without consumer invocation is the plugin authoring its own automation in disguise.

ADR-005 §2 says pronto MAY call a sibling's `:doctor` to gate dispatch. That is consumer-composed cross-plugin invocation under this section: `:doctor` is a skill (capability surface), not a hook (trigger surface), and §3's hook constraints do not apply to it. The consumer composing pronto + sibling has authorized the gate-check.

### 5. Smith catches the mechanical shapes; review catches the rest

Smith — quickstop's internal plugin scaffolder, used to bootstrap new plugins in this repo — must surface the capability/trigger boundary in its Phase-2 questionnaire and refuse to scaffold structures that materialize an obvious violation. Concretely, smith declines to emit cron headers, plugin-install-time hook installers (anything matching the §3 violation shape), and self-scheduling daemons in scaffolded plugins, and asks the author to restate "runs on every commit" as a capability the consumer wires on commit.

Smith does not catch every violation — a skill that schedules a daemon at first invocation, a hook whose pure-observability shape grows behaviour over time, a `:doctor` that quietly mutates state — and isn't expected to. Subtle violations are caught by plugin review with this ADR as the reference.

The Q1 ticket (`project/tickets/open/quickstop-dev-tooling-q1-smith-enhancements.md`) is revised post-ADR-006 to add this surface to smith's questionnaire; hone's Pronto Compliance category in Q2 grows a corresponding signal that flags shipped violations.

### 6. Future scope: where consumer-side automation goes

Today, consumer-side automation lives where it's always lived: a consumer's `.claude/settings.json` for Claude Code event hooks, shell scripts in their repo for `commit-msg` / `pre-commit`-style git hooks, CI workflow files for pipeline triggers, and host-level schedulers (cron, launchd, systemd) for cadenced runs. Anthony's own Batcomputer wiring is the closest reference for how this looks at scale; the marketplace currently has no shared template for it.

A future plan may consolidate these patterns into a template repo, a composer-style plugin, or a documented set of `.claude/settings.json` examples. This ADR does not specify which — the decision recorded here is the boundary, not the consumer-side organization.

In the interim, plugin authors carry a concrete obligation: each plugin's README documents **example wirings** so consumers have copy-pasteable starting points (see Consequences).

## Consequences

### Positive

- **Plugins are smaller and more composable.** A plugin's surface is a list of capabilities, not a behaviour-on-install promise. Reasoning about what a plugin does collapses to "read its skill list."
- **The consumer keeps trigger control.** Disabling a capability on one repo, sequencing two plugins' work, or moving a check from local to CI is a consumer-side change, not a plugin-side change.
- **Test surface shrinks.** A capability-only plugin has unit-testable skills; an automation-bearing plugin has unit tests AND integration tests for the trigger. Capability-only is cheaper to maintain.
- **Marketplace-wide consistency.** A consumer installing N quickstop plugins gets N capability sets, not N background processes they didn't sign up for.
- **Third-party plugins are more naturally welcome.** A plugin author from outside quickstop already builds against the capability surface; they don't need to learn quickstop's automation conventions because there aren't any.

### Marketplace-wide deliverables

- **Each plugin's README gains an "example wirings" section.** Capability-only plugins look inert at install time, so consumers need a copy-pasteable starting point: how to compose `:audit` into a CI step, how to wire a skill into `.git/hooks/` from the consumer side, how to schedule a capability via the consumer's chosen scheduler. This is a uniform deliverable across the marketplace, not a per-plugin afterthought.

### Negative

- **"Just install this" stops being a one-step goal.** The trade is a one-time wiring step against permanent off-switch granularity. Every shipped trigger is one a consumer can't disable on a single repo or single workflow without uninstalling the plugin entirely; the boundary deliberately lives below the install/uninstall line.
- **Boilerplate at the consumer side.** Until the future-scope template repo / composer pattern exists, every consumer wires their own automation. Anthony's personal `.claude/` already does this informally; productizing it is deferred work.
- **Harder authoring decisions live earlier.** Authors must answer "what's my capability vs. what's the consumer's automation" at scaffold time rather than discovering it in production. Smith's questionnaire (§5) helps with the obvious shapes; subtler cases rely on plugin review.

### Known non-conformance and remediation timeline

Commventional ships a known §3 violation. The `PreToolUse` hook (`enforce-ownership.sh`) returns `hookSpecificOutput.updatedInput` to mutate the bash payload before Claude executes — exactly the shape §3 invariant 1 prohibits.

- **Migration shape.** The hook moves out of plugin-installed state into a consumer-invoked skill (e.g. `:install-trailer-stripper`) that writes the equivalent script into `.git/hooks/` only at consumer invocation. The trailer-stripping logic is preserved as a capability; the trigger moves to the consumer.
- **Deadline.** Conformance required by Phase 2 close. A remediation ticket is filed alongside this ADR's merge as a Phase 2 prerequisite. Commventional ships the violation in the interim with the non-conformance noted in its README.
- **Why `accepted` not `proposed`.** Principles create migration backlogs rather than being gated on them — ADR-005 followed the same pattern (claudit and commventional listed for migration without delaying acceptance). The boundary is ratified now; the named violator is in flight to conform.

### Neutral

- **Towncrier's observability hook is permitted but is a precedent that needs careful framing.** Authors reading the marketplace will see "towncrier ships hooks" and may misread it as a green light for behaviour-modifying hooks. §3's three runtime invariants and the registered-surface-vs-implemented-behaviour clause exist to keep the carve-out sharp, but plugin reviewers should expect to refer to them per release of any plugin that registers Claude Code event hooks.
- **The `:fix` skill name (reserved per ADR-005 §4) becomes more important.** A plugin that wants to remediate something must expose `:fix` and let the consumer trigger it; auto-fix-on-save is a consumer composition, not a plugin feature. The future ADR specifying `:fix` shape should reflect this composition expectation.

## Alternatives considered

### Bundled-automation (plugins include their own triggers)

Rejected. The cost of every plugin owning its trigger is paid by the consumer in lost composition, lost off-switch granularity, and a marketplace of background processes. The "out-of-the-box magic" benefit it buys is real but small — most consumers value control over polish here. The marketplace's growth thesis depends on plugins being small and composable; automation ownership pulls in the opposite direction.

### Per-plugin opt-in automation hooks

Rejected. "Plugin ships an automation toggle the consumer can flip" still bakes the trigger surface into the plugin. The toggle becomes another knob to maintain, the default is wrong for some consumers either way, and the line between "capability" and "automation toggle" gets re-litigated at every PR. Cleaner to put the trigger entirely in the consumer's surface.

### Centralized automation plugin (the "composer" idea)

Deferred, not rejected. A plugin whose job is to wire other plugins' capabilities into triggers is plausible, and a template repo is one shape it could take. Specifying it now would over-fit; better to let a few capability-only plugins ship, observe how consumers wire them in real repos, and let the composer shape emerge from real wiring patterns rather than speculation.

### Allow all hooks under "the consumer can uninstall the plugin"

Rejected. "Uninstall to disable" is a binary lever where the consumer wants a dial. Disabling commventional's trailer-stripping on one branch but keeping its commit-message capability available as a skill is a reasonable consumer ask; the current shipped shape can't honour it. The boundary lives below the install/uninstall granularity.

### Behaviour-change acid test instead of payload-mutation acid test

Rejected (during review of this ADR). An earlier draft framed the §3 test as "would removing the hook change the consumer's tool behaviour?" Under that framing, a hook that mutates `tool_input` could be argued past the test ("Claude still runs bash; behaviour is the same kind of thing, the input just differs"). The payload-mutation framing closes the loophole: any return of `updatedInput` / `updatedOutput` / `decision` / `behavior` / `permissionDecision` is automation, full stop, regardless of whether downstream observable behaviour appears to differ.

## Links

- ADR-001 — Meta-orchestrator model. Pronto's role as orchestrator that delegates rather than implements; this ADR generalizes the principle to all plugins.
- ADR-004 — Sibling composition contract. Cross-plugin composition mechanics; the direction-of-call rule in §4 here is consistent with ADR-004's loose-coupling posture.
- ADR-005 — Sibling skill conventions. `:audit`, `:doctor`, `:fix` are the capability-surface skill names this ADR's §1 ratifies; §4 here makes explicit that `:doctor` is a skill (not a hook) and pronto's gating call into a sibling's `:doctor` is consumer-composed cross-plugin invocation.
- Plan: `project/plans/active/quickstop-dev-tooling.md` — smith/hone optimization that depends on this ADR for questionnaire shape.
- Commventional remediation: filed as a follow-up ticket alongside this ADR's merge; non-conformance bounded by Phase 2 close.
