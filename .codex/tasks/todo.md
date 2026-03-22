# Todo

## Current task

- [x] Add a core `Verification` standard with durable pre-commit guidance, affected-path scope, CI-only heavy-suite exceptions, and hook-aware prompting
- [x] Propagate the verification standard through the standards index, README entrypoints, language notes, and Codex skill references
- [x] Refresh downstream managed templates so installed repos receive the new verification guidance and override notes
- [x] Extend installer regression coverage to assert the new verification wording in managed outputs

## Current verification

- [x] `./scripts/verify-docs.sh` passes
- [x] `bash ./scripts/test-manage-downstream.sh` passes
- [x] `bash ./scripts/test-bright-builds-auto-update.sh` passes
- [x] Diff reviewed for unintended side effects

## Current completion review

Completed on 2026-03-22.

Residual risks:

- Hook detection remains heuristic by design, so downstream repos still need local guidance or overrides when hook-owned verification is partial, stale, or intentionally advisory.
- The core rule allows heavy suites to remain CI-only when documented locally, so downstream repos still need to define that boundary clearly if they want agents to avoid guessing.

## Previous work

- [x] Harden downstream adoption for both new repos and legacy codebases
- [x] Add repo-state classification and provenance-gated updates to the downstream manager
- [x] Add force-install backups for conflicting legacy files
- [x] Align README, AI adoption guide, and repo routing docs with a status-first adoption flow
- [x] Reset downstream adoption to the sidecar-based `AGENTS.bright-builds.md` model
- [x] Rework `scripts/manage-downstream.sh` around marker-block `AGENTS.md` installs and the `installable|installed|blocked` contract
- [x] Add integration coverage for install, update, uninstall, and force-install behavior under the new contract
- [x] Refresh downstream docs and templates to match the breaking installer reset

## Verification

- [x] `bash -n scripts/manage-downstream.sh` passes
- [x] `./scripts/verify-docs.sh` passes
- [x] Shell integration tests cover fresh install, append-to-existing-AGENTS install, blocked conflicts, update, uninstall, and `install --force`
- [x] Fresh repo status reports `installable` and recommends `install`
- [x] Repo with existing unmarked `AGENTS.md` reports `installable` and `install` appends exactly one managed block
- [x] Old standalone installs report `blocked` instead of `installed`
- [x] `install --force` backs up conflicting files before replacing them
- [x] Existing `standards-overrides.md` content is preserved during install/update and preserved on uninstall
- [x] Diff reviewed for unintended side effects

## Completion review

Completed on 2026-03-13.

Residual risks:

- The installer intentionally no longer recognizes the previous standalone downstream layout, so any repo that adopted an earlier contract now requires an explicit `install --force` replacement.
- A repo with a local `AGENTS.md` receives the managed block at the end, so agents still rely on the documented rule that repo-local instructions outside the managed block take precedence on conflicts.
