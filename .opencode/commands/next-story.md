---
description: Start exactly one bounded story and prepare it for independent validation
agent: build
---

Start one story. Requested story ID: `$ARGUMENTS`.

1. Read `AGENTS.md`, `TASKS.json`, and `.loop-state/active.json` when present.
2. Run `git status --short`.
3. Select only the requested eligible story. Do not begin another story.
4. Confirm every changed file matches the story's `allowed_paths`.
5. Set `active_story_id` and change the story from `open` to `in_progress`.
6. Read only the story, its dependencies, relevant architecture, and scoped files.
7. State a plan of no more than eight bullets.
8. Implement only this story using typed GDScript and small edits.
9. Run only the focused commands listed in the story's `validation` field.
10. Check each acceptance criterion by ID.

Before ending, write `.loop-state/active.json` with:

- story ID and `in_progress` or `ready_for_validation` status;
- verified acceptance-criterion IDs;
- exact failing check, command, and error;
- changed files;
- one smallest concrete `next_action`.

Preserve every field from `tools/loop-state.example.json`; do not remove or rename
controller-managed fields such as `pass`, `transient_issue`, or
`consecutive_no_progress`.

Completion rules:

- Keep the story status synchronized in both `TASKS.json` and the state file.
- Use `ready_for_validation` only when every criterion is verified and focused checks pass.
- Leave the story `in_progress` for any ordinary implementation or test failure.
- Use `blocked` only for an external condition the agent cannot resolve.
- Clear `active_story_id` only when setting `blocked`.
- Never set the story to `done` in this command.
- Never commit in this command; independent validation and `/finalize-story` come next.
- Do not update the completed-story section of `PROGRESS.md` yet.

Hard limits:

- Maximum 60 lines or about 6,000 characters per write/edit call.
- After malformed tool output, retry at one quarter of the payload size.
- Do not download dependencies or touch executables, caches, generated logs, or
  files outside `allowed_paths`.
- Do not weaken tests or acceptance criteria to obtain a pass.
