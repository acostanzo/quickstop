---
name: audit
description: Audit code-documentation depth (README quality, docs coverage, staleness, internal link health) in a target codebase
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash
argument-hint: --json
---

# Inkwell:audit

Audit the target codebase for Code documentation and emit a v2 wire-contract envelope.

## Output

Emit exactly one JSON object to stdout:

```json
{
  "$schema_version": 2,
  "plugin": "inkwell",
  "dimension": "code-documentation",
  "categories": [],
  "observations": [],
  "composite_score": null,
  "recommendations": []
}
```

<!-- TODO: Fill in `observations[]` entries when scorers are wired up. Until then,
the empty array exercises the translator's case-3 passthrough — the dimension scores
by presence-only fallback. Each observation needs: id (stable string), kind (ratio |
count | presence | score), evidence (object), summary (string). See
plugins/pronto/references/sibling-audit-contract.md for the full field reference. -->
