# Audit Thresholds

Tunable knobs for `/avanti:audit`. Phase 1 ships lenient defaults to avoid nagging before calibration data exists. Consumers tighten these as usage accumulates and real patterns emerge.

## Knobs

| Knob | Default | Category | Rationale |
|---|---|---|---|
| `STALE_PLAN_DAYS` | `60` | Plan freshness | An active plan with no commit for two months is either done-but-not-promoted or abandoned. Either way, the scorecard should surface it. Sixty days is lenient enough that a plan in deliberate hibernation won't nag; tighten to 30 once teams settle into a cadence. |
| `TICKET_AGE_WARN_DAYS` | `45` | Ticket hygiene | A ticket that has sat in `open/` with `status: open` (never promoted to `in-progress`) for a month and a half has probably aged out of useful context. Forty-five days reflects the real tempo of most SDLC work without flagging genuinely long tickets. Tighten to 21 for aggressive teams. |
| `PULSE_CADENCE_WARN_DAYS` | `30` | Pulse cadence | Pulse is a freshness signal — has anyone been working in this repo lately? Thirty days says "nothing in a month." Noisier defaults (7 days) are appropriate for an actively-worked repo; the Phase 1 default is calibrated for mixed-cadence usage. |

## Scoring summary

Each category starts at 100 and deducts based on findings. See `skills/audit/SKILL.md` for the exact deduction rules per finding severity (`critical | high | medium | low`; `info` is informational and does not deduct). The four categories are weighted 0.30 / 0.30 / 0.20 / 0.20 into a composite score, which maps to a letter grade via the bands documented in the pronto wire contract (A+ 95-100, A 90-94, B 75-89, C 60-74, D 40-59, F 0-39).

## Overrides

Thresholds can be overridden at two scopes — repo and artifact.

### Repo-wide: `.avanti/config.json`

Place a JSON file at `<repo-root>/.avanti/config.json` with a `thresholds:` block:

```json
{
  "thresholds": {
    "stale_plan_days": 30,
    "ticket_age_warn_days": 21,
    "pulse_cadence_warn_days": 7
  }
}
```

Any key present replaces the default. Keys not present fall back to the defaults in the table above. `.avanti/` itself is tool state — hidden, tool-named, committable when the overrides should be team-shared (as they usually are).

### Per-artifact frontmatter: `audit_ignore: true`

An individual plan, ticket, or ADR can opt itself out of staleness scoring by adding `audit_ignore: true` to its frontmatter:

```yaml
---
phase: 2
status: active
tickets: [t1, t2]
updated: 2026-04-21
audit_ignore: true
---
```

`audit_ignore: true` means "count me in presence checks, but do not count me in staleness or cadence deductions." Use for:

- Plans that are intentionally long-running (e.g., a running backlog dumping ground).
- Tickets intentionally parked awaiting an external dependency.
- Any artifact where the staleness signal is a false positive the author has already judged.

The audit surfaces `audit_ignore: true` artifacts in verbose output so the pattern doesn't become a quiet way to hide rot.

## Calibration

Phase 1 ships these defaults unchanged. Consumers should tighten them once real data shows what "normal" cadence looks like in their repo. Two suggested calibration points:

- **After 3 months of usage**: review the first pass of staleness findings. If more than 20% are false positives, loosen the relevant knob. If fewer than 5% are flagged, tighten.
- **On team onboarding change**: re-evaluate — a bigger team can sustain tighter thresholds.

Document chosen overrides in the repo's `AGENTS.md` or a short ADR so future readers know why the defaults were changed.
