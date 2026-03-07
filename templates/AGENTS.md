# AGENTS.md

Use this file as the thin local adoption layer in a downstream repository.

## Canonical standards source

- Standards repository: `REPLACE_WITH_REPO_URL`
- Version pin: `REPLACE_WITH_TAG_OR_COMMIT`
- Canonical entrypoint: `REPLACE_WITH_TAGGED_STANDARDS_INDEX_URL`

## Applicable language packs

- `REPLACE_WITH_LANGUAGE_PACKS`

Examples:

- `rust`
- `typescript-javascript`
- `rust, typescript-javascript`

## Highest-signal rules

- Prefer functional core / imperative shell for business logic.
- Prefer early returns over nesting.
- Treat functions over roughly 200 lines as refactor triggers.
- Treat files over roughly 628 lines as refactor triggers.
- Parse boundary data into domain types instead of re-validating primitives everywhere.
- Make illegal states unrepresentable when the language makes that practical.
- In Rust, prefer `let...else` for guard-style extraction when it improves clarity.
- In TypeScript/JavaScript, do not use class inheritance for our own types.
- Unit test pure code and business logic.
- Structure unit tests as Arrange, Act, Assert and keep each test focused on one concern.

## Local overrides and exceptions

Document repo-specific deviations in `standards-overrides.md`.

Recommended fields for each override:

- standard
- local decision
- rationale
- owner
- review date

## Agent workflow

1. Read this local file first.
2. Read the pinned canonical standards entrypoint.
3. Load only the language packs relevant to the task.
4. Apply local overrides before proposing or reviewing changes.
5. If this repository intentionally diverges from the canonical standards, record that divergence instead of silently ignoring it.
