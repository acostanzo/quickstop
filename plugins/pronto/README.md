# Pronto

Meta-orchestrator for Claude-Code-readiness.

## The model

Pronto audits a repo against a **rubric of readiness dimensions** (Claude Code config, skills, commit hygiene, docs, lint posture, observability, AGENTS.md, project records). For each dimension it either:

- Runs the **recommended sibling plugin's audit** and folds the score in, or
- Reports **"not configured"** with an install command or a roll-your-own walkthrough.

Pronto doesn't re-implement what siblings do — `claudit` audits Claude Code config, `skillet` audits skills, `commventional` audits commit hygiene. Pronto owns the rubric, the orchestration, a minimal kernel (AGENTS.md scaffolding, `project/` container presence, `.pronto/` tool state), and a recommendation registry.

- [`references/rubric.md`](references/rubric.md) — the canonical dimensions, weights, owners, and presence-check rules.
- [`references/sibling-audit-contract.md`](references/sibling-audit-contract.md) — the `plugin.json` declaration schema and stdout JSON shape siblings emit against.
- [`references/report-format.md`](references/report-format.md) — the markdown scorecard template and the JSON composite shape produced by `/pronto:audit`.
- [`references/recommendations.json`](references/recommendations.json) — dimension-to-sibling recommendation registry.

## Commands

| Command | Purpose |
|---------|---------|
| `/pronto:init` | Scaffold the kernel into a target repo and propose recommended sibling installs |
| `/pronto:audit` | Run the full readiness audit — composite scorecard with per-dimension breakdown |
| `/pronto:status` | Show installed siblings, last audit score, dimensions below threshold |
| `/pronto:improve` | Walk lowest-scoring dimensions and offer per-dimension fix paths |

## Installation

### From marketplace

```bash
/plugin install pronto@quickstop
```

### From source

```bash
claude --plugin-dir /path/to/quickstop/plugins/pronto
```

## Architecture

```
plugins/pronto/
├── .claude-plugin/plugin.json
├── skills/
│   ├── audit/          # /pronto:audit orchestrator
│   ├── init/           # /pronto:init kernel scaffolder
│   ├── kernel-check/   # presence checks pronto always owns
│   ├── status/         # /pronto:status
│   └── improve/        # /pronto:improve
├── agents/
│   └── parsers/        # per-sibling output parsers (glue until siblings adopt the wire contract)
├── references/
│   ├── rubric.md                   # canonical dimensions, weights, owners
│   ├── sibling-audit-contract.md   # plugin.json declaration + stdout JSON schema
│   ├── recommendations.json        # dimension → recommended sibling + install command
│   └── roll-your-own/              # per-dimension manual-setup walkthroughs
└── templates/                      # kernel content /pronto:init drops into target repos
```

## License

MIT
