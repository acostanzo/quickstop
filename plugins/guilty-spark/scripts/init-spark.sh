#!/bin/bash
# Guilty Spark - Initialize Documentation Structure
# Creates the docs/ directory with standard structure

set -e

DOCS_DIR="docs"

# Create directory structure with error handling
if ! mkdir -p "$DOCS_DIR/architecture/components" 2>/dev/null; then
    echo "Guilty Spark: Error - Cannot create $DOCS_DIR/architecture/components" >&2
    echo "Check permissions and disk space" >&2
    exit 1
fi

if ! mkdir -p "$DOCS_DIR/features" 2>/dev/null; then
    echo "Guilty Spark: Error - Cannot create $DOCS_DIR/features" >&2
    exit 1
fi

# Get project name from directory (with fallback)
PROJECT_NAME=$(basename "$(pwd)" 2>/dev/null) || PROJECT_NAME="unknown"
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="unknown"
fi

# Create INDEX.md with write verification
{
    cat > "$DOCS_DIR/INDEX.md" << 'EOF'
# Documentation Index

> Maintained by Guilty Spark - The Monitor

## Quick Navigation

- [Architecture Overview](architecture/OVERVIEW.md) - System design and key decisions
- [Features](features/INDEX.md) - Feature documentation

## Documentation Structure

```
docs/
├── INDEX.md              # You are here
├── architecture/         # System design
│   ├── OVERVIEW.md       # High-level architecture
│   └── components/       # Component documentation
└── features/             # Feature documentation
    └── INDEX.md          # Feature inventory
```

## About This Documentation

This documentation is maintained by Guilty Spark, an autonomous documentation system.
Documentation is updated automatically at session end or before context clearing.

**Last Updated:** _Not yet initialized_
EOF
} || {
    echo "Guilty Spark: Error - Failed to write INDEX.md" >&2
    exit 1
}

# Verify INDEX.md was created
if [ ! -f "$DOCS_DIR/INDEX.md" ]; then
    echo "Guilty Spark: Error - INDEX.md not created" >&2
    exit 1
fi

# Create architecture/OVERVIEW.md
{
    cat > "$DOCS_DIR/architecture/OVERVIEW.md" << EOF
# Architecture Overview

> Project: $PROJECT_NAME

## System Design

_Awaiting first documentation capture_

## Key Decisions

| Decision | Rationale | Date |
|----------|-----------|------|
| _No decisions documented yet_ | | |

## Technology Stack

_To be documented_
EOF
} || {
    echo "Guilty Spark: Error - Failed to write architecture/OVERVIEW.md" >&2
    exit 1
}

# Create features/INDEX.md
{
    cat > "$DOCS_DIR/features/INDEX.md" << 'EOF'
# Features Index

## Documented Features

| Feature | Status | Last Updated |
|---------|--------|--------------|
| _No features documented yet_ | | |

## Feature Documentation Template

Each feature should have:
- **README.md** - Overview, purpose, and current implementation
- Code references to actual implementation files
EOF
} || {
    echo "Guilty Spark: Error - Failed to write features/INDEX.md" >&2
    exit 1
}

echo "Created documentation structure in $DOCS_DIR/"
exit 0
