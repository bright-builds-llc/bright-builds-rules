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

## task-mnemonic-threshold-provenance | 2026-03-26 18:58 CDT | Refresh threshold provenance hints

- [x] Audit authored numeric rules and limit this pass to the line-count thresholds.
- [x] Change the function refactor trigger from `200` to `161` and document `floor(100 * phi)` as the mnemonic, not a hard cap.
- [x] Keep the file refactor trigger at `628` and document `floor(100 * tau)` as the mnemonic, not a hard cap.
- [x] Mirror the threshold wording in the managed `AGENTS.bright-builds.md` template and update the oversized-function example so it still exceeds the threshold.
- [x] Verify the docs and confirm the managed rule surfaces carry the new `161` and `628` wording without stale `200` references.
- Verification: `./scripts/verify-docs.sh`
- Verification: `rg -n --no-heading '200 lines|161 lines|628 lines|floor\\(100 \\* phi\\)|floor\\(100 \\* tau\\)' standards/core/code-shape.md templates/AGENTS.bright-builds.md README.md AGENTS.md AI-ADOPTION.md`
- Completion review: The provenance hints stay inline with the threshold sentences, so the rules remain scannable and do not introduce a separate glossary or appendix.
- Residual risk: Downstream repositories will not pick up the revised threshold wording until they next run Bright Builds install or update.

## task-harden-downstream-prompt-compliance | 2026-03-30 04:18 CDT | Harden downstream prompt compliance

- [x] Replace the soft downstream `AGENTS.md` wording with a required reading order and explicit stop-before-continuing language.
- [x] Add a compact required-workflow section to `templates/AGENTS.bright-builds.md` that states `AGENTS.md` is the entrypoint rather than the full spec.
- [x] Require brief source acknowledgment for plan, review, and audit outputs in the managed sidecar and reinforcing downstream surfaces.
- [x] Mirror the layered contract in `AI-ADOPTION.md`, `README.md`, and `skills/personal-coding-standards/SKILL.md`.
- [x] Add regression checks for the new contract in `scripts/verify-docs.sh` and `scripts/test-manage-downstream.sh`.
- Verification: `bash -n scripts/manage-downstream.sh`
- Verification: `./scripts/verify-docs.sh`
- Verification: `bash scripts/test-manage-downstream.sh`
- Verification: `bash scripts/test-bright-builds-auto-update.sh`
- Completion review: The install, update, and status flows stay unchanged; this pass only hardens the downstream reading-order contract, the reinforcing docs, and the regression checks around that wording.
- Residual risk: The new contract still cannot prove that a downstream agent truly loaded every required source at runtime; it only makes the required sequence explicit and harder to regress accidentally.
