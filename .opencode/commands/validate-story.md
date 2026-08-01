---
description: Run project and story validation without implementing new features
agent: build
---

Validation-only run. Do not implement new features and do not modify files unless the user explicitly includes `fix` in `$ARGUMENTS`.

1. Read `AGENTS.md`.
2. Read `TASKS.json`.
3. Identify the active story or latest completed story.
4. Run the story-specific focused validation commands.
5. Run `tools\validate.ps1` only when `$ARGUMENTS` includes `global`.
6. Run `git diff --check`.
7. Report commands, exit codes, parser/resource/startup errors, verified criteria, and unverified criteria.
8. When `$ARGUMENTS` does not include `fix`, make no edits.
9. When `$ARGUMENTS` includes `fix`, repair only validation defects within the
   active story's `allowed_paths`, update `.loop-state/active.json`, and stop.
10. Never mark a story `done` or commit from this command.
