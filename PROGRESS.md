# LAST SHIFT — Progress

## Current State

- Active story: none
- Last completed story: none
- Validation baseline: not established
- Current build status: unknown
- Current main scene: unknown
- Known repository state: partial files may exist from an interrupted large agent run

This section should remain short. Update it at the end of each story.

## Stable Decisions

- Use one fresh OpenCode session per story.
- Persist state in `TASKS.json`, this file, architecture documentation, tests, and Git history.
- Use typed GDScript and Godot 4.x.
- Use project-local Godot executable when available.
- No external assets, plugins, or dependencies without explicit user approval.
- Keep the server context at its current practical size; solve context pressure by reducing story scope.
- Avoid large single tool writes because they previously caused truncated JSON calls.

## Known Risks

- Existing files may be incomplete or internally inconsistent.
- Large Godot scene or script generation can exceed reliable tool-call size.
- Headless startup may expose errors that import alone does not catch.
- The local model can overrun context if multiple stories are attempted in one session.
- Automated tests may need to be introduced incrementally as deterministic logic is isolated.

## Iteration Log

Append one entry per story attempt. Do not rewrite or summarize away prior entries.

### Template

```markdown
## YYYY-MM-DD HH:MM — SXX Story Title

**Result:** done | blocked | partial
**Commit:** hash | not committed
**Files changed:**
- path

**Implemented:**
- concise result

**Validation:**
- `command` — pass/fail
- acceptance criterion — verified/not verified

**Problems encountered:**
- exact issue

**Decisions:**
- durable technical decision

**Remaining work:**
- smallest next action

**Context for next session:**
- only facts the next fresh session must know
```
