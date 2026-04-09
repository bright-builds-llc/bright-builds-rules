---
name: bright-builds-rules
description: Use when adopting, checking, refreshing, reviewing, auditing, or audit-and-fixing code against Bright Builds Rules.
---

# Bright Builds Rules

Use this skill when the user wants to:

- adopt the Bright Builds Rules into a repository
- check Bright Builds Rules adoption status in a repository
- refresh or sync Bright Builds managed rules in a repository
- review code or a plan against these standards
- audit a repository against these standards
- audit and remediate a repository against these standards

## Workflow

1. For downstream repos with Bright Builds Rules installed, the required reading order is: local `AGENTS.md`, `AGENTS.bright-builds.md`, `standards-overrides.md` when present, then the pinned canonical standards pages relevant to the task. Treat `AGENTS.md` as the local entrypoint, not the complete Bright Builds Rules spec, and stop to load the missing sources before continuing if that has not happened yet.
2. Read `../../standards/index.md` when working in this canonical repository, or otherwise load the pinned canonical standards entrypoint referenced by the downstream Bright Builds Rules files.
3. Load the standards pages that match the task, including language-specific guidance when it is relevant.
4. Treat `../../standards/` as canonical when working in this repository. Do not duplicate or invent rules that are not present there.
5. Resolve intent before choosing a mode:

    - `adopt`: install the Bright Builds Rules into a repository
    - `status`: inspect the current Bright Builds Rules adoption state
    - `refresh`: update an existing Bright Builds Rules install or sync managed rules
    - `review`: evaluate a current diff, code sample, or plan
    - `audit`: run a read-only repository baseline review, whole-repo by default
    - `audit-and-fix`: run the audit first, then execute one bounded remediation wave

6. If the skill is invoked with no arguments, infer the mode from the current thread and repo state when that intent is clear.
7. If the skill is invoked with no arguments and intent is still ambiguous, return a short action menu instead of erroring. Offer:

    - check Bright Builds Rules status
    - adopt or update Bright Builds Rules
    - run `bash ./scripts/bright-builds-auto-update.sh` when the managed helper exists
    - run an `audit`
    - run an `audit-and-fix` wave
    - review a current diff or plan

8. For `adopt`, `status`, and `refresh` work, follow `../../AI-ADOPTION.md` and keep the status-first Bright Builds Rules flow intact.
9. For Bright Builds Rules refresh intent, prefer the managed helper when the repo already has `./scripts/bright-builds-auto-update.sh` and the user sounds like they want to refresh or sync the installed Bright Builds Rules. Run `bash ./scripts/bright-builds-auto-update.sh` from the repo root in that case.
10. If the helper is missing, or the repo is not clearly an already-installed downstream repo, fall back to the status-first manager flow:

    - run `scripts/manage-downstream.sh status` first when working inside this canonical repository or another repo that already has that script locally
    - otherwise use the `manage-downstream.sh` commands documented in `../../AI-ADOPTION.md`
    - use `install` when status reports `Repo state: installable`
    - use `update` when status reports `Repo state: installed`
    - stop and explain blocking files when status reports `Repo state: blocked`
    - never choose `install --force` automatically
    - if the user explicitly opts into replacement, treat `install --force` as a backup-first merge-assisted path: inspect `.bright-builds-rules-backups/<UTC-timestamp>/`, compare the backups with the fresh managed outputs, and reapply only clearly portable downstream-specific logic or content into safe local extension points
    - safe merge destinations include repo-local `AGENTS.md` content outside the managed block, `standards-overrides.md`, existing non-managed project docs, and `README.md` content outside the managed badge block
    - if carrying prior behavior forward would require re-drifting a fully managed file, inventing a new contract, or making a non-obvious semantic choice, stop and ask the user instead of guessing
    - if `README.md` is the blocking path, keep the managed badge block immediately after the first H1 and only restore prior top-of-file badges or content below it when that does not recreate ambiguity

11. Use `../../templates/` as source material only when editing the managed downstream assets in this repository. Do not bypass the manager flow by manually copying template files into a downstream repo unless the user explicitly wants that lower-level maintenance work.
12. For review, audit, and audit-and-fix work, apply the downstream reading order before evaluating the work: local `AGENTS.md`, `AGENTS.bright-builds.md`, `standards-overrides.md` when present, then the relevant canonical pages.
13. For review and audit work, classify deviations according to the standards' `must`, `should`, and `may` levels.
14. Apply documented local guidance and overrides before reporting a deviation.
15. For `audit`, default to a whole-repo baseline unless the user asks for a narrower scope. If the audit is narrowed, state the audited scope explicitly.
16. For `audit-and-fix`, perform the audit first, then choose one bounded remediation wave or subsystem instead of attempting whole-repo cleanup in one pass.
17. In `audit-and-fix`, default to fixing only low-risk, mechanically clear standards issues. Leave larger refactors as remaining findings or next-wave recommendations.
18. In `audit-and-fix`, do not silently update `standards-overrides.md`; report likely override candidates instead.
19. When reporting `audit-and-fix` results, separate applied fixes, remaining findings, and recommended next remediation waves.

## References

- Bright Builds Rules AI adoption guide: `../../AI-ADOPTION.md`
- Raw Bright Builds Rules installer: `https://raw.githubusercontent.com/bright-builds-llc/bright-builds-rules/main/scripts/manage-downstream.sh`
- Standards index: `../../standards/index.md`
- Core architecture: `../../standards/core/architecture.md`
- Code shape: `../../standards/core/code-shape.md`
- Operability: `../../standards/core/operability.md`
- Local guidance: `../../standards/core/local-guidance.md`
- Verification: `../../standards/core/verification.md`
- Testing: `../../standards/core/testing.md`
- Rust guidance: `../../standards/languages/rust.md`
- TypeScript/JavaScript guidance: `../../standards/languages/typescript-javascript.md`
- Downstream templates: `../../templates/`

## Output expectations

- When handling Bright Builds Rules adoption, status, or refresh work, state which helper or manager command you used and why.
- When using the blocked merge-assisted path, state that explicit user approval was required for `install --force`, then summarize what was safely folded back in and what still needs user judgment.
- When no clear context is available, offer the short action menu instead of failing or inventing intent.
- When reviewing, focus findings on standards violations and note any documented exception.
- For plan, review, and audit outputs, briefly name the local guidance, sidecar, overrides, or canonical standards pages that materially informed the result.
- When auditing, produce findings-first output. Treat `must` violations as findings unless a local override exists, `should` deviations as strong refactor recommendations, and `may` guidance as optional improvements.
- When auditing, treat missing repo-local guidance as a `should` recommendation only when there is concrete evidence of recurring undocumented local workflow knowledge or a repeated local confusion point.
- When audit scope is partial, say so explicitly and avoid implying whole-repo coverage.
- When using `audit-and-fix`, keep the first remediation wave bounded and conservative by default, then report what changed, what still violates the standards, and which override candidates need human confirmation.
- When proposing changes, preserve the canonical standards in this repository as the source of truth.
