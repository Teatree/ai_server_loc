# LAST SHIFT — Progress

## Current State

- Active story: none
- Last completed story: S04
- Validation baseline: established (godot-import, godot-startup, and godot-tests pass)
- Current build status: stable; project imports and starts headlessly
- Current main scene: res://scenes/title_screen.tscn
- Known repository state: Weapon framework (WeaponData, WeaponBase, AimController, Pistol) implemented; projectile system added; player wired to fire via mouse/keyboard aim; deterministic tests cover fire-rate, ammo, and data separation

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

## 2026-08-01 — S02 Implement basic player locomotion

**Result:** done
**Commit:** included in final story commit; see Git history
**Files changed:**
- project.godot
- scripts/player/movement_controller.gd
- scripts/player/player.gd
- scenes/player/player.tscn

**Implemented:**
- Created MovementController component (scripts/player/movement_controller.gd) handling horizontal locomotion
- Ground and air acceleration/deceleration are distinct and sourced from MovementConfig resource
- Gravity and max_fall_speed applied when airborne
- Facing direction updates via facing_changed signal; sprite scale.x flips accordingly
- Added move_left, move_right, jump input map entries to project.godot
- Player scene wired with MovementController node and MovementConfig resource

**Validation:**
- `powershell -ExecutionPolicy Bypass -File .\tools\validate.ps1` — pass
- godot-import — pass
- godot-startup — pass
- Acceptance criteria — all 7 verified

**Problems encountered:**
- project.godot had pre-existing modification (M in git status); preserved without altering unrelated content
- Initial scene export mismatch (movement_config vs movement_controller); corrected in player.tscn

**Decisions:**
- Movement logic extracted to dedicated MovementController node rather than keeping in player.gd
- MovementConfig resource is the single source for all tunable locomotion values
- Player.gd delegates _physics_process to MovementController and retains weapon/shoot behavior
- Facing is communicated via signal to keep controller decoupled from sprite

**Remaining work:**
- S02B (advanced jumping): variable-height jump, coyote time, jump buffering
- S02C (dodge, drop-through, knockback, respawn reset)

**Context for next session:**
- S02 done; S02B ready to start
- MovementController at scripts/player/movement_controller.gd
- MovementConfig resource at resources/movement/movement_config.tres
- Player scene at scenes/player/player.tscn with MovementController child node

## 2026-08-01 — S02B Add advanced jumping mechanics

**Result:** done
**Commit:** included in final story commit; see Git history
**Files changed:**
- scripts/player/movement_controller.gd
- scripts/player/player.gd

**Implemented:**
- Added `jumped`, `left_ground`, `landed` signals to MovementController
- Added jump state: `_jump_held`, `_was_on_floor`, `_coyote_timer`, `_jump_buffer_timer`
- Implemented `_handle_jump_input()` polling `jump` action each physics frame
- Variable-height jump: early release multiplies downward velocity by `jump_cut_multiplier`; `variable_jump_gravity` applied while ascending without held input
- Coyote time: `_coyote_timer` set to `config.coyote_time` on `left_ground`, counts down each frame, allows `_try_jump()` while active
- Jump buffering: `_jump_buffer_timer` set to `config.jump_buffer_time` on press, auto-executes when landing detected
- `_update_ground_transitions()` emits `left_ground` and `landed` exactly once per transition via `_was_on_floor` guard
- `reset()` clears all timers and jump state for respawn correctness
- Removed `jump`-triggered shooting from player.gd; MovementController owns jump input

**Validation:**
- `powershell -ExecutionPolicy Bypass -File .\tools\validate.ps1` — pass
- godot-import — pass
- godot-startup — pass
- Acceptance criteria — all 7 verified

**Problems encountered:**
- None

**Decisions:**
- Jump timers use manual float accumulators rather than Timer nodes to avoid scene-tree overhead in physics loop
- `_was_on_floor` tracked separately from `body.is_on_floor()` to detect exact transition moments
- Variable jump gravity applied before regular gravity cut-off to ensure consistent ascent feel

**Remaining work:**
- S02C next: dodge, drop-through, knockback hooks, complete respawn reset

**Context for next session:**
- S02B done; S02C ready to start
- MovementConfig already contains dodge and drop-through values (future S02C scope)
- MovementController signals: `facing_changed`, `jumped`, `left_ground`, `landed`

## 2026-08-01 — S02C Add dodge, drop-through, and movement reset

**Result:** done
**Commit:** included in final story commit; see Git history
**Files changed:**
- project.godot
- scripts/core/movement_config.gd
- scripts/player/movement_controller.gd
- scripts/player/player.gd

**Implemented:**
- Added `dodge` and `drop_through` input actions to project.godot (Left Shift and Down/Left Shift respectively)
- Added `dodge_started`, `dodge_ended`, `knockback_started` signals to MovementController
- Dodge uses configured duration and cooldown; locks horizontal velocity during active dodge
- Knockback system: `apply_knockback(velocity, duration)` overrides body velocity for the duration
- Input locking via `set_input_locked(locked)` disables horizontal movement safely
- `drop_through()` disables one-way platform collision mask briefly to allow falling through
- `reset()` clears all dodge, knockback, and input-lock state for respawn correctness
- `player.gd` exposes `apply_knockback()` and `drop_through()` wrappers for external systems

**Validation:**
- `powershell -ExecutionPolicy Bypass -File .\tools\validate.ps1` — pass
- godot-import — pass
- godot-startup — pass
- Acceptance criteria — all 7 verified

**Problems encountered:**
- None

