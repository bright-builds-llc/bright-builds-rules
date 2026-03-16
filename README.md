# Personal Coding and Architecture Requirements

[![GitHub Stars](https://img.shields.io/github/stars/bright-builds-llc/coding-and-architecture-requirements)](https://github.com/bright-builds-llc/coding-and-architecture-requirements)

This repository is a versioned policy and adoption kit for a personal, opinionated coding style. It is designed to work for both humans and AI agents:

- Humans can read a small set of canonical standards documents.
- Teams can copy thin local templates into their own repositories.
- Codex users can opt into a thin skill that points back to the canonical docs.

## For AI Agents

If an AI is given only this repository URL and asked to adopt these requirements into another repository, the AI should start with [AI-ADOPTION.md](AI-ADOPTION.md).

Direct fetch targets for AI tooling:

- Repository URL: `https://github.com/bright-builds-llc/coding-and-architecture-requirements`
- Raw README URL: `https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/README.md`
- Raw AI adoption guide URL: `https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/AI-ADOPTION.md`
- Raw install script URL: `https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh`
- Standards index URL: `https://github.com/bright-builds-llc/coding-and-architecture-requirements/blob/main/standards/index.md`

Suggested user phrase for an AI:

`Adopt the requirements from https://github.com/bright-builds-llc/coding-and-architecture-requirements into this repo.`

The intended AI behavior is:

- run `status` first
- run `install` when `status` reports `Repo state: installable`
- run `update` when `status` reports `Repo state: installed`
- stop for review when `status` reports `Repo state: blocked`, unless the user explicitly wants `install --force`
- preserve a pre-existing unmarked `AGENTS.md` by appending the managed Bright Builds block to the end during `install`
- manage a bounded `README.md` badge block when the downstream repo has verified badge inputs and the top badge zone is unambiguous
- let the installer resolve downstream auto-update to `disabled` by default unless the downstream GitHub repo owner or current GitHub user is trusted
- use `install --force` only as an opt-in replacement path for blocked managed files, which first backs them up into `.coding-and-architecture-requirements-backups/<UTC-timestamp>/`
- report `coding-and-architecture-requirements.audit.md` as the downstream paper trail after completion
- report the pinned source URL, requested ref, and exact resolved commit when available

## Quick install

Run these from the root of the downstream repository that should adopt the standards.

Start with `status` for both new repos and existing codebases:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- status
```

The status output classifies the repo with stable lines:

- `Repo state: installable`
- `Repo state: installed`
- `Repo state: blocked`
- `Recommended action: install|update|install --force`
- `README badge block: present|absent|partial|ambiguous|not applicable`
- `Auto-update: enabled|disabled`
- `Auto-update reason: explicit|trusted repo owner <owner>|trusted GitHub user <login>|default disabled`

If `Repo state: installable`, install the downstream adoption layer:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- install --ref main
```

If the repository already has an unmarked local `AGENTS.md`, `install` keeps that file and appends the managed Bright Builds block to the end. The same command also writes `AGENTS.bright-builds.md`, `CONTRIBUTING.md`, `.github/pull_request_template.md`, `coding-and-architecture-requirements.audit.md`, creates `standards-overrides.md` when the overrides file does not already exist, and manages a bounded `README.md` badge block when it can verify at least one default badge.

Fresh installs resolve auto-update to `disabled` unless the downstream GitHub repo owner or the current GitHub user is trusted. Trusted identities are `pRizz` and `bright-builds-llc`, compared case-insensitively. Override the default with `--auto-update enabled` or `--auto-update disabled` when needed.

If `Repo state: installed`, refresh the existing marker-based Bright Builds adoption:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- update --ref main
```

If `Repo state: blocked`, stop and review the blocking managed files before replacing them. If you intentionally want to replace those files, use `install --force`, which first backs them up into `.coding-and-architecture-requirements-backups/<UTC-timestamp>/`:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- install --force --ref main
```

New repo vs existing repo:

- A new repo normally reports `installable`.
- A repo with an existing local `AGENTS.md` and no other managed-file conflicts also reports `installable`.
- A repo with existing managed conflicts such as `CONTRIBUTING.md`, `.github/pull_request_template.md`, `AGENTS.bright-builds.md`, or `coding-and-architecture-requirements.audit.md` reports `blocked`.
- A repo whose README insertion zone already contains unmanaged badge-like content, or whose managed README badge block is partial, also reports `blocked`.
- A repo with the managed AGENTS marker block plus `AGENTS.bright-builds.md` reports `installed`.
- A repo using the previous standalone downstream layout from this repository reports `blocked` until you explicitly replace it.

The manager installs a managed block inside `AGENTS.md`, writes `AGENTS.bright-builds.md`, writes `CONTRIBUTING.md`, writes `.github/pull_request_template.md`, writes `coding-and-architecture-requirements.audit.md`, creates `standards-overrides.md` if it is missing, and inserts or refreshes a managed README badge block when verified badges are available. It keeps the requested `Version pin` breadcrumb and also records the exact resolved commit when that provenance can be determined. Prefer replacing `main` with a tag or commit SHA once you start cutting releases.

When auto-update resolves to `enabled`, the manager also writes:

- `scripts/bright-builds-auto-update.sh`
- `.github/workflows/bright-builds-auto-update.yml`

Check or refresh an existing install at any time:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- status
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- update --ref main
```

Updates reuse the persisted auto-update setting from `coding-and-architecture-requirements.audit.md` unless you explicitly override it with `--auto-update`.

## Default Auto-Update

When auto-update is enabled, the downstream repo gets a managed GitHub Actions workflow plus a managed helper script:

- the workflow runs daily on the fixed UTC schedule `0 14 * * *` and also exposes `workflow_dispatch`
- it tries to commit managed-file changes directly to the default branch first
- if that direct push is rejected, it falls back to the fixed branch `bright-builds/auto-update` and opens or reuses a pull request
- it never uses `install --force`; if `status` stops reporting `Repo state: installed`, the helper script exits without mutating the repo
- it tracks the currently installed ref exactly, so `main` keeps moving while immutable tags and full SHAs effectively stay frozen

This mechanism is intended for GitHub-hosted repos. Repos on other hosts can still use the normal manual `status`, `install`, and `update` flow.

## Default README Badges

When the downstream repository has verifiable inputs, the installer manages a bounded badge block in `README.md`:

- it inserts the block after the first `# ...` H1, or at the top when no H1 exists
- if `README.md` is missing and at least one verified badge is available, it creates a minimal README skeleton using the repo directory name as the H1
- it blocks conservatively when the top insertion zone already contains unmanaged badge-like content or a partial managed badge block
- `install --force` backs up `README.md`, repairs only that badge region, and preserves the rest of the README body

Supported default detectors are intentionally conservative and root-only:

- GitHub stars, CI, deploy-pages, and license from the downstream `origin` GitHub remote plus root workflow and license files
- Node.js from `package.json.engines.node`, else `.nvmrc`, else `actions/setup-node` in the root CI workflow
- TypeScript, Vite, and one framework badge from `solid-js|react|next|vue|svelte` from root `package.json` dependencies or devDependencies
- Rust from `rust-toolchain.toml`, else `Cargo.toml`
- Python from `pyproject.toml`, else `.python-version`
- Go from `go.mod`

If the relevant version source is missing, conflicting, or ambiguous, the installer skips that badge instead of guessing.

## AGENTS Marker And Audit Trail

The downstream install is anchored by two AGENTS files:

- `AGENTS.md` contains a bounded managed Bright Builds block marked by:
  - `<!-- coding-and-architecture-requirements-managed:begin -->`
  - `<!-- coding-and-architecture-requirements-managed:end -->`
- `AGENTS.bright-builds.md` contains the managed Bright Builds guidance and a visible warning that the file is installed from this repository and should not be edited directly.

The visible `coding-and-architecture-requirements.audit.md` file is the paper trail. It records:

- which repository these requirements came from
- which revision is pinned
- which exact commit was installed when it could be resolved
- whether downstream auto-update is currently enabled or disabled, and why
- which managed files are currently tracked
- whether the managed README badge block is currently part of that tracked footprint
- which install/update/uninstall action most recently touched the downstream repo
- when that action last ran in UTC

These files exist to make downstream debugging and auditing more intuitive for both humans and tools. They make it easy to answer:

- where did these requirements come from?
- which revision is this repo pinned to?
- which exact commit was actually installed?
- is auto-update enabled here, and why?
- is the README badge block managed by the installer right now?
- what did the downstream manager last install or update?

Behavior by command:

- `install` writes or refreshes the managed AGENTS block, writes `AGENTS.bright-builds.md`, refreshes the managed files, writes or repairs the managed README badge block when verified badges are available, writes the audit manifest, and creates `standards-overrides.md` if it is missing
- `install` also writes the managed auto-update workflow and helper script when auto-update resolves to `enabled`
- rerunning `install` on an already installed repo refreshes the managed block and does not duplicate it
- `install --force` first backs up blocked managed files into `.coding-and-architecture-requirements-backups/<UTC-timestamp>/` before replacing them, and repairs only the top README badge region when `README.md` is blocked
- `update` refreshes the managed AGENTS block, sidecar, managed files, managed README badge block, audit manifest, and any enabled auto-update files, but only for the new marker-based installs
- `status` uses the managed AGENTS marker block plus `AGENTS.bright-builds.md` as the install signal
- `status` also reports explicit README badge state plus the resolved auto-update mode and reason
- installed `status` also reports the pinned exact commit from the audit trail when present
- `uninstall` removes the managed AGENTS block, managed README badge block, `AGENTS.bright-builds.md`, `CONTRIBUTING.md`, the PR template, the managed auto-update files, and the audit manifest, while preserving `standards-overrides.md`

## Repository layout

```text
.
├── AGENTS.md
├── AI-ADOPTION.md
├── CHANGELOG.md
├── scripts/
├── skills/
│   └── personal-coding-standards/
├── standards/
│   ├── core/
│   └── languages/
└── templates/
```

## Canonical entrypoints

- AI adoption guide: [AI-ADOPTION.md](AI-ADOPTION.md)
- Standards index: [standards/index.md](standards/index.md)
- Core architecture: [standards/core/architecture.md](standards/core/architecture.md)
- Code shape: [standards/core/code-shape.md](standards/core/code-shape.md)
- Testing: [standards/core/testing.md](standards/core/testing.md)
- Rust guidance: [standards/languages/rust.md](standards/languages/rust.md)
- TypeScript/JavaScript guidance: [standards/languages/typescript-javascript.md](standards/languages/typescript-javascript.md)
- Downstream adoption templates: [templates/AGENTS.md](templates/AGENTS.md)
- Downstream sidecar template: [templates/AGENTS.bright-builds.md](templates/AGENTS.bright-builds.md)
- Optional Codex skill: [skills/personal-coding-standards/SKILL.md](skills/personal-coding-standards/SKILL.md)

## Adoption flow

1. Read [standards/index.md](standards/index.md) and any language-specific guidance relevant to the repository.
2. Run the downstream manager or copy the files in `templates/` into the downstream repository.
3. Pin the downstream repo to a tagged release or commit from this repository.
4. Record any repo-specific deviations in the downstream `standards-overrides.md`.
5. Optionally use the Codex skill to bootstrap adoption or review work against the standards.

The intended downstream footprint is still small: a local `AGENTS.md` with a managed Bright Builds block, a local `AGENTS.bright-builds.md` sidecar, a local `CONTRIBUTING.md`, an optional managed README badge block, an overrides file, a PR template, and the audit trail file. The canonical standards remain here.

## Uninstall

Remove the managed AGENTS block and the managed Bright Builds files from a downstream repository while preserving the local override history:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- uninstall
```

## Versioning and releases

Treat this repository like a policy product:

- Tag releases so downstream repositories can pin to a stable revision.
- Add new guidance incrementally instead of rewriting the full corpus at once.
- Record noteworthy policy changes in [CHANGELOG.md](CHANGELOG.md).
- Prefer explicit exceptions over silent drift in downstream repos.

Suggested convention:

- Major: rule meaning changes in a way that would force downstream repos to revisit adoption.
- Minor: new guidance, new examples, or new optional language-specific standards.
- Patch: wording fixes, broken links, and template clarifications.

## Verification

Run the docs hygiene checks with:

```bash
./scripts/verify-docs.sh
```

Run the downstream manager integration checks with:

```bash
bash ./scripts/test-manage-downstream.sh
bash ./scripts/test-bright-builds-auto-update.sh
```

The scripts run Markdown linting, internal link checks, and installer integration coverage for the repository.

## Initial source material

The initial standards in this repository were informed by:

- Scott Wlaschin functional core / imperative shell talk: `https://www.youtube.com/watch?v=P1vES9AgfC4`
- Google Testing Blog article: `https://testing.googleblog.com/2025/10/simplify-your-code-functional-core.html`
- Parse-don't-validate article: `https://www.harudagondi.space/blog/parse-dont-validate-and-type-driven-design-in-rust`
