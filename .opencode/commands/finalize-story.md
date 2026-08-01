---
description: Finalize and commit a story after controller validation succeeds
agent: build
---

Finalize story `$ARGUMENTS`. Do not implement or repair gameplay in this command.

Preconditions:

1. Read `TASKS.json` and require the story to be `ready_for_validation`.
2. Read `.loop-state/active.json` and require every acceptance criterion ID to be
   listed in `verified_criteria`.
3. Read the controller validation log stored as `last_command` in the state file;
   it must exist and contain `All configured validation checks passed.`.
4. Run `git status --short` and confirm every change matches `allowed_paths` plus
   `TASKS.json` and `PROGRESS.md`.

Finalization:

1. Update the Current State section and append one concise entry to `PROGRESS.md`.
2. Set the story to `done` and clear `active_story_id` in `TASKS.json`.
3. Do not change `ARCHITECTURE.md` unless the implementation already made a durable
   architectural decision that is missing from it.
4. Run `git diff --check` and review `git diff --stat`.
5. Stage only the story's `allowed_paths`, `TASKS.json`, `PROGRESS.md`, and any
   justified `ARCHITECTURE.md` change.
6. Commit once using `story(SXX): concise story title`.
7. Do not edit tracked files after the commit.

If any precondition is false, leave the story `ready_for_validation`, do not commit,
record the exact reason in `.loop-state/active.json`, and stop.
