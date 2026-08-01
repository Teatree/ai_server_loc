---
description: Resume only the smallest unresolved part of the active story
agent: build
---

Resume story `$ARGUMENTS`. This is a recovery pass, not a new planning pass.

1. Read `TASKS.json` and require this story to be `in_progress`.
2. Read `.loop-state/active.json` before any source file.
3. Read the active story's `recovery_hints` when present.
4. Read only the files named in `changed_files`, `next_action`, or the failing check.
5. Read the latest relevant `PROGRESS.md` entry only if the state file is insufficient.
6. Run `git status --short` and reject files outside `allowed_paths`.
7. Execute the single `next_action` first.
8. Run the narrowest relevant focused validation command.
9. Continue only when that action exposes a directly related follow-up.

Do not repeat broad repository discovery, redesign completed work, or begin another
acceptance criterion while the recorded failure remains unresolved.

Before ending, update `.loop-state/active.json` with:

- all verified acceptance-criterion IDs;
- the exact remaining failing check and command;
- a one-sentence `next_action` specific enough for a fresh agent;
- the current changed-file list;
- status `in_progress` or `ready_for_validation`.

Preserve the complete schema in `tools/loop-state.example.json`, including all
controller-managed fields.

Status rules:

- Keep the story status synchronized in both `TASKS.json` and the state file.
- Set `ready_for_validation` only after every criterion and focused command passes.
- Leave ordinary defects and failing tests `in_progress`.
- Set `blocked` only for missing authority, unavailable required software, or a
  required user decision that cannot be inferred safely.
- Clear `active_story_id` only when setting `blocked`.
- Never set `done` and never commit from this command.

Recovery rules:

- If the previous pass had a malformed tool call, continue at the recorded action
  with a payload no larger than one quarter of the failed call.
- Preserve working code and make the smallest root-cause repair.
- Never weaken validation merely to advance the story.
