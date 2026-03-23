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
- Prefix internal nullable or optional names with `maybe`, including functions, bindings, and internal fields, and use `MaybeX` aliases only when they materially clarify a repeated nullable surface.
- Split oversized functions and files into sensible units.
- Do not hide substantial foreign-language logic inside strings; keep workflow and automation config thin, move scripts, queries, and similar artifacts into repo-owned or language-aware files, make checked-in scripts rerunnable when sensible, and have them leave breadcrumb-heavy logs and summaries in a repo-defined gitignored location.
- Parse boundary input into domain types when that removes repeated validation.
- Apply any relevant language-specific guidance from the pinned canonical standards.

## Verification expectations

- Before committing, run the relevant repo-native verification steps for the changed paths, including Markdown or shell formatter checks when supported tools are already available and local guidance does not define a clearer workflow, and do not commit if they fail.
- Prefer a repo-owned verify/check/validate/ci command when it exists over reconstructing tool commands by hand.
- Heavy integration, end-to-end, or external-service suites may stay pre-push or CI-only when local guidance or `standards-overrides.md` documents that choice.
- If hooks appear to own verification here and the local workflow is unclear, clarify whether the repo expects hooks, manual checks, or both.

## Test expectations

- Unit test pure code and business logic.
- Keep each unit test focused on one concept.
- Use explicit Arrange, Act, Assert sections unless the structure is truly obvious.

## Pull request expectations

- Explain the behavior change, not just the code movement.
- Call out any new exceptions to the standards.
- Include verification evidence for the changed paths.
- Note any residual risks or follow-up work.
