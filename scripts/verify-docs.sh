#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

print_mdformat_install_instructions() {
  cat >&2 <<'EOF'
Install the required Markdown formatter stack with Python 3.13+:
  pipx install 'mdformat==1.0.0' --python python3.13
  pipx inject mdformat 'mdformat-frontmatter==2.1.2' 'mdformat-gfm==1.0.0'
EOF
}

command -v mdformat >/dev/null 2>&1 || {
  echo "mdformat 1.0.0 with the frontmatter 2.1.2 and GFM 1.0.0 extensions must be available on PATH" >&2
  print_mdformat_install_instructions
  exit 1
}

mdformat_version="$(mdformat --version)"
if [[ "$mdformat_version" != "mdformat 1.0.0" && "$mdformat_version" != "mdformat 1.0.0 ("* ]]; then
  echo "incompatible mdformat core version: expected 1.0.0, found '$mdformat_version'" >&2
  print_mdformat_install_instructions
  exit 1
fi

mdformat_probe_dir="$(mktemp -d)"
trap 'rm -rf "$mdformat_probe_dir"' EXIT
mdformat_probe="$mdformat_probe_dir/extension-probe.md"
printf '%s\n' \
  '---' \
  'title: Markdown extension probe' \
  '---' \
  '' \
  '| Extension           | Enabled |' \
  '| ------------------- | ------- |' \
  '| frontmatter and GFM | true    |' >"$mdformat_probe"

if ! mdformat \
  --check \
  --extensions gfm \
  --extensions frontmatter \
  --no-codeformatters \
  --wrap keep \
  --end-of-line lf \
  "$mdformat_probe" >/dev/null 2>&1; then
  echo "mdformat cannot load the required frontmatter and GFM extensions" >&2
  print_mdformat_install_instructions
  exit 1
fi

npx --yes markdownlint-cli2@0.18.1 \
  "AGENTS.md" \
  "AI-ADOPTION.md" \
  "CHANGELOG.md" \
  "README.md" \
  ".codex/tasks/**/*.md" \
  "skills/**/*.md" \
  "standards/**/*.md" \
  "templates/**/*.md"
mdformat \
  --check \
  --extensions gfm \
  --extensions frontmatter \
  --no-codeformatters \
  --wrap keep \
  --end-of-line lf \
  .
# Run one recursive link-check pass instead of spawning a fresh npx process per file.
npx --yes markdown-link-check@3.14.1 -c .markdown-link-check.json --ignore .git,node_modules .

