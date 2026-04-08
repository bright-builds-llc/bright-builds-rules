# Bright Builds Rules Audit Trail

REPLACE_WITH_MANAGED_FILE_MARKER

This file records that this repository is using the Bright Builds Rules and shows where the managed adoption files came from.

## Current installation

- Source repository: `REPLACE_WITH_REPO_URL`
- Version pin: `REPLACE_WITH_TAG_OR_COMMIT`
- Exact commit: `REPLACE_WITH_EXACT_COMMIT`
- Canonical entrypoint: `REPLACE_WITH_TAGGED_STANDARDS_INDEX_URL`
- Managed sidecar path: `REPLACE_WITH_MANAGED_SIDECAR_PATH`
- AGENTS integration mode: `append-only managed block`
- Audit manifest path: `REPLACE_WITH_AUDIT_MANIFEST_PATH`
- Auto-update: `REPLACE_WITH_AUTO_UPDATE_MODE`
- Auto-update reason: `REPLACE_WITH_AUTO_UPDATE_REASON`
- Last operation: `REPLACE_WITH_LAST_OPERATION`
- Last updated (UTC): `REPLACE_WITH_LAST_UPDATED_UTC`

## Managed files

REPLACE_WITH_MANAGED_FILES_LIST

## Why this exists

- It provides a visible paper trail for install, update, and uninstall operations.
- The installer manages a bounded block inside `AGENTS.md`, a bounded README badge block when applicable, and marked whole-file managed surfaces such as the sidecar, audit trail, contribution guide, PR template, and optional auto-update files.
- `standards-overrides.md` remains repo-local and is preserved during update and uninstall.
- It helps humans and tools debug which standards revision a repository is pinned to.