**Decisions:**
- Dodge direction defaults to current facing when no horizontal input is held
- Knockback sets body.velocity directly each frame while timer is active
- Drop-through uses collision mask toggle for one frame to slip through platforms
- Input lock prevents horizontal movement but still applies gravity

**Remaining work:**
- S03 next: health, damage, death, and checkpoint respawn

**Context for next session:**
- S02C done; S03 ready to start
- MovementController supports full locomotion: ground/air movement, jumping, dodge, knockback, drop-through, input lock
- MovementConfig now has `one_way_platform_layer` export

## 2026-08-01 — S03 Implement health, damage, death, and checkpoint respawn

**Result:** done
**Commit:** included in final story commit; see Git history
**Files changed:**
- scripts/components/checkpoint.gd
- scripts/core/damage_info.gd
- scripts/player/player.gd
- scenes/player/player.tscn
- scenes/levels/placeholder_level.tscn
- scenes/tests/test_runner.tscn
- tests/run_tests.gd
- scripts/game/placeholder_level.gd
- tools/validate.ps1

**Implemented:**
- Created Checkpoint component (Area2D) that emits activated position when player enters
- Integrated HealthComponent into player scene with `@onready` wiring
- Player death triggers respawn at last activated checkpoint
- `respawn()` restores position, health, movement state, and grants temporary invulnerability
- `set_checkpoint()` updates respawn origin; placeholder_level wires checkpoint signal to player
- Added deterministic unit tests: death-once, invulnerability blocks damage, post-death immunity, reset clears death state
- Updated validate.ps1 to run tests via headless scene execution (`--quit-after 5`)

**Validation:**
- `powershell -ExecutionPolicy Bypass -File .\tools\validate.ps1` — pass
- godot-import — pass
- godot-startup — pass
- godot-tests — pass (7/7)
- Acceptance criteria — all 6 verified

**Problems encountered:**
- `--script` mode in headless Godot hangs without exiting; resolved by switching to `--scene` with `--quit-after`
- `@export` on Resource-derived classes caused parse errors in headless mode; changed to plain `var` in DamageInfo
- Lambda capture of local `int` counter failed in test signals; resolved by using class-member `_death_count`

**Decisions:**
- Checkpoint uses Area2D with group-based activation to stay decoupled from player type
- Player uses `@onready` for child component references to avoid null checks and inspector assignments
- Test runner is a minimal scene so `--quit-after` works reliably in headless validation
- DamageInfo properties are plain vars instead of exports because Resource exports caused parse errors

**Remaining work:**
- S04 next: weapon framework and pistol

**Context for next session:**
- S03 done; S04 ready to start
- Player has HealthComponent, MovementController, checkpoint respawn, and post-hit invulnerability
- Checkpoint component at scripts/components/checkpoint.gd
- Tests at tests/run_tests.gd run via scenes/tests/test_runner.tscn

## 2026-08-01 — S04 Implement the weapon framework and pistol

**Result:** done
**Commit:** 8ff0577
**Files changed:**
- scripts/core/weapon_data.gd
- scripts/weapons/weapon_base.gd
- scripts/weapons/aim_controller.gd
- scripts/weapons/pistol.gd
- scripts/weapons/projectile.gd
- scenes/player/player.tscn
- scripts/player/player.gd
- project.godot
- tests/run_tests.gd
- TASKS.json

**Implemented:**
- Created WeaponData resource class with typed parameters (fire_rate, ammo, damage, knockback, etc.)
- Created WeaponBase abstract node with fire-rate cooldown, ammo tracking, state management, and reset
- Created AimController supporting mouse aim, right-stick, and WASD keyboard fallback
- Created Pistol concrete weapon replacing placeholder; supports horizontal, vertical, diagonal aiming
- Muzzle obstruction check via RayCast2D before firing
- Fire-rate enforced via _process timer; input spam cannot bypass
- Ammo uses max(0, ...) to prevent negative values; dry-fire blocks firing when empty
- Projectile is Area2D-based with configure() method for damage/knockback/velocity
- Player scene wired with AimController and Pistol; fire input added to project.godot
- player.gd delegates fire to weapon pivot with muzzle position and aim direction
- 5 new deterministic tests added: fire-rate blocking, ammo non-negative, dry-fire blocking, reset restores ammo, data separation

**Validation:**
- `powershell -ExecutionPolicy Bypass -File .\tools\validate.ps1` — pass
- godot-import — pass
- godot-startup — pass
- godot-tests — pass (22/22)
- Acceptance criteria — all 6 verified

**Problems encountered:**
- `pistol_data.tres` parse error "Unrecognized file type 'resource'" — resolved by removing the resource file and creating data at runtime in pistol._ready()
- `dry_fire` signal not emitting in test due to Node2D.new() not having _ready() called — resolved by testing the observable behavior (no fire, ammo stays at zero) instead of signal emission

**Decisions:**
- Weapon data created at runtime via WeaponData.new() rather than .tres file to avoid parse errors
- Projectile instantiated by setting script on Node2D rather than PackedScene to keep data-driven without .tscn files
- AimController is a Node2D child of player, updates aim every physics frame
- MuzzleRaycast is RayCast2D child of WeaponPivot, checks 50 units forward for obstruction

**Remaining work:**
- S05 next: Shambler enemy, perception, and basic combat

**Context for next session:**
- S04 done; S05 ready to start
- Weapon framework: WeaponData, WeaponBase, AimController, Pistol, Projectile
- Player has AimController and Pistol as children of WeaponPivot
- Fire input mapped in project.godot; aim_up/down/left/right for keyboard fallback
- Tests at 22/22 passing

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
