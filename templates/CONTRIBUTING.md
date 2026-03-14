# CONTRIBUTING.md

Use this file as the starting point for a downstream repository's contribution guide.

## Default contribution expectations

- Follow the local `AGENTS.md`.
- Use the pinned version of the central standards repository as the canonical reference.
- Prefer simple, root-cause fixes over broad rewrites.
- Document repo-specific exceptions in `standards-overrides.md`.

## Code expectations

- Keep business logic in a functional core when practical.
- Prefer early returns and shallow control flow.
- Split oversized functions and files into sensible units.
- Parse boundary input into domain types when that removes repeated validation.
- Apply any relevant language-specific guidance from the pinned canonical standards.

## Test expectations

- Unit test pure code and business logic.
- Keep each unit test focused on one concept.
- Use explicit Arrange, Act, Assert sections unless the structure is truly obvious.
- Run the repository's required verification steps before opening a pull request.

## Pull request expectations

- Explain the behavior change, not just the code movement.
- Call out any new exceptions to the standards.
- Include verification evidence for the changed paths.
- Note any residual risks or follow-up work.
