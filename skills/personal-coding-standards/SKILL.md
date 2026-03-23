---
name: personal-coding-standards
description: Use when applying, bootstrapping, reviewing, auditing, or audit-and-fixing code against this repository's personal coding and architecture standards.
---

# Personal Coding Standards

Use this skill when the user wants to:

- apply these standards to a repository
- review code or a plan against these standards
- audit a repository against these standards
- audit and remediate a repository against these standards
- bootstrap a repository with the local adoption files in `templates/`

## Workflow

1. Read `../../standards/index.md`.
2. Load the standards pages that match the task, including language-specific guidance when it is relevant.
3. Treat `../../standards/` as canonical. Do not duplicate or invent rules that are not present there.
4. Determine the mode explicitly:
   - `bootstrap`: adopt the standards into a repository
   - `review`: evaluate a current diff, code sample, or plan
   - `audit`: run a read-only repository baseline review, whole-repo by default
   - `audit-and-fix`: run the audit first, then execute one bounded remediation wave
5. For bootstrap work, start from the files in `../../templates/` and adapt them to the target repository.
6. For review, audit, and audit-and-fix work, read local `AGENTS.md` and `standards-overrides.md` first when present.
7. For review and audit work, classify deviations according to the standards' `must`, `should`, and `may` levels.
8. Apply documented local overrides before reporting a deviation.
9. For `audit`, default to a whole-repo baseline unless the user asks for a narrower scope. If the audit is narrowed, state the audited scope explicitly.
10. For `audit-and-fix`, perform the audit first, then choose one bounded remediation wave or subsystem instead of attempting whole-repo cleanup in one pass.
11. In `audit-and-fix`, default to fixing only low-risk, mechanically clear standards issues. Leave larger refactors as remaining findings or next-wave recommendations.
12. In `audit-and-fix`, do not silently update `standards-overrides.md`; report likely override candidates instead.
13. When reporting `audit-and-fix` results, separate applied fixes, remaining findings, and recommended next remediation waves.

## References

- Standards index: `../../standards/index.md`
- Core architecture: `../../standards/core/architecture.md`
- Code shape: `../../standards/core/code-shape.md`
- Verification: `../../standards/core/verification.md`
- Testing: `../../standards/core/testing.md`
- Rust guidance: `../../standards/languages/rust.md`
- TypeScript/JavaScript guidance: `../../standards/languages/typescript-javascript.md`
- Downstream templates: `../../templates/`

## Output expectations

- When bootstrapping, keep the local adoption layer thin.
- When reviewing, focus findings on standards violations and note any documented exception.
- When auditing, produce findings-first output. Treat `must` violations as findings unless a local override exists, `should` deviations as strong refactor recommendations, and `may` guidance as optional improvements.
- When audit scope is partial, say so explicitly and avoid implying whole-repo coverage.
- When using `audit-and-fix`, keep the first remediation wave bounded and conservative by default, then report what changed, what still violates the standards, and which override candidates need human confirmation.
- When proposing changes, preserve the canonical standards in this repository as the source of truth.
