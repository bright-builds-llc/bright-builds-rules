# AI Adoption Guide

Use this guide when a user tells you to adopt the Bright Builds Rules into another repository and only gives you this repository URL:

- Repository URL: `https://github.com/bright-builds-llc/bright-builds-rules`
- Raw README URL: `https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/README.md`
- Raw AI adoption guide URL: `https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/AI-ADOPTION.md`
- Raw install script URL: `https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/scripts/manage-downstream.sh`
- Standards index URL: `https://github.com/bright-builds-llc/bright-builds-rules/blob/main/standards/index.md`

## Default behavior

If you have shell access and a downstream repository working directory, run `status` first and then act automatically when the repo state is unambiguous.

Use this decision rule:

1. Confirm you are in the root of the repository that should adopt Bright Builds Rules.
2. Run `status`.
3. If `status` reports `Repo state: installable`, run `install`.
4. If `status` reports `Repo state: installed`, run `update`.
5. If `status` reports `Repo state: blocked`, stop and explain the blocking files instead of forcing an overwrite automatically. Treat downstream edits inside marked whole-file managed outputs as blocking drift, not as content to overwrite silently.
6. Use `install --force` only when the user explicitly wants to replace blocked managed files. Frame that choice as a backup-first, merge-assisted path rather than a blind overwrite; the command first writes `.bright-builds-rules-backups/<UTC-timestamp>/`.
7. After `install --force`, inspect the timestamped backup, diff each backed-up file against the fresh managed output, and reapply only clearly portable downstream-specific logic or content into safe local extension points such as repo-local `AGENTS.md` content outside the managed block, `standards-overrides.md`, existing non-managed project docs, and `README.md` content outside the managed badge block.
8. If preserving prior behavior would require re-drifting a fully managed file, inventing a new contract, or making a non-obvious semantic choice, stop and ask the user instead of guessing.
9. Treat `README.md` as part of the managed surface when the installer can verify default badges from the downstream repo or when a Peter-owned GitHub repo qualifies for the owner-specific OpenLinks badge. If `status` reports a blocked README badge state, stop unless the user explicitly wants `install --force`; after repair, keep the managed badge block immediately after the first H1 and only reinsert prior top-of-file badges or content below it when that does not recreate badge ambiguity.
10. Let the installer resolve downstream auto-update to `disabled` unless the downstream GitHub repo owner or current GitHub user is trusted. Trusted identities are `pRizz` and `bright-builds-llc`. Respect `--auto-update enabled|disabled` when the user asks for an override.
11. When the downstream GitHub repo owner normalizes to `pRizz` or `peterryszkiewicz` (Peter Ryszkiewicz), let the managed sidecar require the `openlinks-identity-presence` skill for README/docs, UI chrome, profile/about/footer, and metadata/discovery surfaces, and let the managed README badge block append a subtle `OpenLinks profile` badge linked to `https://openlinks.us/` after any project badges. Keep the placement subtle and keep the host brand primary.
12. After install or update, report the files written and point the user to `bright-builds-rules.audit.md` as the paper trail, including the source URL, requested ref, exact resolved commit when available, whether a managed README badge block was installed or refreshed, whether owner-specific OpenLinks guidance was included, whether the owner-specific OpenLinks README badge applied, and whether auto-update ended up enabled or disabled.
13. After install or update, treat downstream `AGENTS.md` as the local entrypoint, not the full Bright Builds Rules spec. Before plan, review, implementation, or audit work, load `AGENTS.md`, `AGENTS.bright-builds.md`, `standards-overrides.md` when present, and the pinned canonical standards pages relevant to the task; if that has not happened yet, stop and do it first.
14. For plan, review, and audit work in the downstream repo, briefly acknowledge which of those sources materially informed the answer.
15. When the downstream repo is pre-existing rather than greenfield, mention that the optional `bright-builds-rules` skill can run a read-only `audit` baseline or an `audit-and-fix` cleanup wave after adoption to surface or start remediating standards drift.

## Commands

Use `main` as the documented default pin for now because this repository does not yet publish release tags.

Inspect repo state first:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/scripts/manage-downstream.sh | bash -s -- status
```

Fresh adoption:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/scripts/manage-downstream.sh | bash -s -- install --ref main
```

