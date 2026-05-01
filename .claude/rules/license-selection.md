---
updated: 2026-04-30
---

# License Selection Rule

This rule governs how quickstop plugins choose and apply a license. It applies to every plugin scaffolded by `/smith` and every plugin reviewed by `/hone`.

## Decision tree

| Scenario | Default recommendation | Rationale |
|---|---|---|
| Plugin under `plugins/` intended for marketplace distribution | **MIT** | Marketplace convention; maximises consumer adoption without legal friction |
| Plugin with patent concerns or core developer tooling | **Apache-2.0** | Patent grant clause protects consumers of tooling with potential IP entanglement |
| Internal/private plugin not intended for marketplace | **No LICENSE** | No licence file is the correct statement for private work; MIT on private code signals intent that doesn't apply |
| Other | **Other** (author supplies text/path) | AGPL, BSD variants, MPL — rare in this context; author makes the choice explicitly |

## Non-negotiable directive

**Never default-pick a license silently.** Every plugin must have an explicit license choice by the author, surfaced before scaffolding is complete. A pre-highlighted suggestion is acceptable (MIT for marketplace plugins, No LICENSE for internal plugins), but the author must confirm it — a click or a typed affirmation. A plugin.json that contains `"license": "MIT"` because smith defaulted it without the author seeing the question is a violation of this rule.

## Mechanics (what to create)

| License choice | Files to create |
|---|---|
| **MIT** | `LICENSE` with standard MIT text; `Copyright (c) <current-year> Anthony Costanzo`. No NOTICE file. |
| **Apache-2.0** | `LICENSE` with canonical Apache 2.0 text. `NOTICE` file with project name, copyright, and standard boilerplate ("This product includes software developed at..."). |
| **No LICENSE** | Neither file. Omit the `license` field from `plugin.json` entirely. |
| **Other** | Author-supplied text written to `LICENSE`. No NOTICE unless the license requires it. |

## plugin.json field

When a license is chosen:
- **MIT** → `"license": "MIT"`
- **Apache-2.0** → `"license": "Apache-2.0"`
- **No LICENSE** → omit the `license` field entirely (do not write `"license": null` or `"license": ""`).
- **Other** → `"license": "<SPDX-identifier>"` if the license has one, or omit the field if it does not.

## README footer

When `license != none`, the README ends with:

```
## License

<License name>. See [LICENSE](LICENSE).
```

When `license == none`, omit the license section from the README.

## Pre-highlighting guidance for smith

Smith may pre-highlight a suggestion (not a silent default) using this logic:

- Plugin path starts with `plugins/` (marketplace path) AND role is `tool` or `sibling` → pre-highlight **MIT**.
- Plugin is internal / not under `plugins/` → pre-highlight **No LICENSE**.

The user-facing prompt must show the decision tree from the table above inline, so the user can override without reading this file separately.

## In-tree convention

Shipped quickstop marketplace plugins use MIT. The `plugin.json` files for pronto, claudit, commventional, skillet, avanti, and towncrier all carry `"license": "MIT"`. Smith-scaffolded plugins under `plugins/` follow the same convention when the user confirms MIT.
