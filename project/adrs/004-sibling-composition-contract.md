---
id: 004
status: accepted
superseded_by: null
updated: 2026-04-24
---

# ADR 004 — Sibling composition contract: loose coupling, version handshake, graceful degradation

## Context

The quickstop constellation is a set of plugins that compose — pronto delegates rubric-dimension audits to claudit, skillet, commventional, and eventually inkwell, lintguini, autopompa, and avanti. Phase 1 shipped the composition mechanically: `plugins/pronto/references/sibling-audit-contract.md` defines the wire format, `plugins/pronto/references/recommendations.json` maps dimensions to recommended siblings, and per-sibling parser agents bridge siblings that haven't yet adopted the contract natively.

What was never formally decided is the **posture** of that composition. Two questions have been left to convention:

1. **Version coordination** — does quickstop ship as a bundle (pronto 0.2.x requires claudit 2.y, etc.), or does each plugin version independently? If independent, how does pronto handle a claudit that's older or newer than what its parser expects?
2. **Graceful degradation** — pronto must run when zero siblings, some siblings, or all siblings are installed. The wire-contract doc sketches validation behaviour ("skip sibling, treat as not-configured"), and ADR 002 mentions "a gentle nudge, not a block" for missing siblings, but the full degradation ladder isn't written down in one place.

Compounding the choice: quickstop is public. A third-party could publish a sibling plugin that targets a pronto rubric dimension. Whether that pattern is first-class-supported or tolerated-but-unsupported is itself a decision we've been implicit about.

Three postures were on the table:

1. **Bundle / lockstep**. Pronto declares exact or minor-range pins on every sibling. Releases coordinate. Installing pronto pulls matching siblings.
2. **No coordination**. Each plugin ships independently. Pronto trusts siblings to emit a shape its parsers can handle, and breaks loudly when they don't.
3. **Loose coupling with a version handshake**. Plugins ship independently. Each sibling declares a pronto-version range it speaks to; pronto refuses to dispatch incompatible siblings and surfaces a finding rather than crashing. Every plugin is independently usable — pronto doesn't require siblings, and siblings don't require pronto.

## Decision

We choose **loose coupling with a version handshake** (option 3). The constellation plays well together but does not bind plugins to each other. A consumer can install one, some, or all plugins and get the benefit of each in isolation. Where plugins overlap, composition happens through a specified contract that either side can refuse.

Specifically:

### 1. Wire contract is ratified as the composition model

`plugins/pronto/references/sibling-audit-contract.md` defines the shape siblings emit on `--json` and the `plugin.json` declaration that makes a sibling discoverable. That document, and the `recommendations.json` registry beside it, are the official composition spec. Any plugin that conforms to the contract can participate — including plugins that live outside quickstop.

### 2. Version handshake, not lockstep

This ADR introduces a new optional field — `compatible_pronto` — under the `pronto` block in a sibling's `plugin.json`. No sibling declares it today; siblings adopt it as they opt into the handshake. Shape:

```json
{
  "name": "claudit",
  "version": "2.6.0",
  "pronto": {
    "compatible_pronto": ">=0.1.0 <0.3.0",
    "audits": [
      {
        "dimension": "claude-code-config",
        "command": "/claudit:audit --json"
      }
    ]
  }
}
```

Pronto checks the range at dispatch time:

- **In range** → dispatch the sibling's audit normally.
- **Out of range** → skip the sibling, score the dimension by presence only, emit a finding: *"claudit 2.6.0 declares compatibility with pronto <0.3.0; this pronto is 0.3.2. Sibling audit skipped; upgrade claudit to re-enable depth scoring."*
- **Unset** → assume compatible, emit a soft finding suggesting the sibling declare a range. No block.

Pronto's own version is read from its `plugin.json`. No sibling is ever pinned to a specific pronto version; ranges are the protocol.

### 3. Graceful degradation ladder

Pronto's behaviour as sibling state varies, consolidated in one place. This ladder covers sibling-delegated dimensions; kernel-owned dimensions (e.g. `agents-md`, audited via `/pronto:kernel-check`) are scored directly by pronto and do not traverse it.

| Sibling state | Pronto behaviour | Dimension score |
|---|---|---|
| Not installed, presence check passes | Recommendation ("install claudit for depth scoring") emitted. | Presence-only, capped per `rubric.md`. |
| Not installed, presence check fails | Recommendation + roll-your-own reference emitted. | 0 (no presence signal to score against). |
| Installed, contract-native (`plugin.json` declares audit) | Dispatch `--json` command; parse stdout directly. | Full depth score. |
| Installed, not yet contract-native | Dispatch sibling's default audit; hand output to registered parser agent; parse agent output. | Full depth score (parser-mediated). |
| Installed, version out of compatible range | Skip audit; emit version-mismatch finding. | Presence-only (capped). |
| Installed, declared audit emits invalid JSON | Skip audit; emit parse-error finding with captured stderr. | Presence-only (capped). |
| Installed, no contract and no parser registered | Skip audit; emit "unrecognized sibling" finding. | Presence-only (capped). |

