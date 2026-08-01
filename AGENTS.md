# LAST SHIFT — Agent Operating Rules

## Project

- Engine: Godot 4.x
- Language: typed GDScript
- Project type: 2D action-platformer with firearms and zombies
- Godot executable: use `.\godot.exe` when present; otherwise use the first matching `.\Godot_v*-stable_win64.exe`
- External assets, plugins, and downloads are prohibited unless the user explicitly approves them
- The repository may already contain partial or broken work. Preserve useful existing work and repair it incrementally.

## Ralph Loop Authority

- `.agents/tasks/prd-last-shift.json` is the story source of truth.
- Ralph alone selects stories and updates PRD status. Agents never edit the PRD.
- `TASKS.json`, `PROGRESS.md`, and `.loop-state/` are legacy records; do not edit
  them during a Ralph run.
- `.ralph/progress.md`, `.ralph/errors.log`, and `.ralph/guardrails.md` persist
  lessons between fresh OpenCode sessions.
- A failed test is unfinished work, not a blocker. Omit the completion signal so
  Ralph reopens the same story for a fresh iteration.
- Only external conditions requiring user authority are blockers.

## Scope Safety

- Every Ralph story declares `allowedPaths` in the PRD.
- Refuse to modify or stage anything outside those paths.
- Preserve pre-existing changes and continue them only when they belong to the
  selected story.

## Core Loop

Work on exactly **one Ralph-selected story per OpenCode session**.

1. Read the selected story, Ralph guardrails, errors, and relevant project files.
2. Run `git status --short` and verify every change belongs to `allowedPaths`.
3. State a plan of no more than eight bullets.
4. Continue useful partial work; do not restart the implementation blindly.
5. Run every `validationCommands` entry and the global quality gates.
6. In normal mode, commit only scoped files using `story(SXX): concise title`.
7. Emit `<promise>COMPLETE</promise>` only when all criteria and checks pass.
8. Otherwise stop normally; Ralph will reopen the story in a fresh session.

## Context Discipline

- Do not load the entire repository unless the active story truly requires it.
- Inspect filenames first, then open only relevant files and short surrounding ranges.
- Do not repeat the complete project specification in responses.
- Treat the Ralph PRD, `.ralph/` logs, Git history, and tests as persistent memory.
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

If validation fails, omit the completion signal and record in `.ralph/errors.log`:

- The exact command
- The relevant error
- What was attempted
- The smallest next action needed

Ralph will reopen the story for a fresh iteration.

## Git Safety

- Run `git status --short` before editing.
- Never discard user changes.
- Never use `git reset --hard`, `git clean -fd`, force push, or destructive checkout commands.
- Do not stage unrelated pre-existing changes.
- Use a commit message in this form:

```text
story(SXX): concise story title
```

- In no-commit mode, do not commit. In normal mode, commit only after validation.
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
