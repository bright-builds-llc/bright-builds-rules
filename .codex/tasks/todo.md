# Todo

## Current task

- [x] Add a TS/JS `should` rule that makes Bun the default for new standalone JS/TS projects
- [x] Scope the Bun preference to greenfield repos only and preserve existing npm/pnpm/yarn repos unless they deliberately migrate
- [x] Update the TS/JS verification note to prefer Bun for new standalone projects while preserving repo-native verification ordering
- [x] Record the new language-specific guidance in the changelog

## Current verification

- [x] `./scripts/verify-docs.sh` passes
- [x] Diff reviewed for unintended side effects

## Current completion review

Completed on 2026-03-22.

Residual risks:

- Bun compatibility still depends on the framework, workspace model, hosting platform, and dependency stack, so downstream repos may still need explicit local exceptions when Bun is not the right fit.
- The rule is intentionally greenfield-only, so repos that want a broader migration posture still need to state that locally instead of assuming the standard requires it.

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
