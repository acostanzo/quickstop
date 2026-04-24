#!/usr/bin/env bash
# Deterministic presence check for pronto audit fallback dimensions.
#
# Usage:
#   presence-check.sh <dimension> <REPO_ROOT>
#
# Prints exactly "100" if the presence check passes, "0" otherwise.
# No prose, no other output on stdout.
#
# This script exists so the audit orchestrator does not have to compose
# its own grep/glob/git invocations — every paraphrase is a determinism
# leak (Phase 1.5 PR 3b: event-emission stddev=15.7 in the baseline came
# from the sub-Claude composing different greps across runs). The
# orchestrator's only remaining job is to invoke this script with the
# right dimension slug.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") <dimension> <REPO_ROOT>" >&2
  exit 2
fi

DIM="$1"
REPO_ROOT="$2"

if [[ ! -d "$REPO_ROOT" ]]; then
  echo "Error: REPO_ROOT '$REPO_ROOT' is not a directory" >&2
  exit 2
fi

case "$DIM" in
  skills-quality)
    if compgen -G "${REPO_ROOT}/.claude/skills/*/SKILL.md" >/dev/null \
       || compgen -G "${REPO_ROOT}/plugins/*/skills/*/SKILL.md" >/dev/null
    then echo 100; else echo 0; fi
    ;;

  commit-hygiene)
    subj=$(git -C "$REPO_ROOT" log --no-merges -n 20 --pretty=format:'%s' 2>/dev/null || true)
    n=$(printf '%s\n' "$subj" | grep -c .)
    m=$(printf '%s\n' "$subj" \
        | grep -cE '^(feat|fix|chore|docs|refactor|test|perf|build|ci|style)(\([a-z0-9-]+\))?!?: .+' \
        || true)
    if [[ "$n" -gt 0 && "$((m * 100 / n))" -ge 80 ]]; then echo 100; else echo 0; fi
    ;;

  lint-posture)
    found=0
    for f in "${REPO_ROOT}"/.eslintrc* "${REPO_ROOT}"/.prettierrc* \
             "${REPO_ROOT}"/pyproject.toml "${REPO_ROOT}"/.flake8 \
             "${REPO_ROOT}"/rustfmt.toml "${REPO_ROOT}"/Cargo.toml \
             "${REPO_ROOT}"/.golangci.yml "${REPO_ROOT}"/biome.json \
             "${REPO_ROOT}"/dprint.json
    do
      [[ -e "$f" ]] && { found=1; break; }
    done
    if [[ "$found" -eq 1 ]]; then echo 100; else echo 0; fi
    ;;

  event-emission)
    if grep -rqE 'opentelemetry|OTEL_|tracer|metric|event_bus|eventbus|emit\(|structlog|pino|winston|logrus' \
         "$REPO_ROOT" \
         --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv \
         --exclude-dir=dist --exclude-dir=build 2>/dev/null
    then echo 100; else echo 0; fi
    ;;

  *)
    echo "Error: unknown dimension '$DIM' (expected one of: skills-quality, commit-hygiene, lint-posture, event-emission)" >&2
    exit 2
    ;;
esac
