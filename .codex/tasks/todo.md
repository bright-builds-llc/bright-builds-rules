# Todo

## Active work

- [x] Harden downstream adoption for both new repos and legacy codebases
- [x] Add repo-state classification and provenance-gated updates to the downstream manager
- [x] Add force-install backups for conflicting legacy files
- [x] Align README, AI adoption guide, and repo routing docs with a status-first adoption flow

## Verification

- [x] `bash -n scripts/manage-downstream.sh` passes
- [x] `./scripts/verify-docs.sh` passes
- [x] Fresh repo status reports `fresh` and recommends `install`
- [x] Existing Bright Builds adoption reports `managed` and `update` works
- [x] Legacy conflicts report `conflict`, block `install`, and block `update`
- [x] `install --force` backs up conflicting files before replacing them
- [x] Existing `standards-overrides.md` content is preserved during install
- [x] Diff reviewed for unintended side effects

## Completion review

Completed on 2026-03-12.

Residual risks:

- The documented default pin remains `main` until the repository starts publishing tags, so automated adopters still need a later release flow for immutable pins.
- `install --force` is intentionally destructive after creating a backup, so AIs still need explicit user intent before choosing that path in a legacy repo.
