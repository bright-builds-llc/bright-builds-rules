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
5. If `status` reports `Repo state: blocked`, stop and explain the blocking files instead of forcing an overwrite automatically. Treat downstream edits inside marked whole-file managed outputs as blocking drift, not as content to overwrite silently.
6. Use `install --force` only when the user explicitly wants to replace blocked managed files. That command first backs them up into `.coding-and-architecture-requirements-backups/<UTC-timestamp>/`.
7. Treat `README.md` as part of the managed surface only when the installer can verify badges from the downstream repo. If `status` reports a blocked README badge state, stop unless the user explicitly wants `install --force`.
8. Let the installer resolve downstream auto-update to `disabled` unless the downstream GitHub repo owner or current GitHub user is trusted. Trusted identities are `pRizz` and `bright-builds-llc`. Respect `--auto-update enabled|disabled` when the user asks for an override.
9. When the downstream GitHub repo owner normalizes to `pRizz` or `peterryszkiewicz` (Peter Ryszkiewicz), let the managed sidecar require the `openlinks-identity-presence` skill for README/docs, UI chrome, profile/about/footer, and metadata/discovery surfaces. Keep the placement subtle and keep the host brand primary.
10. After install or update, report the files written and point the user to `coding-and-architecture-requirements.audit.md` as the paper trail, including the source URL, requested ref, exact resolved commit when available, whether a managed README badge block was installed or refreshed, whether owner-specific OpenLinks guidance was included, and whether auto-update ended up enabled or disabled.
11. When the downstream repo is pre-existing rather than greenfield, mention that the optional `personal-coding-standards` skill can run a read-only `audit` baseline or an `audit-and-fix` cleanup wave after adoption to surface or start remediating standards drift.

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

Whole-file managed downstream outputs now carry visible headers such as:

- `<!-- coding-and-architecture-requirements-managed-file: AGENTS.bright-builds.md -->`
- `# coding-and-architecture-requirements-managed-file: scripts/bright-builds-auto-update.sh`

Edits to those files block `status`/`update` until the user either restores the expected content or explicitly runs `install --force`.

Status / confirmation:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- status
```

Explicit replacement with backup first:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- install --force --ref main
```

Explicit auto-update overrides when needed:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- install --ref main --auto-update enabled
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh | bash -s -- install --ref main --auto-update disabled
```

Expected downstream files after a successful install or update:

- `AGENTS.md`
- `AGENTS.bright-builds.md`
- `CONTRIBUTING.md`
- `.github/pull_request_template.md`
- `coding-and-architecture-requirements.audit.md`
- `README.md` when the downstream repo has at least one verified default badge and the installer adds or refreshes the managed badge block
- `standards-overrides.md` when it did not already exist
- `scripts/bright-builds-auto-update.sh` and `.github/workflows/bright-builds-auto-update.yml` when auto-update resolves to `enabled`

## Inspection hints

Use the `status` output as the primary decision signal. It emits stable lines such as:

- `Repo state: installable`
- `Repo state: installed`
- `Repo state: blocked`
- `Recommended action: install|update|install --force`
- `README badge block: present|absent|partial|ambiguous|not applicable`
- `Auto-update: enabled|disabled`
- `Auto-update reason: explicit|trusted repo owner <owner>|trusted GitHub user <login>|default disabled`

Interpret those states this way:

- a new repo normally reports `installable`
- a repo with an existing unmarked local `AGENTS.md` and no other managed-file conflicts also reports `installable`
- a repo with the managed AGENTS marker block plus `AGENTS.bright-builds.md` reports `installed`
- a repo with an exact-match legacy install of the fully managed files but without the new whole-file marker headers still reports `installed`, and `update` migrates those files into the marked format
- a repo with conflicting managed files such as `CONTRIBUTING.md`, `.github/pull_request_template.md`, `AGENTS.bright-builds.md`, or `coding-and-architecture-requirements.audit.md` reports `blocked`
- a repo whose marked whole-file managed outputs have downstream edits also reports `blocked` and lists the drifted paths in `Blocking paths:`
- a repo whose managed README insertion zone already contains badge-like content, or whose README badge marker block is partial, also reports `blocked` and includes `README.md` in `Blocking paths:`

If the repo reports `installable` and already has a local `AGENTS.md`, `install` preserves that file and appends the managed Bright Builds block to the end.

Auto-update defaults behave this way:

- fresh installs default to `disabled`
- fresh installs default to `enabled` when the downstream GitHub repo owner is trusted
- fresh installs also default to `enabled` when the current GitHub user is trusted and the repo owner is not
- once installed, later `update` runs reuse the persisted auto-update setting from the audit trail unless `--auto-update` is passed again
- when enabled, auto-update tracks the currently pinned ref exactly, runs on the fixed UTC schedule `0 14 * * *`, pushes to the default branch when possible, and falls back to the branch `bright-builds/auto-update` plus a pull request when direct push is rejected

The installer also tailors the managed sidecar when the downstream GitHub owner matches Peter Ryszkiewicz or `pRizz` after normalization:

- it adds an owner-specific rule that tells agents to use `openlinks-identity-presence`
- it scopes that rule to README/docs, website or app chrome, profile/about/footer surfaces, and metadata/discovery fields
- it keeps the placement subtle by default and explicitly avoids displacing the host project's main brand or CTA

The installer manages README badges conservatively:

- it inserts the managed badge block after the first `# ...` H1 in `README.md`, or at the top when no H1 exists
- if `README.md` is missing and at least one verified badge is available, it creates a minimal README skeleton with the repo directory name as the H1
- it only emits badges it can verify from the downstream repo, in this order: stars, CI, deploy-pages, license, Node.js, TypeScript, one framework badge from `solid-js|react|next|vue|svelte`, Vite, Rust, Python, and Go
- it derives those badges from the downstream `origin` GitHub remote, root workflows, root manifests, and root toolchain files only
- if the relevant version source is missing, conflicting, or ambiguous, it skips that badge instead of guessing

