#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v mdformat >/dev/null 2>&1 || {
  echo "mdformat must be available on PATH for downstream Markdown verification" >&2
  exit 1
}

npx --yes markdownlint-cli2@0.18.1 \
  "AGENTS.md" \
  "AI-ADOPTION.md" \
  "CHANGELOG.md" \
  "README.md" \
  ".codex/tasks/**/*.md" \
  "skills/**/*.md" \
  "standards/**/*.md" \
  "templates/**/*.md"
mdformat --check \
  "templates/AGENTS.md" \
  "templates/AGENTS.bright-builds.md" \
  "templates/CONTRIBUTING.md" \
  "templates/pull_request_template.md" \
  "templates/bright-builds-rules.audit.md" \
  "templates/standards-overrides.md"
# Run one recursive link-check pass instead of spawning a fresh npx process per file.
npx --yes markdown-link-check@3.14.1 -c .markdown-link-check.json --ignore .git,node_modules .

rg -Fq 'Before plan, review, implementation, or audit work:' templates/AGENTS.md
rg -Fq 'Use this routing map when deciding what to load next:' templates/AGENTS.md
rg -Fq 'use the canonical page `standards/core/verification.md`' templates/AGENTS.md
rg -Fq '`AGENTS.md` is the entrypoint for repo-local instructions, not a complete Bright Builds Rules spec.' templates/AGENTS.bright-builds.md
rg -Fq '## Routing hints' templates/AGENTS.bright-builds.md
rg -Fq 'Use the canonical page `standards/core/testing.md` for unit-test expectations.' templates/AGENTS.bright-builds.md
rg -Fq 'Before you start substantive implementation or other repo-changing work, sync first:' standards/core/verification.md
rg -Fq '`git pull --rebase` when that matches local guidance' standards/core/verification.md
rg -Fq 'Before substantive implementation work, sync first: fetch remote state before editing;' templates/AGENTS.bright-builds.md
rg -Fq '`git pull --rebase` when local guidance uses it' templates/AGENTS.bright-builds.md
rg -Fq 'Before substantive implementation work, sync first: fetch remote state before editing;' templates/CONTRIBUTING.md
rg -Fq '`git pull --rebase` when local guidance uses it' templates/CONTRIBUTING.md
rg -Fq 'After install or update, treat downstream `AGENTS.md` as the local entrypoint, not the full Bright Builds Rules spec.' AI-ADOPTION.md
rg -Fq 'Treat downstream `AGENTS.md` as the local entrypoint, not the full Bright Builds Rules spec.' README.md
rg -Fq 'Do Not Add Python Scripts To Bun-Friendly JS/TS Repositories' standards/languages/typescript-javascript.md
rg -Fq 'do not add new Python scripts for repo-owned automation' standards/languages/typescript-javascript.md
rg -Fq 'Prefer Stack-Aligned UI Libraries For TS/JS Frontends' standards/languages/typescript-javascript.md
rg -Fq 'prefer [MysticUI](https://github.com/pRizz/mystic-ui) for SolidJS apps and [MagicUI](https://github.com/magicuidesign/magicui) for React-based apps' standards/languages/typescript-javascript.md
rg -Fq 'pin the GitHub dependency to the latest available commit SHA at the time of adoption or update' standards/languages/typescript-javascript.md
rg -Fq 'Use the [MysticUI README](https://github.com/pRizz/mystic-ui/blob/main/README.md) as the source of truth' standards/languages/typescript-javascript.md
rg -Fq 'This repository uses Bun and TypeScript for repo-owned scripting.' AGENTS.md
rg -Fq '[![GitHub Stars](https://img.shields.io/github/stars/bright-builds-llc/bright-builds-rules)](https://github.com/bright-builds-llc/bright-builds-rules) [![Bright Builds: Rules](public/badges/bright-builds-rules-flat.svg)](https://github.com/bright-builds-llc/bright-builds-rules)' README.md
rg -Fq 'https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/public/badges/bright-builds-rules.svg' README.md
rg -Fq 'https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/public/badges/bright-builds-rules-flat.svg' README.md
rg -Fq 'https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/assets/badges/bright-builds-rules-dark.svg' README.md
rg -Fq 'https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/assets/badges/bright-builds-rules-light.svg' README.md
rg -Fq 'https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/assets/badges/bright-builds-rules-compact.svg' README.md
rg -Fq '[![Bright Builds: Rules](https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/public/badges/bright-builds-rules-flat.svg)](https://github.com/bright-builds-llc/bright-builds-rules)' README.md
rg -Fq 'For downstream repos with Bright Builds Rules installed, the required reading order is:' skills/bright-builds-rules/SKILL.md

old_skill_slug_part_one='personal'
old_skill_slug_part_two='coding-standards'
old_skill_slug="${old_skill_slug_part_one}-${old_skill_slug_part_two}"

if rg -n -F "$old_skill_slug" .; then
  echo "stale legacy skill references remain"
  exit 1
fi
