#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

npx --yes markdownlint-cli2@0.18.1 "**/*.md"
# Run one recursive link-check pass instead of spawning a fresh npx process per file.
npx --yes markdown-link-check@3.14.1 --ignore .git,node_modules .
