---
name: audit
description: Audit a target codebase's event-emission posture and emit a wire-contract envelope on stdout
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash
argument-hint: --json
---

# Towncrier:audit

Audit the target codebase for event-emission posture and emit a v2 wire-contract envelope.

## Output

Emit exactly one JSON object to stdout:

```json
{
  "$schema_version": 2,
  "plugin": "towncrier",
  "dimension": "event-emission",
  "categories": [],
  "observations": [],
  "composite_score": null,
  "recommendations": []
}
```

<!-- TODO: Fill in `observations[]` entries when scorers are wired up. Until then,
the empty array exercises the translator's case-3 passthrough — the dimension scores
by presence-only fallback (observability instrumentation grep matches → 50 capped).
Each observation needs: id (stable string), kind (ratio | count | presence | score),
evidence (object), summary (string). See
plugins/pronto/references/sibling-audit-contract.md for the full field reference. -->
