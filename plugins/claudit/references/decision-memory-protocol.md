# Claudit Decision Memory Protocol

This reference defines the standard procedure for reading and writing claudit decision memory. Decision memory stores user responses to audit recommendations so future runs can present past context alongside new findings.

**Core principle:** Previous decisions are context, not constraints. Claudit always surfaces all recommendations — decisions annotate them, never suppress them.

## Storage Location

- **Project audits** (comprehensive scope): `{PROJECT_ROOT}/.claude/claudit-decisions.json`
- **Global-only audits**: `~/.cache/claudit/decisions.json`

Project decision files are committable — team members benefit from shared context. The `reason` field doubles as documentation for intentional deviations from best practice.

## Schema

```json
{
  "schema_version": 1,
  "decisions": [
    {
      "fingerprint": "over-engineering:restated-builtin:CLAUDE.md:a3f8c1d2",
      "category": "Over-Engineering",
      "recommendation": "Remove restated built-in: 'Always read files before editing'",
      "action": "rejected",
      "reason": "Team onboarding — keeping for junior devs",
      "decided_by": "acostanzo",
      "timestamp": "2026-03-24T10:30:00Z",
      "context": {
        "claudit_version": "2.4.0",
        "claude_code_version": "2.1.81",
        "score_impact": 10
      }
    }
  ]
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `fingerprint` | string | Composite key: `{category_slug}:{issue_type}:{file_stem}:{content_hash_8}` |
| `category` | string | Scoring category name (e.g., "Over-Engineering") |
| `recommendation` | string | The recommendation text as presented |
| `action` | enum | `accepted`, `rejected`, `alternative`, `deferred` |
| `reason` | string? | Optional user-provided reason (most valuable for `rejected`) |
| `decided_by` | string | Git user name (`git config user.name`) at decision time |
| `timestamp` | string | ISO 8601 timestamp |
| `context.claudit_version` | string | Plugin version at decision time |
| `context.claude_code_version` | string | Claude Code version at decision time |
| `context.score_impact` | number | Point impact at decision time |

### Action Types

| Action | Meaning | Future Behavior |
|--------|---------|-----------------|
| `accepted` | User applied the fix | If issue recurs, annotate as regression |
| `rejected` | User intentionally declined | Annotate with reason, check staleness |
| `alternative` | User took a different approach | Annotate with what they did instead |
| `deferred` | User will address later | Treat as new after 30 days |

## Fingerprinting

`{category_slug}:{issue_type}:{file_stem}:{content_hash_8}`

- **category_slug**: Slugified scoring category (see Issue Type Slugs table in scoring-rubric.md)
- **issue_type**: Normalized from rubric deductions (e.g., `restated-builtin`, `missing-binary`)
- **file_stem**: Target file basename (e.g., `CLAUDE.md`, `settings.json`) or `_global` for cross-file issues
- **content_hash_8**: First 8 chars of SHA-256 of the specific flagged content (see Hashing Guidance below)

### Hashing Guidance

The `content_hash_8` must be computed from a stable, deterministic input. Hash the **exact text of the configuration value or instruction being flagged**, trimmed of leading/trailing whitespace. Examples:

- **Restated built-in**: hash the quoted instruction text (e.g., `"Always read files before editing"`)
- **Hook sprawl**: hash the hook's `command` field value
- **Missing binary**: hash the MCP server's `command` field value
- **Verbose CLAUDE.md**: hash the file path being flagged (e.g., `CLAUDE.md`) since the issue is file-level, not line-level
- **Cross-file duplication**: hash the duplicated instruction text
- **Feature adoption**: hash the feature name (e.g., `"@import"`, `"rules directory"`)

If the flagged content is ambiguous or spans multiple lines, hash the first meaningful line. Consistency across runs matters more than perfect specificity — the structural match (same `category:issue_type:file_stem`) catches content-changed cases.

### Matching Algorithm

When a new recommendation is generated, compute its fingerprint and match against stored decisions:

1. **Exact match** (full fingerprint): High confidence. Past decision is directly relevant.
2. **Structural match** (same `category:issue_type:file_stem`, different hash): Content changed since the decision. Flag for re-evaluation with reason "config changed."
3. **No match**: New recommendation. No past decision applies.

## Staleness Rules

A past decision is flagged for re-evaluation when ANY condition is met:

| Condition | Reason | Check |
|-----------|--------|-------|
| Content hash changed | Config was modified since decision | Structural match but hash differs |
| Score impact delta >= 5 | Rubric or analysis weighted it differently | Compare `context.score_impact` to current |
| Claude Code version changed | Best practices may have evolved | Compare `context.claude_code_version` to current |
| Decision age > 90 days | Periodic re-evaluation | Compare `timestamp` to current date |
| Deferred age > 30 days | Deferred items expire sooner | Action is `deferred` and age > 30 days |

**Precedence:** The 30-day deferred expiry takes precedence over the 90-day general threshold for `deferred` items — report the 30-day reason, not both.

Stale decisions are annotated in the report with the specific staleness reason, prompting the user to re-evaluate.

## Read Procedure

1. Determine scope: comprehensive → read `{PROJECT_ROOT}/.claude/claudit-decisions.json`; global-only → read `~/.cache/claudit/decisions.json`
2. If file does not exist → `DECISION_HISTORY = []` (first run, no decisions yet)
3. If file exists, parse JSON and validate `schema_version` is 1
4. Store parsed `decisions` array as `DECISION_HISTORY`

## Write Procedure

1. Compute new decisions from Phase 4 selections
2. Load existing decisions (same read procedure)
3. Merge: new decisions overwrite any with matching `fingerprint` (upsert)
4. Write merged array back to file
5. For `decided_by`: run `git config user.name 2>/dev/null` and use the result (fall back to "unknown")
