---
name: personal-coding-standards
description: Use when adopting, checking, refreshing, reviewing, auditing, or audit-and-fixing code against this repository's Bright Builds coding and architecture standards.
---

# Personal Coding Standards

Use this skill when the user wants to:

- adopt the Bright Builds requirements into a repository
- check Bright Builds adoption status in a repository
- refresh or sync Bright Builds managed rules in a repository
- review code or a plan against these standards
- audit a repository against these standards
- audit and remediate a repository against these standards

## Workflow

1. Read `../../standards/index.md`.
2. Load the standards pages that match the task, including language-specific guidance when it is relevant.
3. Treat `../../standards/` as canonical. Do not duplicate or invent rules that are not present there.
4. Resolve intent before choosing a mode:
   - `adopt`: install the Bright Builds requirements into a repository
   - `status`: inspect the current Bright Builds adoption state
   - `refresh`: update an existing Bright Builds install or sync managed rules
   - `review`: evaluate a current diff, code sample, or plan
   - `audit`: run a read-only repository baseline review, whole-repo by default
   - `audit-and-fix`: run the audit first, then execute one bounded remediation wave
5. If the skill is invoked with no arguments, infer the mode from the current thread and repo state when that intent is clear.
6. If the skill is invoked with no arguments and intent is still ambiguous, return a short action menu instead of erroring. Offer:
   - check Bright Builds status
   - adopt or update Bright Builds requirements
   - run `bash ./scripts/bright-builds-auto-update.sh` when the managed helper exists
   - run an `audit`
   - run an `audit-and-fix` wave
   - review a current diff or plan
7. For `adopt`, `status`, and `refresh` work, follow `../../AI-ADOPTION.md` and keep the status-first Bright Builds flow intact.
8. For Bright Builds refresh intent, prefer the managed helper when the repo already has `./scripts/bright-builds-auto-update.sh` and the user sounds like they want to refresh or sync the installed Bright Builds rules. Run `bash ./scripts/bright-builds-auto-update.sh` from the repo root in that case.
9. If the helper is missing, or the repo is not clearly an already-installed downstream repo, fall back to the status-first manager flow:
   - run `scripts/manage-downstream.sh status` first when working inside this canonical repository or another repo that already has that script locally
   - otherwise use the `manage-downstream.sh` commands documented in `../../AI-ADOPTION.md`
   - use `install` when status reports `Repo state: installable`
   - use `update` when status reports `Repo state: installed`
   - stop and explain blocking files when status reports `Repo state: blocked`
   - never choose `install --force` automatically
10. Use `../../templates/` as source material only when editing the managed downstream assets in this repository. Do not bypass the manager flow by manually copying template files into a downstream repo unless the user explicitly wants that lower-level maintenance work.
11. For review, audit, and audit-and-fix work, read local `AGENTS.md` and `standards-overrides.md` first when present.
12. For review and audit work, classify deviations according to the standards' `must`, `should`, and `may` levels.
13. Apply documented local overrides before reporting a deviation.
14. For `audit`, default to a whole-repo baseline unless the user asks for a narrower scope. If the audit is narrowed, state the audited scope explicitly.
15. For `audit-and-fix`, perform the audit first, then choose one bounded remediation wave or subsystem instead of attempting whole-repo cleanup in one pass.
16. In `audit-and-fix`, default to fixing only low-risk, mechanically clear standards issues. Leave larger refactors as remaining findings or next-wave recommendations.
17. In `audit-and-fix`, do not silently update `standards-overrides.md`; report likely override candidates instead.
18. When reporting `audit-and-fix` results, separate applied fixes, remaining findings, and recommended next remediation waves.

## References

- Bright Builds AI adoption guide: `../../AI-ADOPTION.md`
- Raw Bright Builds installer: `https://raw.githubusercontent.com/bright-builds-llc/coding-and-architecture-requirements/main/scripts/manage-downstream.sh`
- Standards index: `../../standards/index.md`
- Core architecture: `../../standards/core/architecture.md`
- Code shape: `../../standards/core/code-shape.md`
- Verification: `../../standards/core/verification.md`
- Testing: `../../standards/core/testing.md`
- Rust guidance: `../../standards/languages/rust.md`
- TypeScript/JavaScript guidance: `../../standards/languages/typescript-javascript.md`
- Downstream templates: `../../templates/`

## Output expectations

- When handling Bright Builds adoption, status, or refresh work, state which helper or manager command you used and why.
- When no clear context is available, offer the short action menu instead of failing or inventing intent.
- When reviewing, focus findings on standards violations and note any documented exception.
- When auditing, produce findings-first output. Treat `must` violations as findings unless a local override exists, `should` deviations as strong refactor recommendations, and `may` guidance as optional improvements.
- When audit scope is partial, say so explicitly and avoid implying whole-repo coverage.
- When using `audit-and-fix`, keep the first remediation wave bounded and conservative by default, then report what changed, what still violates the standards, and which override candidates need human confirmation.
- When proposing changes, preserve the canonical standards in this repository as the source of truth.
