---
name: search
description: Full-text search over the repo's `docs/` tree (FTS5-backed). Returns ranked hits with file paths, tags, and matching snippets.
allowed-tools: Bash
argument-hint: <query>
---

# Inkwell:search

Thin wrapper over `bin/inkwell-search.sh`. Run the bash script with the
user's query verbatim and pass stdout through unchanged.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/inkwell-search.sh" "<QUERY>" "<REPO_ROOT>"
```

`<QUERY>` is everything the user supplied as arguments. `<REPO_ROOT>`
is the absolute path to the target repository — typically the working
directory when `/inkwell:search` was invoked.

The bash script invokes `inkwell-index.sh` first, so the index is
always current relative to the on-disk `docs/` tree. The on-write
contract for `/inkwell:doc` follows from this: a doc written one moment
ago is searchable the next moment without any explicit reindex step.

## Output shape

Each hit is one line:

```
docs/auth/session.md:12  [auth, security]  ...validateSession verifies the JWT and...
```

`path:line` is followed by the doc's tags and a snippet of the matching
context. Ranking is FTS5's default (`bm25`) — most-relevant first, capped
at 25 hits. No hits → empty stdout, exit 0.

## Query syntax

The index uses FTS5's `porter unicode61` tokenizer. Bare tokens are
stemmed (`validation` matches `validates`), but porter does not stem
short prefixes — for broad matching, use a prefix wildcard:

```
/inkwell:search auth*       # matches authentication, authorize, etc.
/inkwell:search "JWT token" # phrase query
/inkwell:search auth NOT session
```

## Empty-scope contract

If `docs/` is missing or empty, the script exits 0 with `no documents
indexed` on stderr and empty stdout — search must never crash a
writer's flow on a fresh repo. Surface the stderr message to the
user verbatim when it appears; do not retry or fabricate hits.

## What this skill does not do

- No vector search. v1 is FTS5 only (deferred to v2 per ADR-007 / plan).
- No answer synthesis, no citation rollup. That's `/inkwell:query` (T3).
- No mutation of `docs/` or any consumer artefact. ADR-006 §2 holds.
