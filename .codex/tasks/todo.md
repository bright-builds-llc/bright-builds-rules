# Todo

## Current task

- [x] Extend the downstream installer with bounded default `README.md` badge management
- [x] Add conservative README badge blocking, force-repair handling, and audit/status reporting
- [x] Cover README badge install, update, force, uninstall, and detector behavior in integration tests
- [x] Update adoption docs, repo routing guidance, and the changelog for the new README badge contract

## Current verification

- [x] `bash ./scripts/test-manage-downstream.sh` passes
- [x] `./scripts/verify-docs.sh` passes
- [x] Diff reviewed for unintended side effects

## Current completion review

Completed on 2026-03-15.

Residual risks:

- Badge detection is intentionally root-only and conservative, so workspace or multi-package repos may need repo-local README badges outside the managed default block.

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
