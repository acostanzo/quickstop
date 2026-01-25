#!/bin/bash
# Guilty Spark - Initialize Documentation Structure
# Creates the docs/ directory with standard structure

set -e

DOCS_DIR="docs"

# Create directory structure
mkdir -p "$DOCS_DIR/architecture/components"
mkdir -p "$DOCS_DIR/features"

# Get project name from directory
PROJECT_NAME=$(basename "$(pwd)")

# Create INDEX.md
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

# Create architecture/OVERVIEW.md
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

# Create features/INDEX.md
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

echo "Created documentation structure in $DOCS_DIR/"
