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
- remember that install/update may also manage a bounded README badge block when the downstream repo has verified badge inputs
- remember that install/update may also tailor `AGENTS.bright-builds.md` with an `openlinks-identity-presence` rule when the downstream GitHub repo owner normalizes to `pRizz` or `peterryszkiewicz` (Peter Ryszkiewicz)
- use `install --force` only as an explicit replacement path, which first creates `.coding-and-architecture-requirements-backups/<UTC-timestamp>/`

## Canonical sources

- AI adoption flow: `AI-ADOPTION.md`
- Downstream installer: `scripts/manage-downstream.sh`
- Standards corpus: `standards/index.md`

## Notes

- Use `scripts/manage-downstream.sh` as the canonical install, update, status, and uninstall mechanism.
- The downstream AGENTS model is a managed block inside `AGENTS.md` plus the managed `AGENTS.bright-builds.md` sidecar.
- The downstream README badge model is a separate bounded block in `README.md`, inserted after the first H1 when verified badges are available and blocked conservatively when the top badge zone is ambiguous.
- Preserve the downstream audit trail in `coding-and-architecture-requirements.audit.md`.
- Do not invent alternate adoption steps when `AI-ADOPTION.md` already covers the use case.
