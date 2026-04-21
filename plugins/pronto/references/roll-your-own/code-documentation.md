# Roll Your Own — Code Documentation

How to achieve the `code-documentation` dimension's readiness without installing the forthcoming `inkwell` plugin.

Inkwell (Phase 2+) is the recommended depth auditor. Until it ships, every repo is in roll-your-own territory for this dimension. This document is what you do.

## What "good" looks like

- **README.md** at repo root answers the five arrival questions in under 50 lines:
  1. What does this project do?
  2. Who is it for?
  3. How do I install / run it?
  4. What's the status? (production / alpha / deprecated)
  5. Where do I go next?
- **`docs/`** (or equivalent) for anything longer than a README section. Organized by audience: `docs/users/`, `docs/contributors/`, `docs/reference/`.
- **Code comments are rare and surgical.** The *why* and the non-obvious invariant, never the *what*. Good naming does the what.
- **Examples compile / run.** Anything in a README code fence should work verbatim. If examples drift, CI catches it.
- **No dead links or stale screenshots.** A quarterly sweep is enough to catch most rot.

## Minimum viable setup

### README skeleton

```markdown
# <project>

<one-sentence what-and-why>

## Install

<copy-pasteable — 3 lines max>

## Usage

<one minimal example that works>

## Docs

See [docs/](docs/) for deeper detail.

## Status

<production | beta | alpha | experimental | deprecated>

## License

<SPDX identifier>
```

### docs/ layout

```
docs/
├── README.md               # index — what lives where
├── users/
│   ├── getting-started.md
│   └── faq.md
├── contributors/
│   ├── development.md
│   └── architecture.md
└── reference/
    ├── api.md
    └── configuration.md
```

Audience-scoped top-level dirs keep a reader from wading through contributor notes to find how to install the thing.

## Periodic audit checklist

- README >10 non-blank lines? (Kernel presence check.)
- Any code fence in the README that would fail if copy-pasted into a shell / interpreter now?
- Any file in `docs/` older than one year with no linkbacks from current code?
- Any diagram or screenshot showing UI / API state that's no longer true?
- `CHANGELOG.md` (or release notes) reflects the last few releases? Not three months behind?

## Common anti-patterns

- **"See the wiki."** Wikis drift faster than code and GitHub dumps them at the bottom of the repo UI. Prefer `docs/` in-tree.
- **`docs/TODO.md` as the project plan.** That belongs in `project/plans/` (or an issue tracker), not in public-facing docs.
- **API reference rotting in hand-maintained `.md`.** Generate it from source (rustdoc, godoc, pdoc, typedoc, Sphinx autodoc) if at all possible.
- **README that's mostly badges.** Badges are fine. If the reader has to scroll past 30 badges to find out what the project does, badges are wrong.

## Presence check pronto uses

Pronto's kernel presence check for this dimension passes if `README.md` exists at repo root with at least 10 non-blank lines. Presence-cap is 50 until `inkwell` ships or a manual depth audit runs.

## Concrete first step

Open your README right now. Trim it to answer the five arrival questions in under 50 lines. Move everything else to `docs/`. If the answer is "we don't have a `docs/`," create `docs/README.md` with a one-liner and migrate the overflow there.
