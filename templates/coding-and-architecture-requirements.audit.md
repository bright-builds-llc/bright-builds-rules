# Coding and Architecture Requirements Audit Trail

This file records that this repository is using the Bright Builds coding and architecture requirements and shows where the managed adoption files came from.

## Current installation

- Source repository: `REPLACE_WITH_REPO_URL`
- Version pin: `REPLACE_WITH_TAG_OR_COMMIT`
- Exact commit: `REPLACE_WITH_EXACT_COMMIT`
- Canonical entrypoint: `REPLACE_WITH_TAGGED_STANDARDS_INDEX_URL`
- Managed sidecar path: `REPLACE_WITH_MANAGED_SIDECAR_PATH`
- AGENTS integration mode: `append-only managed block`
- Audit manifest path: `REPLACE_WITH_AUDIT_MANIFEST_PATH`
- Last operation: `REPLACE_WITH_LAST_OPERATION`
- Last updated (UTC): `REPLACE_WITH_LAST_UPDATED_UTC`

## Managed files

REPLACE_WITH_MANAGED_FILES_LIST

## Why this exists

- It provides a visible paper trail for install, update, and uninstall operations.
- The installer manages a bounded block inside `AGENTS.md` and the full `AGENTS.bright-builds.md` sidecar.
- `standards-overrides.md` remains repo-local and is preserved during update and uninstall.
- It helps humans and tools debug which standards revision a repository is pinned to.
