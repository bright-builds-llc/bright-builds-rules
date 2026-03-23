# Local Guidance

This page defines how repositories should capture recurring local knowledge without turning every local pattern into a canonical standard or an override.

## Document Recurring Repo-Local Knowledge

- Level: `should`
- Intent: Keep recurring repo-specific workflow knowledge easy to find for new humans and agents without promoting it into a cross-repo rule prematurely.
- Rule: When you observe a repo-specific pattern or repetitive action that is likely to recur and is not already obvious from code, scripts, or existing docs, document it or propose documenting it in `AGENTS.md` under `## Repo-Local Guidance`. Treat the trigger as met after either two observations of the same local pattern or one confirmed confusion, verification failure, or onboarding miss that is clearly likely to recur. Use this section for recurring local facts such as verification entrypoints, hook behavior, CI-only suites, local service prerequisites, codegen expectations, generated-file ownership, recurring path or layout conventions, release or deploy quirks, and other non-obvious "we always do X here" workflow rules.
- Rationale: Repeated repo-specific clarifications are expensive when they live only in chat history, reviewer memory, or old pull requests. A small, stable local guidance surface helps newcomers and agents get local behavior right faster while preserving the distinction between global standards and local practice.
- Good example:

```text
## Repo-Local Guidance

- Verify changed packages with `pnpm turbo run check --filter=web`.
- `.husky/pre-commit` is advisory here; manual verification is still expected before commit.
- Browser E2E stays CI-only because local browser setup is intentionally optional.
- `apps/web/src/routeTree.gen.ts` is generated; edit the route definitions instead.
```

- Bad example:

```text
- Keep the hook behavior, generated-file ownership, and CI-only suite expectations undocumented.
- Repeat the same clarification in review comments and onboarding chats every few weeks.
- Record a recurring local workflow rule only in a one-off issue or pull request.
```

- Exceptions or escape hatches: Do not put secrets, temporary incidents, transient outages, one-off tickets, or personal preferences in `Repo-Local Guidance`. If the item is a deliberate deviation from a canonical standard, record it in `standards-overrides.md` instead. If the pattern is broadly useful across many repositories, upstream it into the canonical standards rather than copying it repo by repo.
- Review questions: Is there recurring local behavior that a newcomer would likely miss? Has the same clarification already been repeated or already caused a failure? Does this belong in `Repo-Local Guidance`, `standards-overrides.md`, or the canonical standards corpus?
- Automation potential: Repeated review comments, onboarding notes, or audit findings can suggest candidates, but deciding whether a pattern is durable and truly repo-local still needs judgment.

## Keep Repo-Local Guidance Concise and Durable

- Level: `should`
- Intent: Keep local AGENTS guidance fast to scan, stable enough to trust, and clearly separated from runbooks or historical notes.
- Rule: Keep `## Repo-Local Guidance` high signal: prefer short bullets, direct commands, and links to repo-owned runbooks or deeper docs when more detail is needed. If an item becomes long, volatile, or procedural, summarize the stable invariant in `AGENTS.md` and link to the deeper repo-owned document instead of copying long onboarding docs, full playbooks, or incident history into the section.
- Rationale: `AGENTS.md` works best as a quick-entry local map. When it accumulates long procedures or narrative history, readers stop trusting it as the fast path and the highest-value guidance gets buried.
- Good example:

```text
## Repo-Local Guidance

- Release flow: run `just release-dry-run` first. Full playbook: `docs/release.md`.
- Local Postgres is required for `bin/verify api`; seed data lives in `docs/dev-db.md`.
- `scripts/sync-schema.sh` is the supported codegen entrypoint; do not edit generated snapshots by hand.
```

- Bad example:

```text
## Repo-Local Guidance

- Paste a 70-line release checklist directly into `AGENTS.md`.
- Copy a long onboarding guide, old incident timeline, and step-by-step deploy playbook into the same section.
- Link to ephemeral chat threads instead of repo-owned documents.
```

- Exceptions or escape hatches: Very small repositories may keep all local guidance directly in `AGENTS.md` if it stays short and stable. If a deeper runbook does not exist yet, keep the local bullet concise until there is a real need to split it out.
- Review questions: Can a newcomer act on the item quickly? Is `AGENTS.md` collecting procedural detail that belongs in a repo-owned runbook? Are the linked details stable and checked into the repository?
- Automation potential: Simple length checks can flag drift, but signal-to-noise and long-term durability still require review judgment.
