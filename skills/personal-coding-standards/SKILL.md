---
name: personal-coding-standards
description: Use when applying, bootstrapping, or reviewing code against this repository's personal coding and architecture standards.
---

# Personal Coding Standards

Use this skill when the user wants to:

- apply these standards to a repository
- review code or a plan against these standards
- bootstrap a repository with the local adoption files in `templates/`

## Workflow

1. Read `../../standards/index.md`.
2. Load only the standards pages that match the task and language.
3. Treat `../../standards/` as canonical. Do not duplicate or invent rules that are not present there.
4. For bootstrap work, start from the files in `../../templates/` and adapt them to the target repository.
5. For review work, classify deviations according to the standards' `must`, `should`, and `may` levels.
6. Apply documented local overrides before reporting a deviation.

## References

- Standards index: `../../standards/index.md`
- Core architecture: `../../standards/core/architecture.md`
- Code shape: `../../standards/core/code-shape.md`
- Testing: `../../standards/core/testing.md`
- Rust language pack: `../../standards/languages/rust.md`
- TypeScript/JavaScript language pack: `../../standards/languages/typescript-javascript.md`
- Downstream templates: `../../templates/`

## Output expectations

- When bootstrapping, keep the local adoption layer thin.
- When reviewing, focus findings on standards violations and note any documented exception.
- When proposing changes, preserve the canonical standards in this repository as the source of truth.
