---
description: Show minimal-loop status and the next eligible story
agent: plan
---

Do not modify files.

1. Read `TASKS.json`.
2. Read `.loop-state/active.json` when it exists.
3. Read the Current State section and latest Iteration Log entry in `PROGRESS.md`.
4. Run `git status --short`.
5. Report:
   - active story
   - latest completed story
   - blocked stories and reasons
   - next eligible story
   - dependency chain preventing later stories
   - uncommitted changes
   - verified criteria, failing check, no-progress count, and next action
   - whether the story is awaiting independent validation
   - exact recommended next command, such as `/next-story S02`
6. Treat `TASKS.json` as authoritative when `PROGRESS.md` is stale.
7. Keep the response under 300 words.
