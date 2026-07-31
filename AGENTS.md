# LAST SHIFT — Agent Operating Rules

## Project

- Engine: Godot 4.x
- Language: typed GDScript
- Project type: 2D action-platformer with firearms and zombies
- Godot executable: use `.\godot.exe` when present; otherwise use the first matching `.\Godot_v*-stable_win64.exe`
- External assets, plugins, and downloads are prohibited unless the user explicitly approves them
- The repository may already contain partial or broken work. Preserve useful existing work and repair it incrementally.

## Core Loop

Work on exactly **one story per OpenCode session**.

At the start of every `/next-story` run:

1. Read `AGENTS.md`.
2. Read `TASKS.json`.
3. Read the current-state section and latest log entry in `PROGRESS.md`.
4. Read only the relevant parts of `ARCHITECTURE.md`.
5. Run `git status --short`.
6. Select one story:
   - Use the story ID supplied as `$ARGUMENTS`, when present.
   - Otherwise select the highest-priority `open` story whose dependencies are all `done`.
   - Resume an `in_progress` story instead of starting another one.
7. Mark the selected story `in_progress` before implementation.
8. State a plan of no more than eight bullets.

At the end of the run:

1. Execute the global validation script.
2. Execute every story-specific validation command.
3. Compare the result against every acceptance criterion.
4. Update `TASKS.json`.
5. Update `PROGRESS.md`.
6. Update `ARCHITECTURE.md` only when an architectural decision actually changed.
7. Review `git diff --check` and `git diff --stat`.
8. Commit only the files belonging to this story, when safe.
9. Stop. Do not begin another story in the same session.

## Context Discipline

- Do not load the entire repository unless the active story truly requires it.
- Inspect filenames first, then open only relevant files and short surrounding ranges.
- Do not repeat the complete project specification in responses.
- Treat `TASKS.json`, `PROGRESS.md`, Git history, and tests as persistent memory.
- Prefer a new OpenCode session over continuing after the context becomes cluttered.
- Never invoke compaction as part of this workflow. End the session instead.

## File-Write Discipline

The local model has previously produced truncated JSON tool calls. Therefore:

- Limit a single write or edit operation to approximately 120 lines.
- For a file expected to exceed 180 lines, create a small skeleton first and add focused sections in later edits.
- Do not replace an existing large file when a targeted edit is sufficient.
- Keep gameplay scripts cohesive; split scripts that approach 300 lines unless there is a strong reason not to.
- Never embed binary data or generated assets in a tool call.
- Do not edit, rename, delete, or commit the Godot executable.
- Do not modify `.godot/`, imported cache files, or generated logs.

## Implementation Standards

- Use typed variables, parameters, and return values.
- Prefer composition and small components over deep inheritance.
- Keep gameplay constants in resources or centralized configuration.
- Use signals or explicit interfaces for cross-system communication.
- Avoid repeated scene-tree searches in frame callbacks.
- Disconnect signals and release transient nodes correctly.
- Make deterministic gameplay logic testable without rendering when practical.
- Do not leave placeholder methods that falsely imply a feature is complete.
- Do not add external dependencies to solve a task that can be implemented directly.

## Validation

The global command is:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate.ps1
```

A story cannot be marked `done` when:

- Godot import fails.
- The project reports parse or resource-loading errors.
- The main scene cannot start headlessly.
- A story-specific validation command fails.
- Any acceptance criterion is unverified.
- The implementation contains obvious placeholders for required behavior.

If validation cannot be completed, mark the story `blocked` and record:

- The exact command
- The relevant error
- What was attempted
- The smallest next action needed

## Git Safety

- Run `git status --short` before editing.
- Never discard user changes.
- Never use `git reset --hard`, `git clean -fd`, force push, or destructive checkout commands.
- Do not stage unrelated pre-existing changes.
- Use a commit message in this form:

```text
story(SXX): concise story title
```

- If unrelated changes prevent a clean isolated commit, leave the story uncommitted and explain why in `PROGRESS.md`.

## Completion Response

End with a compact report containing:

- Story ID and title
- Files changed
- Validation performed
- Acceptance criteria result
- Commit hash, or why no commit was made
- Remaining risks
- Explicit statement that the session is stopping

## Hard Tool-Call Size Limits

These limits are mandatory because large write calls have previously produced
truncated JSON.

- Never write or replace more than 60 lines in one tool call.
- Never send more than approximately 6,000 characters in one write or edit.
- Files expected to exceed 100 lines must be created incrementally.
- First create a minimal skeleton.
- Add methods in focused groups using separate edit calls.
- Prefer targeted edits over replacing complete files.
- After any JSON parse error or unterminated-string error, do not retry the
  same payload. Reduce the next operation to one quarter of the previous size.
- Record the failed operation and continuation point in PROGRESS.md.
