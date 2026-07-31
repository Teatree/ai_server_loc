---
description: Review one story and its diff without editing files
agent: plan
---

Perform a review-only pass. Do not modify files.

Requested story ID: `$ARGUMENTS`

1. Read `AGENTS.md`.
2. Read the requested story in `TASKS.json`; when no ID is supplied, use `active_story_id` or the latest completed story.
3. Read the latest relevant entry in `PROGRESS.md`.
4. Inspect `git status --short`, `git diff --stat`, and the relevant diff.
5. Inspect only source files needed to understand the change.
6. Compare the implementation against every acceptance criterion.
7. Look specifically for:
   - lifecycle and duplicate-signal defects
   - invalid node paths or resource references
   - state that survives death or scene reload incorrectly
   - tool-generated truncation or malformed files
   - untyped or over-coupled GDScript
   - missing edge cases
   - tests that confirm the implementation rather than intended behavior
8. Report findings by severity: blocker, high, medium, low.
9. For every finding, give the exact file, symbol or line range, failure mode, and smallest safe repair.
10. Do not claim an issue without evidence.
11. Do not edit, stage, or commit anything.