Marker-based adoption already installed:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/scripts/manage-downstream.sh | bash -s -- update --ref main
```

Whole-file managed downstream outputs now carry visible headers such as:

- `<!-- bright-builds-rules-managed-file: AGENTS.bright-builds.md -->`
- `# bright-builds-rules-managed-file: scripts/bright-builds-auto-update.sh`

Edits to those files block `status`/`update` until the user either restores the expected content or explicitly runs `install --force` and then performs the merge review described below.

Status / confirmation:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/scripts/manage-downstream.sh | bash -s -- status
```

Explicit replacement with backup first, followed by the agent's merge review:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/scripts/manage-downstream.sh | bash -s -- install --force --ref main
```

Explicit auto-update overrides when needed:

```bash
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/scripts/manage-downstream.sh | bash -s -- install --ref main --auto-update enabled
curl -fsSL https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/scripts/manage-downstream.sh | bash -s -- install --ref main --auto-update disabled
```

Expected downstream files after a successful install or update:

- `AGENTS.md`
- `AGENTS.bright-builds.md`
- `CONTRIBUTING.md`
- `.github/pull_request_template.md`
- `bright-builds-rules.audit.md`
- `README.md` when the downstream repo has at least one verified default badge or the owner-specific OpenLinks badge applies and the installer adds or refreshes the managed badge block
- `standards-overrides.md` when it did not already exist
- `scripts/bright-builds-auto-update.sh` and `.github/workflows/bright-builds-auto-update.yml` when auto-update resolves to `enabled`

After install or update, the downstream instruction contract is layered:

1. `AGENTS.md` is the local entrypoint, not the full Bright Builds Rules spec.
2. `AGENTS.bright-builds.md` carries the managed Bright Builds Rules workflow and high-signal rules.
3. `standards-overrides.md` records deliberate repo-specific exceptions when it exists.
4. The pinned canonical standards pages remain the source of truth for task-relevant rules.

Before plan, review, implementation, or audit work, load those sources in that order. If that has not happened yet, stop and do it first. For plan, review, and audit outputs, briefly acknowledge which of those sources materially informed the answer.

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
- a repo with conflicting managed files such as `CONTRIBUTING.md`, `.github/pull_request_template.md`, `AGENTS.bright-builds.md`, or `bright-builds-rules.audit.md` reports `blocked`
- a repo whose marked whole-file managed outputs have downstream edits also reports `blocked` and lists the drifted paths in `Blocking paths:`
- a repo whose managed README insertion zone already contains badge-like content, or whose README badge marker block is partial, also reports `blocked` and includes `README.md` in `Blocking paths:`

If the repo reports `installable` and already has a local `AGENTS.md`, `install` preserves that file and appends the managed Bright Builds Rules block to the end.

Auto-update defaults behave this way:

- fresh installs default to `disabled`
- fresh installs default to `enabled` when the downstream GitHub repo owner is trusted
- fresh installs also default to `enabled` when the current GitHub user is trusted and the repo owner is not
- once installed, later `update` runs reuse the persisted auto-update setting from the audit trail unless `--auto-update` is passed again
- when enabled, auto-update tracks the currently pinned ref exactly, runs on the fixed UTC schedule `0 14 * * *`, pushes to the default branch when possible, and falls back to the branch `bright-builds/auto-update` plus a pull request when direct push is rejected
- when enabled, that same `update` path also repairs the exact legacy Bright Builds README badge snippets this repo previously documented, so already-installed downstream repos can self-heal old `coding-and-architecture-requirements` badge markdown without a separate job

The installer also tailors the managed sidecar when the downstream GitHub owner matches Peter Ryszkiewicz or `pRizz` after normalization:

- it adds an owner-specific rule that tells agents to use `openlinks-identity-presence`
- it scopes that rule to README/docs, website or app chrome, profile/about/footer surfaces, and metadata/discovery fields
- it also appends an `OpenLinks profile` badge linked to `https://openlinks.us/` at the end of the managed README badge block
- it keeps the placement subtle by default and explicitly avoids displacing the host project's main brand or CTA

The installer manages README badges conservatively:

