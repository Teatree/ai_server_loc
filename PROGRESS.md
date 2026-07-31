# LAST SHIFT — Progress

## Current State

- Active story: none
- Last completed story: S01
- Validation baseline: established (godot-import and godot-startup pass)
- Current build status: stable; project imports and starts headlessly
- Current main scene: res://scenes/title_screen.tscn
- Known repository state: GameFlow autoload manages scene transitions; placeholder level with basic player exists; pause menu implemented

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

## 2026-08-01 00:17 — S00 Audit and stabilize the current repository

**Result:** done
**Commit:** 0b5d0bf
**Files changed:**
- scenes/title_screen.tscn
- scenes/main_game.tscn
- scripts/ui/title_screen.gd
- PROGRESS.md

**Implemented:**
- Created missing scenes/ directory
- Created minimal title_screen.tscn (Control-based UI with title label and start button)
- Created placeholder main_game.tscn for New Game flow
- Created scripts/ui/title_screen.gd wired to button press signal
- Updated PROGRESS.md Current State section

**Validation:**
- `powershell -ExecutionPolicy Bypass -File .\tools\validate.ps1` — pass
- Repository structure documented — done
- project.godot with valid main scene — done
- Broken references identified — done (scenes/ missing, now resolved)
- Godot executable excluded from Git — done (.gitignore already covers it)
- No unrelated working code discarded — done

**Problems encountered:**
- scenes/ directory did not exist despite project.godot referencing res://scenes/title_screen.tscn as main_scene
- scripts/ui/ directory did not exist for title screen script

**Decisions:**
- Created minimal title_screen.tscn as Control node with ColorRect background, Label, and Button
- Created placeholder main_game.tscn (Node2D) to satisfy New Game transition target; full game flow will be implemented in S01

**Remaining work:**
- Wire New Game button to transition to main_game.tscn (emits signal; actual transition is S01 scope)

**Context for next session:**
- S00 is in_progress; core scripts exist at scripts/core/ (movement_config, health_component, damage_info)
- scenes/ now contains title_screen.tscn and placeholder main_game.tscn
- Validation script exists at tools/validate.ps1 and uses godot.exe or Godot_v*-stable_win64.exe
- project.godot references scenes/title_screen.tscn as main scene; 1280x720 viewport

## 2026-08-01 — S01 Create the launchable project shell and title flow

**Result:** done
**Commit:** 544adb8
**Files changed:**
- project.godot
- scenes/title_screen.tscn
- scenes/levels/placeholder_level.tscn
- scenes/player/player.tscn
- scripts/game/game_flow.gd
- scripts/game/placeholder_level.gd
- scripts/player/player.gd
- scripts/ui/title_screen.gd
- scripts/ui/pause_menu.gd
- scripts/weapons/pistol_placeholder.gd
- scripts/weapons/projectile_placeholder.gd
- TASKS.json
- PROGRESS.md

**Implemented:**
- Created GameFlow autoload singleton managing title-to-level-to-title transitions with pause and return-to-title
- Wired title_screen.gd buttons directly to GameFlow.go_to_level and quit
- Created placeholder_level.tscn with ground, player spawn marker, and player instance
- Created player scene with CharacterBody2D, Sprite2D, collision, and weapon pivot
- Created placeholder pistol with cooldown and projectile spawning
- Created pause menu overlay (Resume and Return to Title buttons)
- Placeholder level wired to GameFlow.request_return_to_title via ReturnToTitle button
- Keyboard (WASD/arrows) movement and mouse aim for player

**Validation:**
- `powershell -ExecutionPolicy Bypass -File .\tools\validate.ps1` — pass
- godot-import pass — verified
- godot-startup pass — verified

**Problems encountered:**
- Initial title_screen.gd type error assigning VBoxContainer to Button variable; fixed by using correct types and get_node()
- run-story-loop.ps1 has unrelated pre-existing modifications; excluded from commit

**Decisions:**
- GameFlow is the single autoload responsible for all scene transitions and pause state
- Placeholder level uses CharacterBody2D with direct input for immediate playability
- Pause menu created dynamically as overlay to avoid duplicate node issues

**Remaining work:**
- None for S01; next story is S02 (player movement refinement)

**Context for next session:**
- S01 done; S02 ready to start
- GameFlow autoload at scripts/game/game_flow.gd
- Player scene at scenes/player/player.tscn with placeholder weapon
- Placeholder level at scenes/levels/placeholder_level.tscn
- run-story-loop.ps1 has unrelated pre-existing modifications (not committed as part of S01)

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
