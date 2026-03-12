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

- inspect the target repo first
- run `install` for a fresh adoption
- run `update` when `coding-and-architecture-requirements.audit.md` or a pinned `AGENTS.md` already shows an existing Bright Builds adoption
- report `coding-and-architecture-requirements.audit.md` as the downstream paper trail after completion

## Quick install

Run these from the root of the downstream repository that should adopt the standards.

Use `install` for a fresh adoption when the repo does not already contain a Bright Builds audit file or pinned `AGENTS.md`.

Install the generic downstream adoption layer:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- install --ref main
```

Use `update` when the repo already appears to be adopted from this repository and you want to refresh the managed files and audit trail.

Check or refresh an existing install:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- status
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- update --ref main
```

The manager installs `AGENTS.md`, `CONTRIBUTING.md`, `standards-overrides.md`, `.github/pull_request_template.md`, and `coding-and-architecture-requirements.audit.md`. Prefer replacing `main` with a tag or commit SHA once you start cutting releases.

## Breadcrumbs and Audit Trail

Every managed Markdown file installed by the downstream manager begins with a hidden HTML comment block marked by:

- `<!-- coding-and-architecture-requirements:begin -->`
- `<!-- coding-and-architecture-requirements:end -->`

That hidden block records the source repository URL, pinned version/ref, canonical entrypoint URL, and the path to `coding-and-architecture-requirements.audit.md`.

The visible `coding-and-architecture-requirements.audit.md` file is the main paper trail. It records:

- which repository these requirements came from
- which revision is pinned
- which managed files are currently present
- which install/update/uninstall action most recently touched the downstream repo
- when that action last ran in UTC

These breadcrumbs exist to make downstream debugging and auditing more intuitive for both humans and tools. They make it easy to answer:

- where did these requirements come from?
- which revision is this repo pinned to?
- what did the downstream manager last install, update, or intentionally leave behind?

Behavior by command:

- `install` writes the managed files, hidden breadcrumb comments, and the audit manifest
- `update` refreshes the managed files, breadcrumb comments, and audit manifest
- `status` reads from the audit manifest when present and falls back to `AGENTS.md` for older installs
- `uninstall` removes `AGENTS.md`, `CONTRIBUTING.md`, and the PR template, but intentionally keeps `standards-overrides.md` and `coding-and-architecture-requirements.audit.md` so the paper trail remains
- `uninstall --remove-overrides` removes both `standards-overrides.md` and `coding-and-architecture-requirements.audit.md`

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
- Optional Codex skill: [skills/personal-coding-standards/SKILL.md](skills/personal-coding-standards/SKILL.md)

## Adoption flow

1. Read [standards/index.md](standards/index.md) and any language-specific guidance relevant to the repository.
2. Run the downstream manager or copy the files in `templates/` into the downstream repository.
3. Pin the downstream repo to a tagged release or commit from this repository.
4. Record any repo-specific deviations in the downstream `standards-overrides.md`.
5. Optionally use the Codex skill to bootstrap adoption or review work against the standards.

The intended downstream footprint is still small: a local `AGENTS.md`, a local `CONTRIBUTING.md`, an overrides file, a PR template, and the audit trail file. The canonical standards remain here.

## Uninstall

Remove the main managed files from a downstream repository while preserving the local override history and audit trail:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- uninstall
```

Also remove `standards-overrides.md` and `coding-and-architecture-requirements.audit.md` if the downstream repository no longer needs any local trace of the installation:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- uninstall --remove-overrides
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

The script runs Markdown linting and internal link checks for the repository.

## Initial source material

The initial standards in this repository were informed by:

- Scott Wlaschin functional core / imperative shell talk: `https://www.youtube.com/watch?v=P1vES9AgfC4`
- Google Testing Blog article: `https://testing.googleblog.com/2025/10/simplify-your-code-functional-core.html`
- Parse-don't-validate article: `https://www.harudagondi.space/blog/parse-dont-validate-and-type-driven-design-in-rust`