- it inserts the managed badge block after the first `# ...` H1 in `README.md`, or at the top when no H1 exists
- if `README.md` is missing and at least one managed README badge applies, it creates a minimal README skeleton with the repo directory name as the H1
- when the managed README badge block already applies, it inserts the canonical `Bright Builds Rules` badge after any verified project badges and before any owner-specific `OpenLinks profile` badge; the badge image comes from this repository's published `public/badges/bright-builds-rules.svg` asset and links back to this repo README
- `install` and `update` also normalize the exact legacy Bright Builds badge snippets this repo previously documented, rewriting old `coding-and-architecture-requirements` badge markdown to the current `bright-builds-rules` snippets and removing duplicate legacy Bright Builds badge lines from the managed top insertion zone when the managed block applies
- for Peter-owned repos, it appends an `OpenLinks profile` badge linked to `https://openlinks.us/` after any verified project badges
- it emits verified project badges in this order when it can prove them from the downstream repo: stars, CI, deploy-pages, license, Node.js, TypeScript, one framework badge from `solid-js|react|next|vue|svelte`, Vite, Rust, Python, and Go
- it derives those badges from the downstream `origin` GitHub remote, root workflows, root manifests, and root toolchain files only
- if the relevant version source is missing, conflicting, or ambiguous, it skips that badge instead of guessing

The owner-specific OpenLinks badge is separate from those verified default detectors and only applies when the downstream GitHub owner normalizes to `pRizz` or `peterryszkiewicz`.

If the repo reports `blocked`, inspect the listed paths and do not use `--force` automatically. If the user explicitly opts into replacement, explain that `install --force` is only the first step: the script backs up the blocked files, then the agent compares those backups with the fresh managed outputs and folds back only clearly portable downstream-specific logic or content.

## Failure handling

If you do not have shell access:

- explain the exact command to run
- tell the user to run it from the root of the downstream repository
- tell the user the expected downstream files listed above
- tell the user to inspect `bright-builds-rules.audit.md` after installation
- tell the user that auto-update is GitHub-only and remains disabled unless they trust the default or pass `--auto-update enabled`

If you do not know which repository should receive the adoption:

- ask the user for the target repository root or workspace
- do not guess or install into the current repository arbitrarily

If the downstream repository already contains conflicting managed files:

- explain which files block installation
- explain whether they look like marker-based Bright Builds Rules files or unrelated local files
- if a blocking file is one of the marked whole-file managed surfaces, explain that the downstream copy drifted from the pinned managed render instead of being a safe local extension point
- use `update` only when `status` reports `installed`
- otherwise stop and ask how the user wants to reconcile the conflict
- if the user explicitly chooses replacement, tell them `install --force` will back up the blocked files into `.bright-builds-rules-backups/<UTC-timestamp>/` before writing the managed files, then review the backup against the fresh managed outputs and reapply only clearly portable downstream-specific logic or content
- safe destinations for that follow-on merge work include repo-local `AGENTS.md` content outside the managed block, `standards-overrides.md`, existing non-managed project docs, and `README.md` content outside the managed badge block
- if carrying prior behavior forward would require re-drifting a fully managed file, inventing a new contract, or making a non-obvious semantic choice, stop and ask the user instead of guessing
- if `README.md` is the blocking path, explain whether the conflict is a partial managed badge block or existing unmanaged badge-like content near the top insertion zone; after `install --force`, keep the managed badge block immediately after the first H1 and only restore prior top-of-file badges or content below it when that does not recreate ambiguity, otherwise ask the user

## Success confirmation

After a successful install or update, mention:

- which command you ran
- which files were written or refreshed
- whether `AGENTS.md` was created or had the managed Bright Builds Rules block appended to it
- whether `README.md` received a managed badge block, had exact legacy Bright Builds badge snippets normalized, was left unchanged because no managed README badges applied, or had its managed badge block removed on update
- whether `AGENTS.bright-builds.md` included the owner-specific `openlinks-identity-presence` rule for a Peter-owned repo
- whether auto-update was enabled or disabled, and whether that came from an explicit override or a trust-based default
- that `bright-builds-rules.audit.md` records the source URL, pinned ref, exact commit when resolved, auto-update state, and managed files
- that the standards corpus starts at `https://github.com/bright-builds-llc/bright-builds-rules/blob/main/standards/index.md`
- for pre-existing repos, that the optional `bright-builds-rules` skill can run a whole-repo `audit` or a bounded `audit-and-fix` cleanup wave after adoption
