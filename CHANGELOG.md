# Changelog

This repository uses a simple release-notes model instead of a heavyweight changelog taxonomy.

## Unreleased

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

## Release note guidance

When cutting a release, summarize:

- New or changed `must` rules
- New or changed `should` guidance that materially affects adoption
- Template changes that downstream repos should consider pulling in
- Skill behavior changes that affect AI-assisted workflows
