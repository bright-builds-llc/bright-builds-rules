# Changelog

This repository uses a simple release-notes model instead of a heavyweight changelog taxonomy.

## Unreleased

- Extended the pre-commit verification guidance so changed Markdown and shell paths pick up conditional check-mode formatter verification when supported tools are already available locally or through the repo's normal runner, without requiring new tool installs
- Added a Rust `must` rule that new or touched multi-file modules should use `foo.rs` plus `foo/` instead of `foo/mod.rs`, while leaving stable untouched `mod.rs` trees as non-retroactive migrations
- Added `should` guidance for greenfield standalone JavaScript and TypeScript projects to prefer Bun for package management and routine script execution, while leaving existing npm/pnpm/yarn repositories unchanged unless they deliberately migrate
- Added a core `Verification` standard for pre-commit repo-native checks, including affected-path scope, aggregate-command preference, CI-only heavy-suite exceptions, blocked-environment handling, and hook-aware user prompting
- Updated downstream managed templates to surface the new verification guidance, including flexible pre-commit wording and documented override notes for hook-owned or CI-only verification
- Added trust-aware downstream auto-update management, including persisted auto-update state in the audit trail, a managed GitHub Actions workflow plus helper script, and direct-push with PR fallback behavior
- Added `should` guidance for repo-owned scripts to be rerunnable when sensible and to persist breadcrumb-heavy logs plus run summaries in a repo-defined gitignored path, plus matching downstream template wording
- Added `should` guidance to avoid hiding foreign-language logic inside strings, keep orchestration thin, and prefer repo-owned or language-aware artifacts over embedded shell, JS, query, or pattern snippets, plus matching downstream template wording
- Added cross-language `should` guidance to prefix internal nullable or optional names with `maybe`, including functions, bindings, internal fields, and Promise or Future-wrapped nullish values, while reserving `MaybeX` aliases for repeated clarity wins and keeping narrow contract-driven exceptions
- Initial standards corpus for architecture, code shape, testing, Rust, and TypeScript/JavaScript
- Downstream adoption templates for `AGENTS.md`, `CONTRIBUTING.md`, overrides, and PRs
- Optional Codex skill for applying or reviewing against the standards
- Docs verification script and Markdown lint configuration
- Downstream management script plus README one-liners for install, update, status, and uninstall
- Generic downstream installation flow with language-agnostic templates and docs
- Dedicated AI adoption guide plus repo-root agent routing for URL-only adoption workflows
- Breaking reset to a marker-based downstream installer with `AGENTS.bright-builds.md`, append-only `AGENTS.md` integration, and `installable|installed|blocked` status
- Simplified downstream audit trail and uninstall flow, including removal of breadcrumb comments and preservation of repo-local `standards-overrides.md`
- Exact-commit provenance recorded alongside the requested ref in `AGENTS.bright-builds.md`, the audit trail, and installed `status`
- Default downstream README badge management with conservative blocking, force-repair support, and detector-driven badge generation for GitHub/workflow, JS/TS, Rust, Python, and Go repos

## Release note guidance

When cutting a release, summarize:

- New or changed `must` rules
- New or changed `should` guidance that materially affects adoption
- Template changes that downstream repos should consider pulling in
- Skill behavior changes that affect AI-assisted workflows
