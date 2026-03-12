# AI Adoption Guide

Use this guide when a user tells you to adopt the Bright Builds coding and architecture requirements into another repository and only gives you this repository URL:

- Repository URL: `https://github.com/bright-builds-llc/coding-and-architecture-requirements`
- Raw README URL: `https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/README.md`
- Raw AI adoption guide URL: `https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/AI-ADOPTION.md`
- Raw install script URL: `https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh`
- Standards index URL: `https://github.com/bright-builds-llc/coding-and-architecture-requirements/blob/main/standards/index.md`

## Default behavior

If you have shell access and a downstream repository working directory, inspect first and install automatically when it is safe.

Use this decision rule:

1. Confirm you are in the root of the repository that should adopt these requirements.
2. Inspect the repo for `coding-and-architecture-requirements.audit.md` or `AGENTS.md`.
3. If either file already exists and clearly points to `https://github.com/bright-builds-llc/coding-and-architecture-requirements`, run `update`.
4. If neither file exists, run `install`.
5. If managed files already exist but do not clearly belong to this repository, stop and explain the conflict instead of forcing an overwrite.
6. After install or update, report the files written and point the user to `coding-and-architecture-requirements.audit.md` as the paper trail.

## Commands

Use `main` as the documented default pin for now because this repository does not yet publish release tags.

Fresh adoption:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- install --ref main
```

Existing adoption from this repository:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- update --ref main
```

Status / confirmation:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- status
```

Expected downstream files after a successful install or update:

- `AGENTS.md`
- `CONTRIBUTING.md`
- `standards-overrides.md`
- `.github/pull_request_template.md`
- `coding-and-architecture-requirements.audit.md`

## Inspection hints

Before running install or update, prefer a quick inspection such as:

- confirm the target working directory is the intended downstream repo root
- check whether `coding-and-architecture-requirements.audit.md` exists
- check whether `AGENTS.md` exists and whether it references `https://github.com/bright-builds-llc/coding-and-architecture-requirements`

If the repo already has local files with the same names but no clear Bright Builds provenance, do not use `--force` automatically.

## Failure handling

If you do not have shell access:

- explain the exact command to run
- tell the user to run it from the root of the downstream repository
- tell the user the expected downstream files listed above
- tell the user to inspect `coding-and-architecture-requirements.audit.md` after installation

If you do not know which repository should receive the adoption:

- ask the user for the target repository root or workspace
- do not guess or install into the current repository arbitrarily

If the downstream repository already contains conflicting managed files:

- explain which files conflict
- explain whether they look like an existing Bright Builds adoption or unrelated local files
- use `update` only for clear Bright Builds adoptions
- otherwise stop and ask how the user wants to reconcile the conflict

## Success confirmation

After a successful install or update, mention:

- which command you ran
- which files were written or refreshed
- that `coding-and-architecture-requirements.audit.md` records the source URL, pinned ref, and managed files
- that the standards corpus starts at `https://github.com/bright-builds-llc/coding-and-architecture-requirements/blob/main/standards/index.md`
