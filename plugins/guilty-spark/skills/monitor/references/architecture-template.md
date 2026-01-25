# Architecture Documentation Template

Use this template for architecture documentation. Sentinels reference this for consistency.

## OVERVIEW.md Template

```markdown
# Architecture Overview

> Project: [Project Name]

## System Design

Brief description of the overall system architecture (3-5 sentences).

### High-Level Diagram

```
[Component A] → [Component B] → [Component C]
     ↓              ↓
[Storage]      [External API]
```

## Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| Frontend | React/Vue/etc | User interface |
| Backend | Node/Python/etc | API and business logic |
| Database | Postgres/etc | Data persistence |

## Key Architectural Decisions

| Decision | Rationale | Trade-offs | Date |
|----------|-----------|------------|------|
| Using X over Y | Brief explanation | What we gave up | YYYY-MM-DD |

## Directory Structure

```
project/
├── src/           # Description
│   ├── components/
│   └── services/
├── tests/         # Description
└── config/        # Description
```

## Data Flow

1. User action triggers...
2. Request flows to...
3. Processing happens in...
4. Response returns via...

## Integration Points

| System | Protocol | Purpose |
|--------|----------|---------|
| External API | REST/GraphQL | What it's for |
```

## Component Documentation Template

For `architecture/components/[component].md`:

```markdown
# [Component Name]

> Part of: [Parent System/Module]

## Purpose

What this component does and why it exists.

## Implementation

**Main files:**
- `path/to/main-file.ts` - Entry point
- `path/to/helpers.ts` - Support functions

## Decisions

| Decision | Why | Alternatives Considered |
|----------|-----|------------------------|
| Chose X | Reason | Y, Z |

## Dependencies

- **Requires:** Components this depends on
- **Used by:** Components that depend on this

## API Surface

If applicable, document the public interface.
```

## Writing Guidelines

1. **Focus on "why"** - Decisions and rationale matter more than "what"
2. **Keep current** - Only document the current state
3. **Reference code** - Include file paths for key implementations
4. **Avoid duplication** - Link to component docs instead of repeating
5. **Simple diagrams** - ASCII art preferred for portability
