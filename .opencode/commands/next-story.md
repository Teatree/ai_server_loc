---
description: Implement exactly one bounded story and then stop
agent: build
---

Run one minimal-loop iteration for this project.

Optional requested story ID: `$ARGUMENTS`

Follow this procedure exactly:

1. Read `AGENTS.md`.
2. Read `TASKS.json`.
3. Read the Current State section and newest Iteration Log entry in `PROGRESS.md`.
4. Read only architecture sections relevant to the selected story.
5. Run `git status --short`.
6. Select exactly one story:
   - When `$ARGUMENTS` contains a valid story ID, use it if its dependencies are done.
   - Otherwise resume the single `in_progress` story.
   - Otherwise choose the highest-priority `open` story whose dependencies are all `done`.
7. If no story is eligible, explain why and stop without editing.
8. Update `TASKS.json`: set `active_story_id` and set the story to `in_progress`.
9. Inspect only files relevant to that story.
10. Present a plan of no more than eight bullets.
11. Implement only that story.

Hard limits:

- Do not begin a second story.
- Do not repeat the full game specification.
- Do not load the whole repository by default.
- Do not issue a single write/edit tool call larger than roughly 120 lines.
- For large files, create a skeleton and patch focused sections.
- Do not download assets, plugins, packages, or other dependencies.
- Do not edit or commit the Godot executable.
- Preserve unrelated user changes.

Validation:

1. Run `powershell -ExecutionPolicy Bypass -File .\tools\validate.ps1`.
2. Run every validation command listed for the story in `TASKS.json`.
3. Check every acceptance criterion individually.
4. Run `git diff --check`.
5. Review `git diff --stat` and the relevant diff.

Completion:

- Set the story to `done` only when all acceptance criteria are verified.
- Set it to `blocked` when an unresolved issue prevents completion.
- Otherwise leave it `in_progress`.
- Clear `active_story_id` only when the story is `done` or `blocked`.
- Update the short Current State section in `PROGRESS.md`.
- Append one Iteration Log entry using the existing template.
- Update `ARCHITECTURE.md` only for a durable cross-system decision.
- Stage only files belonging to this story.
- Commit with `story(SXX): concise story title` when an isolated commit is safe.
- If unrelated changes prevent a safe commit, do not commit; document the reason.
- End with the completion report required by `AGENTS.md`.
- Stop after this one story.

HARD WRITE LIMIT:

- Maximum 60 lines or approximately 6,000 characters per write/edit call.
- Large files must be built through multiple small edits.
- Never retry a truncated tool payload at the same size.

## Final Commit Ordering

Before creating the final story commit:

1. Update TASKS.json.
2. Update PROGRESS.md.
3. Run all validation.
4. Stage every file belonging to the story.
5. Create the final story commit.

In PROGRESS.md, write:

    **Commit:** included in final story commit; see Git history

Do not insert the commit hash into PROGRESS.md after committing.

Do not modify any tracked file after the final story commit. The final Git
working tree must be clean when the session stops.
