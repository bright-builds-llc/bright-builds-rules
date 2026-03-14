# AGENTS.md

This repository is the canonical source for the Bright Builds coding and architecture requirements.

## Agent routing

If the task is to adopt these requirements into another repository, start with `AI-ADOPTION.md`.

Use the status-first decision rule from `AI-ADOPTION.md`:

- run `scripts/manage-downstream.sh status` first
- use `install` when `Repo state: installable`
- use `update` when `Repo state: installed`
- do not overwrite blocked managed files automatically when `Repo state: blocked`
- remember that `install` may append the managed Bright Builds block to an existing unmarked downstream `AGENTS.md`
- use `install --force` only as an explicit replacement path, which first creates `.coding-and-architecture-requirements-backups/<UTC-timestamp>/`

## Canonical sources

- AI adoption flow: `AI-ADOPTION.md`
- Downstream installer: `scripts/manage-downstream.sh`
- Standards corpus: `standards/index.md`

## Notes

- Use `scripts/manage-downstream.sh` as the canonical install, update, status, and uninstall mechanism.
- The downstream AGENTS model is a managed block inside `AGENTS.md` plus the managed `AGENTS.bright-builds.md` sidecar.
- Preserve the downstream audit trail in `coding-and-architecture-requirements.audit.md`.
- Do not invent alternate adoption steps when `AI-ADOPTION.md` already covers the use case.
