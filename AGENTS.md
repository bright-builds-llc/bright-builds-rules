# AGENTS.md

This repository is the canonical source for the Bright Builds Rules.

## Agent routing

If the task is to adopt Bright Builds Rules into another repository, start with `AI-ADOPTION.md`.

Use the status-first decision rule from `AI-ADOPTION.md`:

- run `scripts/manage-downstream.sh status` first
- use `install` when `Repo state: installable`
- use `update` when `Repo state: installed`
- do not overwrite blocked managed files automatically when `Repo state: blocked`
- if the user explicitly opts into replacing blocked managed files, treat `install --force` as a backup-first merge-assisted path: review the timestamped backup against the fresh managed outputs and fold back only clearly portable downstream-specific logic or content into safe local extension points
- if that merge review would require re-drifting a fully managed file or making a non-obvious semantic choice, stop and ask the user
- remember that `install` may append the managed Bright Builds Rules block to an existing unmarked downstream `AGENTS.md`
- remember that install/update may also manage a bounded README badge block when the downstream repo has verified default badge inputs or when a Peter-owned repo gets the owner-specific OpenLinks badge
- remember that install/update may also tailor `AGENTS.bright-builds.md` with an `openlinks-identity-presence` rule when the downstream GitHub repo owner normalizes to `pRizz` or `peterryszkiewicz` (Peter Ryszkiewicz)
- use `install --force` only as an explicit replacement path, which first creates `.bright-builds-rules-backups/<UTC-timestamp>/`; for blocked `README.md`, keep the managed badge block after the first H1 and only restore prior top-of-file badges or content below it when that does not recreate ambiguity

## Canonical sources

- AI adoption flow: `AI-ADOPTION.md`
- Downstream installer: `scripts/manage-downstream.sh`
- Standards corpus: `standards/index.md`

## Repo-Local Guidance

- Use `scripts/manage-downstream.sh` as the canonical install, update, status, and uninstall mechanism.
- Keep reusable cross-repo rules in `standards/`, keep downstream managed wording in `templates/`, and keep recurring workflow facts for this repository in this section.
- The downstream AGENTS model is a managed block inside `AGENTS.md` plus the managed `AGENTS.bright-builds.md` sidecar.
- This repository uses Bun and TypeScript for repo-owned scripting. Do not add Python scripts here unless a rare compatibility exception is explicitly documented.
- Keep downstream Markdown default-`mdformat`-clean. `./scripts/verify-docs.sh` and `bash scripts/test-manage-downstream.sh` expect `mdformat` on `PATH` and treat formatting drift in managed downstream Markdown as an installer/template regression.
- When updating this repository's `.codex/tasks/todo.md` or `.codex/tasks/lessons.md`, use append-only blocks with stable IDs and timestamps, append new work at the end, and keep edits localized to the matching block instead of rewriting shared current-status sections.
- Fully managed downstream files such as `AGENTS.bright-builds.md`, `CONTRIBUTING.md`, the PR template, the audit trail, and enabled auto-update files use visible whole-file managed markers and should block status/update when they drift downstream.
- When a refactor or rename touches downstream-managed contract surfaces such as managed filenames, marker names, audit paths, README badge markers, source URLs, or install/update/auto-update behavior, preserve backward compatibility for already-installed downstream repos by default; before finalizing the change, audit the old contract across `scripts/manage-downstream.sh`, the managed auto-update helper template, downstream-facing docs, and regression tests, update any affected migration or auto-update paths together, add or refresh regression coverage for both direct `update` and scheduled auto-update when applicable, and if a compatibility break is intentional, document the migration path and user-facing impact explicitly instead of shipping it silently.
- The downstream README badge model is a separate bounded block in `README.md`, inserted after the first H1 when managed README badges apply, including the owner-specific `OpenLinks profile` badge for Peter-owned repos, and blocked conservatively when the top badge zone is ambiguous.
- Preserve the downstream audit trail in `bright-builds-rules.audit.md`.
- Do not invent alternate adoption steps when `AI-ADOPTION.md` already covers the use case.
