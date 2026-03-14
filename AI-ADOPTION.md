# AI Adoption Guide

Use this guide when a user tells you to adopt the Bright Builds coding and architecture requirements into another repository and only gives you this repository URL:

- Repository URL: `https://github.com/bright-builds-llc/coding-and-architecture-requirements`
- Raw README URL: `https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/README.md`
- Raw AI adoption guide URL: `https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/AI-ADOPTION.md`
- Raw install script URL: `https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh`
- Standards index URL: `https://github.com/bright-builds-llc/coding-and-architecture-requirements/blob/main/standards/index.md`

## Default behavior

If you have shell access and a downstream repository working directory, run `status` first and then act automatically when the repo state is unambiguous.

Use this decision rule:

1. Confirm you are in the root of the repository that should adopt these requirements.
2. Run `status`.
3. If `status` reports `Repo state: installable`, run `install`.
4. If `status` reports `Repo state: installed`, run `update`.
5. If `status` reports `Repo state: blocked`, stop and explain the blocking files instead of forcing an overwrite automatically.
6. Use `install --force` only when the user explicitly wants to replace blocked managed files. That command first backs them up into `.coding-and-architecture-requirements-backups/<UTC-timestamp>/`.
7. After install or update, report the files written and point the user to `coding-and-architecture-requirements.audit.md` as the paper trail, including the source URL, requested ref, and exact resolved commit when available.

## Commands

Use `main` as the documented default pin for now because this repository does not yet publish release tags.

Inspect repo state first:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- status
```

Fresh adoption:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- install --ref main
```

Marker-based adoption already installed:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- update --ref main
```

Status / confirmation:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- status
```

Explicit replacement with backup first:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- install --force --ref main
```

Expected downstream files after a successful install or update:

- `AGENTS.md`
- `AGENTS.bright-builds.md`
- `CONTRIBUTING.md`
- `.github/pull_request_template.md`
- `coding-and-architecture-requirements.audit.md`
- `standards-overrides.md` when it did not already exist

## Inspection hints

Use the `status` output as the primary decision signal. It emits stable lines such as:

- `Repo state: installable`
- `Repo state: installed`
- `Repo state: blocked`
- `Recommended action: install|update|install --force`

Interpret those states this way:

- a new repo normally reports `installable`
- a repo with an existing unmarked local `AGENTS.md` and no other managed-file conflicts also reports `installable`
- a repo with the managed AGENTS marker block plus `AGENTS.bright-builds.md` reports `installed`
- a repo with conflicting managed files such as `CONTRIBUTING.md`, `.github/pull_request_template.md`, `AGENTS.bright-builds.md`, or `coding-and-architecture-requirements.audit.md` reports `blocked`

If the repo reports `installable` and already has a local `AGENTS.md`, `install` preserves that file and appends the managed Bright Builds block to the end.

If the repo reports `blocked`, inspect the listed paths and do not use `--force` automatically.

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

- explain which files block installation
- explain whether they look like marker-based Bright Builds files or unrelated local files
- use `update` only when `status` reports `installed`
- otherwise stop and ask how the user wants to reconcile the conflict
- if the user explicitly chooses replacement, tell them `install --force` will back up the blocked files into `.coding-and-architecture-requirements-backups/<UTC-timestamp>/` before writing the managed files

## Success confirmation

After a successful install or update, mention:

- which command you ran
- which files were written or refreshed
- whether `AGENTS.md` was created or had the managed Bright Builds block appended to it
- that `coding-and-architecture-requirements.audit.md` records the source URL, pinned ref, exact commit when resolved, and managed files
- that the standards corpus starts at `https://github.com/bright-builds-llc/coding-and-architecture-requirements/blob/main/standards/index.md`
