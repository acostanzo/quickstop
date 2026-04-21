---
id: t10
plan: phase-1-pronto
status: closed
updated: 2026-04-21
---

# T10 — Roll-your-own references

## Context

`plugins/pronto/references/roll-your-own/` — eight markdown docs, one per rubric dimension, describing how a consumer can achieve that dimension's readiness without installing the recommended sibling. Links are already wired: `recommendations.json` carries `roll_your_own_ref: "roll-your-own/<slug>.md"` for every dimension.

## Acceptance

- 8/8 dimensions covered: `claude-code-config.md`, `skills-quality.md`, `commit-hygiene.md`, `code-documentation.md`, `lint-posture.md`, `event-emission.md`, `agents-md.md`, `project-record.md`.
- Every doc under ~200 lines (max: 115 for lint-posture, min: 64 for claude-code-config, 690 total).
- Each doc ends with a **"Concrete first step"** section the reader can execute in the next five minutes.
- Portability grep (`anthony|batcomputer|batdev|batvault|alfred|grapple-gun|batctl|mind-palace`) inside the roll-your-own/ dir: zero matches.
- Each doc documents the presence check pronto applies for that dimension — so a reader who chooses roll-your-own still knows how the audit will treat their setup.

## Decisions recorded

- **Consistent doc shape across all eight.** Each carries: "What good looks like" → "Minimum viable setup" (with copy-pasteable scaffolding) → "Periodic audit checklist" → "Common anti-patterns" → "Presence check pronto uses" → "Concrete first step." Predictable shape means a reader who's skimmed one can skim the rest in seconds.
- **No recommendations to specific SaaS vendors in default paths.** Tool suggestions are open-source-first (Biome / Ruff / Pino / OpenTelemetry / Lefthook) — consumers can pick vendor tooling on top of these if they want.
- **Phase 2+ dimensions get full treatment now.** Inkwell / lintguini / autopompa don't exist yet, but the roll-your-own docs do — the dimensions are gradable today via presence + hand audit. Future siblings replace the depth measure, not the conventions.
- **`agents-md.md` explicitly acknowledges pronto as its own recommended path.** The dimension is kernel-owned; the "roll-your-own" framing covers users who'd rather not run `/pronto:init` but still want to land the scaffold by hand.
