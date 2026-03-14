# Lessons

## 2026-03-12

- What went wrong: A CLI surface cleanup was treated as finished before repo-wide references and breadcrumbs were fully audited.
- Preventive rule: After changing any downstream contract, run a full repo search for the old interface and add explicit audit-trail coverage before calling the change complete.
- Trigger signal: Any change that removes or reshapes install, update, or uninstall behavior.

## 2026-03-13

- What went wrong: I kept planning around compatibility-preserving downstream adoption behavior after the user had signaled that a clean breaking reset was acceptable and simpler.
- Preventive rule: When a downstream installer is still pre-adoption, explicitly test whether dropping legacy compatibility produces a cleaner contract before designing merge or migration logic.
- Trigger signal: A request that mentions no current users, a safe compatibility break, or a desire to simplify the install model.