rg -Fq 'Before plan, review, implementation, or audit work:' templates/AGENTS.md
rg -Fq 'Use this routing map when deciding what to load next:' templates/AGENTS.md
rg -Fq 'use the managed standards page `standards/core/frontend-ui.md`' templates/AGENTS.md
rg -Fq 'use the managed standards page `standards/core/verification.md`' templates/AGENTS.md
rg -Fq 'bun scripts/bright-builds-check.ts all' templates/AGENTS.md
rg -Fq '`AGENTS.md` is the entrypoint for repo-local instructions, not a complete Bright Builds Rules spec.' templates/AGENTS.bright-builds.md
rg -Fq '## Routing hints' templates/AGENTS.bright-builds.md
rg -Fq 'Use the managed standards page `standards/core/frontend-ui.md` for frontend visual defaults, theme defaults, dark-mode decisions, and public open-source source/FOSS/maintainer disclosure.' templates/AGENTS.bright-builds.md
rg -Fq 'Use the managed standards page `standards/core/testing.md` for unit-test expectations.' templates/AGENTS.bright-builds.md
rg -Fq 'Frontend experiences should default to dark mode' templates/AGENTS.bright-builds.md
rg -Fq 'New TypeScript/JavaScript web frontends should default to SolidJS' templates/AGENTS.bright-builds.md
rg -Fq '## Load And Maintain Active Lessons Within A Bounded Context Budget' standards/core/local-guidance.md
rg -Fq 'combined size is at most 24,000 bytes' standards/core/local-guidance.md
rg -Fq 'summed conservative estimate `ceil(file_bytes / 3)` is at most 8,000 tokens' standards/core/local-guidance.md
rg -Fq 'when no audit baseline exists' standards/core/local-guidance.md
rg -Fq 'first crosses 75% of either budget' standards/core/local-guidance.md
rg -Fq 'when 90 days have elapsed and active lesson content changed' standards/core/local-guidance.md
rg -Fq 'when 10 active lessons have been added since the prior audit' standards/core/local-guidance.md
rg -Fq 'before an append projected to exceed either full budget' standards/core/local-guidance.md
rg -Fq 'must not recursively retrigger solely because the set remains above that threshold' standards/core/local-guidance.md
rg -Fq 'read the repository-owned active set in full within the default 24,000-byte and 8,000-estimated-token budgets' templates/AGENTS.bright-builds.md
rg -Fq 'Normal install and update must not create or edit downstream lesson, audit, or archive files.' templates/AGENTS.bright-builds.md
rg -Fq 'Public open-source web apps and sites must expose source repository access in stable product chrome' templates/AGENTS.bright-builds.md
rg -Fq 'Disclose Public Open-Source Project Identity In Product Chrome' standards/core/frontend-ui.md
rg -Fq 'Only describe the project as `free and open source` when the repository and license actually support that claim.' standards/core/frontend-ui.md
rg -Fq 'mention Peter Ryszkiewicz and link to `https://openlinks.us/`' standards/core/frontend-ui.md
rg -Fq 'link public GitHub commits and CI run-backed build times when URLs are available' templates/AGENTS.bright-builds.md
rg -Fq 'open external provenance links in new tabs safely' templates/AGENTS.bright-builds.md
rg -Fq 'copyable summaries as optional support affordances' templates/AGENTS.bright-builds.md
rg -Fq 'short commit hash, usually 7-12 characters' standards/core/operability.md
rg -Fq 'external source and CI provenance links should open in a new tab or window' standards/core/operability.md
rg -Fq 'rel="noopener noreferrer"' standards/core/operability.md
rg -Fq 'https://github.com/example/admin/actions/runs/123456789' standards/core/operability.md
rg -Fq 'Before you start substantive implementation or other repo-changing work, sync first:' standards/core/verification.md
rg -Fq '`git pull --rebase` when that matches local guidance' standards/core/verification.md
rg -Fq '## Honor Markdown Dialects and Formatter Contracts' standards/core/verification.md
rg -Fq 'Do not fall back to bare `mdformat` or another generic formatter when the repository requires syntax extensions or plugins that are unavailable.' standards/core/verification.md
rg -Fq 'Before substantive implementation work, sync first: fetch remote state before editing;' templates/AGENTS.bright-builds.md
rg -Fq '`git pull --rebase` when local guidance uses it' templates/AGENTS.bright-builds.md
rg -Fq 'Never fall back to bare `mdformat` when required plugins are unavailable.' templates/AGENTS.bright-builds.md
rg -Fq 'optional user-owned `.bright-builds-rules-checks.tsv`' templates/AGENTS.bright-builds.md
rg -Fq 'Before substantive implementation work, sync first: fetch remote state before editing;' templates/CONTRIBUTING.md
rg -Fq '`git pull --rebase` when local guidance uses it' templates/CONTRIBUTING.md
rg -Fq 'Never fall back to bare `mdformat` when required plugins are unavailable.' templates/CONTRIBUTING.md
rg -Fq 'Run `bun scripts/bright-builds-check.ts all`' templates/CONTRIBUTING.md
rg -Fq '`bun scripts/bright-builds-check.ts all` ran and passed' templates/pull_request_template.md
rg -Fq 'After install or update, treat downstream `AGENTS.md` as the local entrypoint, not the full Bright Builds Rules spec.' AI-ADOPTION.md
rg -Fq 'Preserve any downstream `.mdformat.toml` and arbitrary user-authored Markdown.' AI-ADOPTION.md
rg -Fq '`Checks CI: enabled|disabled`' AI-ADOPTION.md
rg -Fq '`scripts/bright-builds-check.ts`' AI-ADOPTION.md
rg -Fq 'Treat downstream `AGENTS.md` as the local entrypoint, not the full Bright Builds Rules spec.' README.md
rg -Fq 'Bright Builds owns only its managed Markdown.' README.md
rg -Fq '## Managed Starter Checks' README.md
rg -Fq 'check-id<TAB>repo-relative-exact-path<TAB>required reason' README.md
rg -Fq 'bun scripts/bright-builds-check.ts file-lengths' standards/core/code-shape.md
rg -Fq 'bun scripts/bright-builds-check.ts lessons' standards/core/local-guidance.md
rg -Fq 'When the managed `scripts/bright-builds-check.ts` exists' standards/core/verification.md
rg -Fq 'mdformat 1.0.0' .mdformat.toml
rg -Fq 'mdformat-frontmatter 2.1.2' .mdformat.toml
rg -Fq 'mdformat-gfm 1.0.0' .mdformat.toml
rg -Fq 'mdformat-frontmatter==2.1.2' README.md
rg -Fq 'mdformat-gfm==1.0.0' README.md
rg -Fq "'mdformat==1.0.0'" scripts/verify-docs.sh
rg -Fq "'mdformat-frontmatter==2.1.2'" scripts/verify-docs.sh
rg -Fq "'mdformat-gfm==1.0.0'" scripts/verify-docs.sh
rg -Fq 'mdformat==1.0.0' .github/workflows/markdown.yml
rg -Fq 'mdformat-frontmatter==2.1.2' .github/workflows/markdown.yml
rg -Fq 'mdformat-gfm==1.0.0' .github/workflows/markdown.yml
rg -Fq 'sudo apt-get install --yes ripgrep' .github/workflows/markdown.yml
rg -Fq 'mdformat --check' .github/workflows/markdown.yml
rg -Fq 'extensions = ["gfm", "frontmatter"]' .mdformat.toml
rg -Fq 'templates/compat/**' .mdformat.toml
rg -Fq 'Do Not Add Python Scripts To Bun-Friendly JS/TS Repositories' standards/languages/typescript-javascript.md
rg -Fq 'do not add new Python scripts for repo-owned automation' standards/languages/typescript-javascript.md
rg -Fq 'Prefer SolidJS For New Web Frontends' standards/languages/typescript-javascript.md
rg -Fq 'For new TypeScript or JavaScript web frontend experiences, default to SolidJS' standards/languages/typescript-javascript.md
rg -Fq 'Prefer Stack-Aligned UI Libraries For TS/JS Frontends' standards/languages/typescript-javascript.md
rg -Fq 'Because new TypeScript and JavaScript web frontends should default to SolidJS, prefer [MysticUI](https://github.com/pRizz/mystic-ui)' standards/languages/typescript-javascript.md
rg -Fq 'pin the GitHub dependency to the latest available commit SHA at the time of adoption or update' standards/languages/typescript-javascript.md
rg -Fq 'Use the [MysticUI README](https://github.com/pRizz/mystic-ui/blob/main/README.md) as the source of truth' standards/languages/typescript-javascript.md
rg -Fq 'This repository uses Bun and TypeScript for repo-owned scripting.' AGENTS.md
rg -Fq 'Treat `.codex/tasks/lessons.md` as this repository'\''s active lesson ledger.' AGENTS.md
rg -Fq 'This append-only log is operational metadata and is not part of normal startup lesson context.' .codex/tasks/lesson-audits.md
rg -Fq '## lesson-audit-baseline-20260719 | 2026-07-19 13:19 CDT' .codex/tasks/lesson-audits.md
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

