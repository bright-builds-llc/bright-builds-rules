#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

npx --yes markdownlint-cli2@0.18.1 "**/*.md"

while IFS= read -r -d '' file; do
  npx --yes markdown-link-check@3.14.1 "$file"
done < <(find . -type f -name '*.md' -not -path './.git/*' -print0 | sort -z)
