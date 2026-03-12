# Todo

## Active work

- [x] Add a dedicated AI adoption guide with exact fetch URLs and adoption decision rules
- [x] Add repo-root agent routing so URL-only adoption tasks have a clear starting point
- [x] Align README and script help text with the documented AI install-vs-update workflow

## Verification

- [x] `scripts/manage-downstream.sh --help` matches the AI and README workflow descriptions
- [x] `./scripts/verify-docs.sh` passes
- [x] Fresh install and update still work when following the documented AI flow
- [x] README makes `AI-ADOPTION.md` discoverable without reading deeper repo docs
- [x] `AI-ADOPTION.md` is self-contained for URL-only adoption
- [x] Diff reviewed for unintended side effects

## Completion review

Completed on 2026-03-12.

Residual risks:

- The documented default pin remains `main` until the repository starts publishing tags, so AIs following the guide will not yet pin to immutable releases.