lesson_count="$(rg -c '^## lesson-[^ |]+ \|' .codex/tasks/lessons.md)"
unique_lesson_count="$(
  sed -nE 's/^## (lesson-[^ |]+) \|.*$/\1/p' .codex/tasks/lessons.md |
    sort -u |
    wc -l |
    tr -d ' '
)"

if [[ "$lesson_count" != "$unique_lesson_count" ]]; then
  echo "active lesson IDs must be unique" >&2
  exit 1
fi

awk '
  function verify_block() {
    if (in_block && (date_fields != 1 || wrong_fields != 1 || rule_fields != 1 || trigger_fields != 1)) {
      exit 1
    }
  }

  /^## lesson-[^ |]+ \|/ {
    verify_block()
    in_block = 1
    date_fields = 0
    wrong_fields = 0
    rule_fields = 0
    trigger_fields = 0
    next
  }

  in_block && /^- Date: / { date_fields += 1 }
  in_block && /^- What went wrong: / { wrong_fields += 1 }
  in_block && /^- Preventive rule: / { rule_fields += 1 }
  in_block && /^- Trigger signal: / { trigger_fields += 1 }

  END {
    verify_block()
  }
' .codex/tasks/lessons.md || {
  echo "every active lesson must contain exactly one Date, What went wrong, Preventive rule, and Trigger signal field" >&2
  exit 1
}
