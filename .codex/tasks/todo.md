# Todo

## Current task

- [x] Add visible whole-file managed markers to fully managed downstream outputs without changing the bounded-marker model for `AGENTS.md` or README badges
- [x] Teach `scripts/manage-downstream.sh` to treat drifted whole-file managed outputs as `blocked`, while still accepting exact-match legacy unmarked installs and migrating them on `update`
- [x] Make `uninstall` preserve drifted whole-file managed files instead of deleting them blindly
- [x] Refresh downstream templates, README, AI adoption docs, and changelog wording for whole-file markers and drift handling
- [x] Extend downstream and auto-update integration tests for marker emission, legacy migration, drift blocking, and conservative uninstall behavior

## Current verification

- [x] `bash -n scripts/manage-downstream.sh` passes
- [x] `./scripts/verify-docs.sh` passes
- [x] `bash scripts/test-manage-downstream.sh` passes
- [x] `bash scripts/test-bright-builds-auto-update.sh` passes
- [x] Diff reviewed for unintended side effects

## Current completion review

Completed on 2026-03-22.

Residual risks:

- Drift detection for fully managed files reconstructs the expected install from persisted install metadata and pinned source templates, so manual edits to the audit metadata itself are only as detectable as the audit trail fields that can be re-rendered from that persisted state.
- Auto-update correctness now depends on the stored exact commit for reconstructing the currently installed render, so any future change to the audit manifest fields that carry provenance needs matching integration coverage.

## Previous work

- [x] Expand the `personal-coding-standards` skill for Bright Builds adopt/status/refresh flows and graceful no-argument handling
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
