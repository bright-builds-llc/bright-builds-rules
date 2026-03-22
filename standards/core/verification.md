# Verification

This page defines the baseline expectations for pre-commit verification without forcing every repository into the same toolchain shape.

## Run Relevant Repo-Native Verification Before Commit

- Level: `must`
- Intent: Catch regressions before they land while keeping the verification burden proportional to the actual change.
- Rule: Before committing, run the repository's relevant verification steps for the changed paths and do not commit if those checks fail. Determine the verification surface in this order: repo-local guidance first, then a repo-owned aggregate command such as `verify`, `check`, `validate`, or `ci`, then framework-native commands, then individual tool commands only when needed. Scope the run to the affected files, packages, workspaces, or services when the repository supports that. If a change spans multiple language or runtime surfaces, run the relevant verification for each affected surface.
- Rationale: Requiring passed verification before commit catches common regressions early, but a durable standard also has to respect monorepos, mixed-language repositories, and ecosystems with different default tooling. Using the repository's own verification entrypoints preserves local intent and avoids turning policy into guesswork.
- Good example:

```text
Change: docs plus one Rust crate
- run the repo's docs check for the changed Markdown
- run the crate-scoped Rust verify/check command used by the repo
- skip unrelated frontend or end-to-end suites
```

- Bad example:

```text
Change: one package in a monorepo
- invent a hand-rolled command list even though the repo already has `pnpm verify --filter ...`
- skip the available package-scoped checks and commit anyway after a failing typecheck
```

- Exceptions or escape hatches: Do not invent missing verification categories. A repository that has tests but no linter, or a build step but no typecheck, should run what it actually has. Heavy integration, browser, end-to-end, or external-service suites may remain pre-push or CI-only when the repo's local guidance says so. If local verification is blocked by missing secrets, required services, containers, browsers, network access, or similar prerequisites, stop and ask or document a local exception instead of silently skipping the check.
- Review questions: What are the repo's documented verification entrypoints for these changed paths? Is there an affected-package or changed-path mode that avoids whole-repo work? Does the change touch more than one verification surface?
- Automation potential: Scripts and CI can enforce parts of this rule, but judging what is relevant still depends on changed-path and repository context.

## Prefer Repo-Owned Verification Entry Points

- Level: `should`
- Intent: Keep verification consistent with the repository's own workflow instead of reconstructing it from tool fragments.
- Rule: Prefer a repo-owned verification entrypoint such as `make verify`, `just check`, `bin/verify`, `cargo xtask`, `nx affected`, or `turbo` over manually chaining low-level tool commands when that entrypoint already captures the intended local workflow.
- Rationale: Repositories often encode subtle local knowledge in aggregate commands, including ordering, filtering, environment setup, and tool flags. Rebuilding that knowledge ad hoc is brittle and easy to get wrong.
- Good example:

```bash
just check changed=packages/billing
```

- Bad example:

```bash
eslint packages/billing
tsc --noEmit
vitest packages/billing
```

- Exceptions or escape hatches: If the repo-owned command is unavailable, undocumented, or clearly broader than necessary for the change, fall back to the next best repo-native or framework-native command set. When using auto-fix commands is the repo norm, rerun the relevant checks after the fixes and avoid pulling unrelated rewrites into the commit.
- Review questions: Does the repository already define a single command that expresses the intended verification workflow? Are low-level tool invocations drifting away from the documented local contract?
- Automation potential: Tooling can detect common aggregate entrypoints, but choosing the narrowest correct one still needs context.

## Coordinate With Existing Hook-Based Verification

- Level: `should`
- Intent: Avoid silently duplicating verification that may already be enforced by local commit automation.
- Rule: If the repository shows likely hook-managed verification signals such as `.husky/`, `lefthook.yml`, `.pre-commit-config.yaml`, `.pre-commit-config.yml`, `.git/hooks/`, or `lint-staged`-style configuration, do not assume manual duplication is required. When repo-local guidance does not already define the workflow, ask the user whether to rely on hooks, run the checks manually now, or do both.
- Rationale: Existing hook automation may already run the relevant checks, but those signals are heuristics, not proof that the hook is installed, active, or comprehensive. Coordinating explicitly avoids wasted time and conflicting assumptions.
- Good example:

```text
Detected `.husky/pre-commit` and `lint-staged` in package.json.
Local docs do not say whether manual verification is still expected.
Ask which path the repo prefers before duplicating the same checks.
```

- Bad example:

```text
Detect hook config, ignore it, run the same lint/test suite manually, and let the commit trigger the same work again without warning.
```

- Exceptions or escape hatches: If repo-local guidance already says that hooks are advisory, mandatory, or intentionally incomplete, follow that documented workflow instead of asking again.
- Review questions: Is there already hook-based verification here? Is it documented clearly enough to avoid a user question? Are the hook signals only partial, local-machine specific, or obviously stale?
- Automation potential: Repositories can be scanned for common hook files, but their presence alone cannot prove runtime behavior.
