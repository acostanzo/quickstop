# Architecture Documentation Template

Use this template for architecture documentation. Sentinels reference this for consistency.

## OVERVIEW.md Template

```markdown
# Architecture Overview

> Project: [Project Name]

## System Design

Brief description of the overall system architecture (3-5 sentences).

### High-Level Diagram

```mermaid
flowchart TD
    subgraph Client
        A[Web App]
        B[Mobile App]
    end
    subgraph API Layer
        C[API Gateway]
        D[Auth Service]
    end
    subgraph Backend
        E[Core Service]
        F[Worker Service]
    end
    subgraph Data
        G[(Database)]
        H[(Cache)]
    end

    A --> C
    B --> C
    C --> D
    C --> E
    E --> F
    E --> G
    E --> H
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

### Request Lifecycle

```mermaid
sequenceDiagram
    participant C as Client
    participant G as Gateway
    participant S as Service
    participant D as Database

    C->>G: HTTP Request
    G->>G: Validate Token
    G->>S: Forward Request
    S->>D: Query Data
    D-->>S: Result Set
    S->>S: Transform Data
    S-->>G: Response
    G-->>C: HTTP Response
```

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

## Architecture

```mermaid
flowchart TD
    subgraph Component
        A[Entry Point]
        B[Core Logic]
        C[Data Access]
    end

    Input --> A
    A --> B
    B --> C
    C --> Output
```

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
5. **Use mermaid diagrams** - Preferred over ASCII art for maintainability and rendering

## Diagram Guidelines

### System Overview
Use `flowchart TD` with subgraphs to show major system components and their relationships.

### Data Flow
Use `sequenceDiagram` to show how requests flow through the system.

### Component Relationships
Use `flowchart` to show internal structure of complex components.

### Data Models
Use `erDiagram` to show entity relationships in the data layer.
