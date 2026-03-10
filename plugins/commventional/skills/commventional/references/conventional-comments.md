# Conventional Comments Specification Summary

Source: https://conventionalcomments.org/

## Format

```
<label> [decorations]: <subject>

[discussion]
```

## Labels

Every comment MUST be prefixed with a label. Labels indicate the kind of feedback.

| Label | Description | Blocking Default |
|-------|-------------|-----------------|
| **praise** | Highlights something positive. Doesn't need to be conditional or have a suggestion. | Non-blocking |
| **nitpick** | Trivial, preference-based suggestions. By definition, nitpicks are non-blocking. | Non-blocking |
| **suggestion** | Proposes improvements to the current subject. Reader should be free to decide whether to apply. | Non-blocking |
| **issue** | Highlights a specific problem with the subject. If not paired with a suggestion, it's at least expected to be discussed. | Blocking |
| **question** | Asks for clarification about the subject. Implies there may be a need for improvement but is not certain. | Non-blocking |
| **thought** | Represents an idea that popped up from reviewing. Not a direct change request, but seeds for potential future improvement. | Non-blocking |
| **chore** | Simple tasks that must be done before merging. Usually involves no discussion — cleanup, renaming, etc. | Blocking |
| **typo** | A typographical or spelling error. Like chore, typically requires no discussion. | Blocking |

## Decorations

Optional metadata in parentheses after the label:

| Decoration | Meaning |
|------------|---------|
| **(non-blocking)** | The comment should not prevent merging. Used to explicitly override a label's default blocking behavior. |
| **(blocking)** | The comment should prevent merging until resolved. Used to override non-blocking defaults. |
| **(if-minor)** | Shorthand for "I don't feel strongly about this, but if the change is minor, consider it." |

## Examples

```
praise: Clean extraction of the validation logic into its own module.
```

```
nitpick: `hasUserAccess` would be a clearer name than `checkAccess`.
```

```
suggestion: Consider using a guard clause to reduce nesting.

This would flatten the control flow and make the happy path more obvious.
Early returns are idiomatic in this codebase.
```

```
issue (blocking): This query has no index and will cause a full table scan.

The `users` table has 2M rows. Without an index on `email`,
this query will degrade as the table grows.
```

```
question: What happens if `config` is undefined here?

I don't see a default value or null check, but maybe the caller
guarantees it's always present?
```

```
thought: This pattern might benefit from the Strategy pattern if we add
more payment providers in the future.
```

```
chore: Remove this unused import.
```

```
suggestion (if-minor): Prefer `const` over `let` since this value is never reassigned.
```

## Best Practices

1. **Always use a label** — unlabeled comments are ambiguous about intent and urgency
2. **Use decorations to clarify blocking status** — especially when overriding the default
3. **Be specific in the subject** — "this is wrong" is less useful than "this will NPE on null input"
4. **Keep discussion optional** — if the subject says it all, don't pad with filler
5. **Praise genuinely** — calling out good decisions reinforces positive patterns
6. **Use nitpick honestly** — don't disguise blocking issues as nitpicks to seem polite
7. **One concern per comment** — don't bundle unrelated feedback into a single comment
