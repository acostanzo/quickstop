# Pronto Kernel Templates

Template tree `/pronto:init` drops into a target repo. Sources here are copied verbatim to matching target paths, with two exceptions:

- `gitignore-additions.txt` is **appended** to the target's `.gitignore` (or used to create one if absent). It is never overwritten.
- `.gitkeep` files are placeholders that exist only to allow git to track empty directories. Consumers may delete them once real content lands in the corresponding dir.

## Target layout after `/pronto:init`

```
<target-repo>/
├── AGENTS.md
├── project/
│   ├── README.md
│   ├── plans/
│   ├── tickets/
│   ├── adrs/
│   └── pulse/
├── .claude/
│   └── README.md
├── .pronto/
│   └── state.json
└── .gitignore          (appended, not overwritten)
```

## Portability

All template content is portable: no author names, no hostnames, no absolute paths, no references to specific machines or organizations. Substitutions are applied by the init skill at copy time if needed — otherwise templates are literal.

## Rename map (source → target)

All paths map 1:1 except `gitignore-additions.txt`:

| Source | Target | Strategy |
|---|---|---|
| `AGENTS.md` | `AGENTS.md` | copy (refuse on conflict without `--force`) |
| `project/**` | `project/**` | copy (refuse on conflict without `--force`) |
| `.claude/**` | `.claude/**` | copy (skip files that already exist — consumers may already have `.claude/` configured) |
| `.pronto/**` | `.pronto/**` | copy (refuse on conflict without `--force`) |
| `gitignore-additions.txt` | `.gitignore` | append (merge — never overwrite existing lines) |
