# Changelog

This repository uses a simple release-notes model instead of a heavyweight changelog taxonomy.

## Unreleased

- Hardened managed-source downloads with bounded transient retries, non-empty response validation, and atomic replacement so failed fetches cannot empty or publish managed files.
- Added conservative skill and adoption-path context-cost snapshots, append-only history, guarded README visibility, and local/CI enforcement.
- Added a bounded startup-loading and maintenance `should` rule for repositories that already track active lessons, plus matching managed-sidecar guidance that propagates through normal downstream updates without creating or modifying downstream lesson artifacts.
- Hardened managed auto-update token handling so no-op and non-workflow updates can still use `github.token`, while workflow-file changes detect missing or under-scoped `BRIGHT_BUILDS_PUSH_TOKEN`, skip futile PR fallback, and print the exact secure repair and rerun flow, including for legacy managed helpers.
- Added `should` guidance for new TypeScript/JavaScript web frontends to default to SolidJS unless a documented constraint requires another stack, plus matching managed template wording.
- Updated app provenance guidance so visible commit values default to short hashes, public GitHub commit hashes link to commit pages when URLs are known, and CI-produced build times or build ids link to workflow runs when stable run URLs are available.
- Clarified that web UI commit and build provenance links should open in new tabs with safe link attributes.
- Added `should` guidance for frontend experiences to default to dark mode unless a documented product constraint requires otherwise, plus matching downstream managed template routing.
- Relaxed app provenance guidance so copyable build-info summaries are optional support affordances instead of required UI.
- Added downstream installation of the managed local `standards/` corpus so routing hints resolve to files inside adopted repositories while retaining source and exact-commit provenance in the sidecar and audit trail
- Breaking skill rename: renamed the optional Codex skill from `Personal Coding Standards` to `Bright Builds Rules` so the slug, path, and UI label align with `Bright Builds Rules`
- Breaking rename: standardized the canonical project identity, downstream installer contract, audit trail name, markers, backup paths, badge assets, and docs around `Bright Builds Rules`
- Added `should` guidance to fetch remote state, rebase onto the latest upstream or use the repo's equivalent sync path before substantive implementation work, treat detached-head worktrees as default-branch work by default unless local guidance says otherwise, resolve sync conflicts before proceeding, and then run the repo's normal bootstrap or dependency-sync step when dependencies or tools may be stale, plus matching downstream managed template wording
- Added `should` guidance to keep shared versioned task and lesson trackers merge-safe with stable-ID append-only blocks, localized updates, and derived summaries instead of hot shared status sections, plus matching downstream managed AGENTS wording
- Added a core `Local Guidance` standard for promoting recurring repo-specific workflow knowledge into `AGENTS.md` under `## Repo-Local Guidance`, while keeping `standards-overrides.md` reserved for deliberate standards deviations
- Extended the pre-commit verification guidance so changed Markdown and shell paths pick up conditional check-mode formatter verification when supported tools are already available locally or through the repo's normal runner, without requiring new tool installs
- Added a Rust `must` rule that new or touched multi-file modules should use `foo.rs` plus `foo/` instead of `foo/mod.rs`, while leaving stable untouched `mod.rs` trees as non-retroactive migrations
- Added `should` guidance for greenfield standalone JavaScript and TypeScript projects to prefer Bun for package management and routine script execution, while leaving existing npm/pnpm/yarn repositories unchanged unless they deliberately migrate
- Added a core `Verification` standard for pre-commit repo-native checks, including affected-path scope, aggregate-command preference, CI-only heavy-suite exceptions, blocked-environment handling, and hook-aware user prompting
- Updated downstream managed templates to surface the new verification guidance, clarify the `Repo-Local Guidance` versus `standards-overrides.md` split, and keep AGENTS as the local entrypoint
- Added trust-aware downstream auto-update management, including persisted auto-update state in the audit trail, a managed GitHub Actions workflow plus helper script, and direct-push with PR fallback behavior
- Added visible whole-file managed markers for installer-owned downstream files, blocking drift detection for marked managed outputs, legacy exact-match migration on update, and drift-preserving uninstall behavior
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
