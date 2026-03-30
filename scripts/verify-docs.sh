#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

npx --yes markdownlint-cli2@0.18.1 "**/*.md"
# Run one recursive link-check pass instead of spawning a fresh npx process per file.
npx --yes markdown-link-check@3.14.1 --ignore .git,node_modules .

rg -Fq 'Before plan, review, implementation, or audit work:' templates/AGENTS.md
rg -Fq '`AGENTS.md` is the entrypoint for repo-local instructions, not a complete Bright Builds spec.' templates/AGENTS.bright-builds.md
rg -Fq 'After install or update, treat downstream `AGENTS.md` as the local entrypoint, not the full Bright Builds spec.' AI-ADOPTION.md
rg -Fq 'Treat downstream `AGENTS.md` as the local entrypoint, not the full Bright Builds spec.' README.md
rg -Fq 'For downstream repos with Bright Builds installed, the required reading order is:' skills/personal-coding-standards/SKILL.md
