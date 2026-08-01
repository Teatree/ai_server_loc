# LAST SHIFT — Ralph Worker Rules

- Ralph's selected PRD story is the only work scope for this iteration.
- Ralph owns PRD status. Never edit the PRD, `TASKS.json`, or `.loop-state/`.
- Do not read the full PRD or legacy task files; use the injected selected story.
- Preserve useful existing work and never discard user changes.
- Change only paths listed under the selected story's Allowed Paths.
- Do not modify the Godot executable, `.godot/`, imports, or generated logs.
- Do not download assets, plugins, packages, or other dependencies.
- Use typed GDScript and small cohesive components.
- Never weaken tests or acceptance criteria to obtain a pass.
- Limit each write/edit tool call to 60 lines and about 6,000 characters.
- After malformed tool output, retry at one quarter of the payload size.
- Run every selected-story validation command and every global quality gate.
- A failed test is ordinary unfinished work: diagnose it and omit COMPLETE.
- Only emit `<promise>COMPLETE</promise>` when all criteria and checks pass.
- Never start a second story in the same OpenCode session.
- In no-commit mode, leave all work uncommitted.
- In normal mode, commit only selected-story files after validation.
