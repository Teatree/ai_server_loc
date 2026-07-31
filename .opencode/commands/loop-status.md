---
description: Show minimal-loop status and the next eligible story
agent: plan
---

Do not modify files.

1. Read `TASKS.json`.
2. Read the Current State section and latest Iteration Log entry in `PROGRESS.md`.
3. Run `git status --short`.
4. Report:
   - active story
   - latest completed story
   - blocked stories and reasons
   - next eligible story
   - dependency chain preventing later stories
   - uncommitted changes
   - exact recommended next command, such as `/next-story S02`
5. Keep the response under 300 words.