The common thread: **no state crashes pronto**. Every degradation path produces a finding the consumer can act on.

### 4. Third-party plugins are first-class

Any plugin — in `quickstop`, in another marketplace, or in a private repo — that conforms to the wire contract and declares itself via `plugin.json` is a participating sibling. Pronto's runtime discovery is registry-first (`recommendations.json`), declaration-aware (scans installed plugins' `plugin.json`), and does not hardcode quickstop-only names.

A third-party sibling targeting an existing rubric dimension competes with the quickstop default; the audit declared by the installed plugin wins. If two installed plugins target the same dimension, pronto emits an ambiguity finding and picks the one sorted first alphabetically by plugin name (deterministic, documented, boring — a future ADR can introduce consumer-side priority if needed).

### 5. Explicit non-decisions

The following are **rejected** and documented here so the question doesn't re-open:

- **No bundled install.** Installing pronto does not install any sibling. Each plugin is an independent `/plugin install` action.
- **No required co-installation.** Pronto runs with zero siblings. Siblings run without pronto — their audits are useful in isolation, not only as pronto input.
- **No shared version constraint.** There is no "quickstop 1.x" that pins pronto-N / claudit-M / skillet-K. Each plugin versions on its own cadence.
- **No enforced release coordination.** Siblings and pronto release independently. The version handshake is the coordination surface.

## Consequences

### Positive

- **Each plugin is independently useful.** A consumer who only wants commit-hygiene checks installs commventional alone and gets value. Pronto is not a gate.
- **Third-party extension is unblocked.** Writing a new sibling is a spec-followed exercise, not a fork-of-quickstop exercise.
- **Version skew is recoverable.** A pronto consumer running a six-month-old claudit sees a version-mismatch finding, not a broken audit. They upgrade on their own schedule.
- **The contract is already in flight.** Wire-contract doc and recommendations registry pre-date this ADR; it ratifies what's already being implemented rather than proposing something new.

### Negative

- **Handshake drift is a real maintenance item.** Every pronto release that changes the wire contract must bump compatibility expectations, and siblings must update their declared ranges. We pay this in version-mismatch findings rather than in runtime crashes, which is the right trade, but it is not free.
- **The ambiguity rule is a papercut.** Two plugins targeting the same dimension is unusual but legal; the "alphabetical first declaration wins" tie-break is deterministic but arbitrary. If that bites, a future ADR can introduce explicit consumer-side priority.
- **Presence-only capping can feel punishing.** A consumer with a strong codebase but no siblings installed sees a ceiling on their audit score. This is by design — "presence only" is honest about what pronto can measure alone — but it invites an "install everything to pass" anti-pattern. Counter-signal: the rubric caps are conservative enough that "A" is reachable without all siblings.

### Neutral

- **Plugin authors outside quickstop get a stable target.** The sibling registry (`recommendations.json`) carries a `$schema_version` field; versioning the wire contract itself — adding a schema-version header to `sibling-audit-contract.md` — is a follow-up. Third-party siblings track both surfaces, not the quickstop release schedule.
- **Pronto iterates on its rubric independently.** Adding a new dimension does not require a sibling to exist — "presence only" is the honest fallback until the ecosystem catches up.

## Alternatives considered

### Bundled / lockstep versioning

Rejected. Bundling forces coordinated releases across N plugins. Pronto doesn't benefit from the coupling — its rubric aggregates independent dimensions, not a unified thing — and consumers lose the ability to update one plugin without chasing the rest of the constellation. The "minor lockstep" variant (pronto pins sibling minor versions) was considered and rejected for the same reason in weaker form. The user-facing cost of lockstep is the loss of the "one, some, or all" posture: once a bundle exists, using the constellation piecemeal stops being a supported path.

### No coordination at all

Rejected. Without a version handshake, pronto either trusts every installed sibling (and crashes on incompatible shapes) or refuses to trust any (and falls back to presence-only for everything). Both are worse than a declared range that degrades gracefully.

### Pronto-centric registry only (ignore sibling `plugin.json`)

Rejected. Registry-only means third-party siblings can't participate without a PR to quickstop. That defeats the "one, some, or all" posture at the ecosystem level. Sibling `plugin.json` declarations are the extensibility surface.

## Links

- Wire contract spec: `plugins/pronto/references/sibling-audit-contract.md`
- Sibling registry: `plugins/pronto/references/recommendations.json`
- Rubric + presence caps: `plugins/pronto/references/rubric.md`
- Related ADR: `project/adrs/001-meta-orchestrator-model.md` — pronto's role as orchestrator that delegates rather than implements.
- Related ADR: `project/adrs/002-avanti-scope-and-model.md` — established "either pronto or avanti can land first; the two compose cleanly when both are installed" as the composition principle this ADR formalizes across all siblings.
