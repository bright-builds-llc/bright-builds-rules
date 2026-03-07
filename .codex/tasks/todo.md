# Todo

## Active work

- [x] Create the canonical standards corpus under `standards/`
- [x] Create thin downstream adoption templates under `templates/`
- [x] Add the optional Codex skill under `skills/`
- [x] Add repository verification assets for docs hygiene

## Verification

- [x] Markdown lint passes
- [x] Internal Markdown links pass
- [x] Diff reviewed for unintended side effects

## Completion review

Completed on 2026-03-07.

Residual risks:

- The generated Codex skill files were manually inspected, but the bundled `quick_validate.py` script could not run in this environment because `PyYAML` is not installed.
