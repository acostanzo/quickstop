---
id: 003
status: accepted
superseded_by: null
updated: 2026-04-21
---

# ADR 003 — Lifecycle state-machine model: folder-as-primary with frontmatter mirror

## Context

Avanti formalizes three distinct state machines — plans (`draft → active → done`), tickets (`open → in-progress → closed`), and ADRs (`proposed → accepted → superseded`). Representing an artifact's current state consistently across all three is a design choice with real ergonomics consequences.

Three representations were considered:

1. **Frontmatter-only**: each file carries `status:` in its frontmatter; the folder is either flat or organized by some other dimension (type, date, author). State is a property of the file content.
2. **Folder-only**: the directory a file sits in is the only indicator of state. Frontmatter carries no status field.
3. **Folder-as-primary with frontmatter mirror**: the folder is authoritative, and frontmatter `status:` mirrors it for machine-readability.

Compounding the choice: the ADR ecosystem in wide use — MADR, ADR-tools, Log4Brains — keeps ADRs in a single flat directory indexed by sequence number, because (a) the number is the primary index, (b) most ADRs end at `accepted` and stay there forever, and (c) supersession is explicit via cross-link, not re-filing. A single uniform rule for all three artifact types would either force ADRs into a non-standard layout or force plans/tickets into a state-in-frontmatter-only model that's harder to scan.

## Decision

We will use **folder-as-primary with frontmatter mirror** for plans and tickets, and **frontmatter-as-primary with flat folder** for ADRs. In both cases, `status:` appears in frontmatter; the difference is which source is authoritative:

- **Plans** live at `project/plans/{draft,active,done}/<slug>.md`. Folder is authoritative.
- **Tickets** live at `project/tickets/{open,closed}/<id>-<slug>.md`. Folder is authoritative for `closed`; inside `open/`, frontmatter distinguishes `open` vs `in-progress` (no third folder — the transition is frontmatter-only to keep merge surfaces narrow).
- **ADRs** live at `project/adrs/<NNN>-<slug>.md`. Folder is flat; frontmatter `status:` is authoritative. Supersession is recorded by `superseded_by: <id>` cross-link rather than a folder move.

`/avanti:promote` moves files (for plans/tickets) and updates frontmatter atomically; folder/frontmatter disagreement surfaced by `/avanti:audit` is a convention violation.

## Consequences

### Positive

- **Scannability** — `ls project/plans/active/` immediately shows what's in flight without opening files. Ditto `tickets/closed/`.
- **Two-source-of-truth with atomic updates** — the audit can detect folder/frontmatter mismatch as a hygiene signal, catching manual edits that forgot the `mv` or vice versa.
- **ADRs follow ecosystem convention** — tooling, references, and reader expectations around ADRs carry over cleanly. Numeric sequence as primary index is preserved.
- **Git history follows the file** across folder moves (git tracks by content, not path), so promotion doesn't fragment blame.

### Negative

- **Two rules to learn** instead of one — folder-primary for plans/tickets, frontmatter-primary for ADRs. Mitigated by `/avanti:promote` doing the right thing regardless; consumers rarely reason about the distinction directly.
- **Merge conflicts on status changes** — two agents promoting different artifacts in the same minute touch the same frontmatter block pattern. Manageable, but noisier than frontmatter-only.

### Neutral

- Tickets don't get a third folder for `in-progress`. The open-to-in-progress transition is a frontmatter edit that keeps the file in `tickets/open/`. This matches how tickets flow in practice (most tickets pass through in-progress briefly) and avoids adding churn for a state change that usually lives minutes-to-days.
- Supersession links are explicit (`superseded_by` / `supersedes`), meaning a reader can follow the chain without directory archaeology.

## Alternatives considered

### Frontmatter-only for all three types

Rejected. Scannability suffers — listing "what plans are active" requires reading every file's frontmatter. Atomic transitions become harder because there's no move to anchor on. Lose the git-pattern of `ls project/plans/active/` showing work in flight.

### Folder-only for all three types

Rejected. ADRs would land at `project/adrs/proposed/003-foo.md`, forcing a rename on every promotion and breaking the ecosystem convention of `003-foo.md` as a stable citation path. Supersession across folders fragments readability.

### Branch-based state (feature branches for draft plans, main for active)

Rejected. Tangles SDLC lifecycle with git branching conventions, which are already doing load-bearing work around code review. An "active plan" has nothing to do with whether its code review is complete; conflating the two would create cross-domain edge cases that neither system handles cleanly.

### External issue tracker as source of truth

Rejected. Consumers range from "heavy Linear users" to "no issue tracker at all." Storing SDLC state in a JIRA or Linear requires a consumer-owned integration — deliberately out of scope for avanti.

## Links

- Plan: `project/plans/active/phase-1-avanti.md`
- Related ADR: `project/adrs/002-avanti-scope-and-model.md` — the plugin that implements this state-machine model.
- Conventions: `plugins/avanti/references/sdlc-conventions.md` — the reference doc consumers read.
