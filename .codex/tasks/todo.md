# Todo

## Current task

- [x] Add a Rust `must` rule that prefers `foo.rs` plus `foo/` over `foo/mod.rs` for new or touched multi-file modules
- [x] Scope the rule to new modules and touched refactors without forcing repo-wide migration of untouched `mod.rs` trees
- [x] Document narrow exceptions for generated code, tooling constraints, and explicitly documented local conventions
- [x] Record the new Rust guidance in the changelog

## Current verification

- [x] `./scripts/verify-docs.sh` passes
- [x] Diff reviewed for unintended side effects

## Current completion review

Completed on 2026-03-22.

Residual risks:

- Existing Rust codebases may still contain many stable `mod.rs` trees, so reviewers need to apply the non-retroactive migration posture consistently instead of demanding unrelated renames.
- Some code generators or framework conventions may still require `mod.rs`, so local exceptions need to stay explicit rather than becoming an assumed loophole.

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