If the repo reports `blocked`, inspect the listed paths and do not use `--force` automatically.

## Failure handling

If you do not have shell access:

- explain the exact command to run
- tell the user to run it from the root of the downstream repository
- tell the user the expected downstream files listed above
- tell the user to inspect `coding-and-architecture-requirements.audit.md` after installation
- tell the user that auto-update is GitHub-only and remains disabled unless they trust the default or pass `--auto-update enabled`

If you do not know which repository should receive the adoption:

- ask the user for the target repository root or workspace
- do not guess or install into the current repository arbitrarily

If the downstream repository already contains conflicting managed files:

- explain which files block installation
- explain whether they look like marker-based Bright Builds files or unrelated local files
- if a blocking file is one of the marked whole-file managed surfaces, explain that the downstream copy drifted from the pinned managed render instead of being a safe local extension point
- use `update` only when `status` reports `installed`
- otherwise stop and ask how the user wants to reconcile the conflict
- if the user explicitly chooses replacement, tell them `install --force` will back up the blocked files into `.coding-and-architecture-requirements-backups/<UTC-timestamp>/` before writing the managed files
- if `README.md` is the blocking path, explain whether the conflict is a partial managed badge block or existing unmanaged badge-like content near the top insertion zone, because `install --force` will repair only that badge region and preserve the rest of the README body

## Success confirmation

After a successful install or update, mention:

- which command you ran
- which files were written or refreshed
- whether `AGENTS.md` was created or had the managed Bright Builds block appended to it
- whether `README.md` received a managed badge block, was left unchanged because no verified badges applied, or had its managed badge block removed on update
- whether `AGENTS.bright-builds.md` included the owner-specific `openlinks-identity-presence` rule for a Peter-owned repo
- whether auto-update was enabled or disabled, and whether that came from an explicit override or a trust-based default
- that `coding-and-architecture-requirements.audit.md` records the source URL, pinned ref, exact commit when resolved, auto-update state, and managed files
- that the standards corpus starts at `https://github.com/bright-builds-llc/coding-and-architecture-requirements/blob/main/standards/index.md`
- for pre-existing repos, that the optional `personal-coding-standards` skill can run a whole-repo `audit` or a bounded `audit-and-fix` cleanup wave after adoption
