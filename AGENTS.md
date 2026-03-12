# AGENTS.md

This repository is the canonical source for the Bright Builds coding and architecture requirements.

## Agent routing

If the task is to adopt these requirements into another repository, start with `AI-ADOPTION.md`.

Use the status-first decision rule from `AI-ADOPTION.md`:

- run `scripts/manage-downstream.sh status` first
- use `install` only for `Repo state: fresh`
- use `update` only for `Repo state: managed`
- do not overwrite unclear local files automatically when `Repo state: conflict`
- use `install --force` only as an explicit legacy replacement path, which first creates `.coding-and-architecture-requirements-backups/<UTC-timestamp>/`

## Canonical sources

- AI adoption flow: `AI-ADOPTION.md`
- Downstream installer: `scripts/manage-downstream.sh`
- Standards corpus: `standards/index.md`

## Notes

- Use `scripts/manage-downstream.sh` as the canonical install, update, status, and uninstall mechanism.
- Preserve the downstream audit trail in `coding-and-architecture-requirements.audit.md`.
- Do not invent alternate adoption steps when `AI-ADOPTION.md` already covers the use case.
