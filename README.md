# Last Shift

2D action-platformer built with Godot 4.x. Survive waves of zombies using firearms, melee, and upgrades across authored arena levels.

## Prerequisites

- Godot 4.7.1+ (project-local `godot.exe` or `Godot_v*-stable_win64.exe` in repo root)
- Windows PowerShell for validation scripts

## Setup

1. Clone or extract the repository.
2. Ensure `godot.exe` is present in the project root (or add Godot to PATH).
3. Open `project.godot` in the Godot editor, or run headless commands from the repo root.

## Running

```powershell
# Import and start headlessly (validation baseline)
powershell -NoProfile -File ./tools/validate.ps1

# Run only tests
powershell -NoProfile -File ./tools/validate.ps1 -TestsOnly
```

## Controls

| Action | Keyboard | Mouse |
|--------|----------|-------|
| Move | A / D or Arrow Left / Right | — |
| Jump | Space or Up Arrow | — |
| Dodge | Left Shift | — |
| Drop through platform | Down Arrow (while on one-way platform) | — |
| Fire | — | Left Click |
| Aim | W / A / S / D | Mouse cursor |
| Reload | R | — |
| Switch weapon | Q | — |
| Debug overlay | R (numpad or Ctrl) | — |

## Project Structure

```
scenes/
  game/           - Level scenes
  player/         - Player entity
  enemies/        - Shambler, Runner, Spitter, Brute
  weapons/        - Weapon scenes (if any)
  ui/             - HUD, pause, death, victory, upgrade selection
  tests/          - Test runner scene
  effects/        - Hit flash, damage numbers

scripts/
  game/           - GameFlow autoload, placeholder level logic
  player/         - Player, MovementController
  enemies/        - Enemy AI scripts
  weapons/        - Weapon framework and concrete weapons
  ui/             - UI screens
  audio/          - AudioManager, AudioEmitter
  feedback/       - Camera shake, hit stop, damage numbers
  save/           - Save schema, sanitizer, manager
  upgrades/       - Upgrade data, manager, runtime, chooser
  director/       - Encounter director
  navigation/     - Platform graph and enemy navigator
  components/     - Checkpoint, pickup, moving platform, hazard
  core/           - HealthComponent, DamageInfo, MovementConfig, WeaponData

resources/
  movement/       - MovementConfig resource
  weapons/        - WeaponData resources (pistol, rifle, shotgun, melee)
  upgrades/       - Upgrade definition resources

tests/
  run_tests.gd    - Deterministic test suite (135 test functions)
tools/
  validate.ps1    - Global validation (import, startup, tests)
  validate-story.ps1 - Story-focused validation
```

## Current State

- Main scene: `res://scenes/title_screen.tscn`
- Validation baseline: import, startup, and 135-test suite pass headlessly
- Known non-blocking warning: test runner leaks RIDs/resources at exit; functionality is unaffected

## Known Limitations

- No authored story content beyond the placeholder arena; levels are test fixtures.
- `placeholder_level.tscn` is the only playable level.
- No external asset pipeline; all visuals are programmatic ColorRect/Sprite2D.
- Save system uses local JSON files; no encryption or cloud sync.
- Debug overlay is minimal and toggled via keyboard only.
- `UpgradeManager` is referenced at `/root/UpgradeManager` but is not currently an autoload or instantiated in the main scene; runtime upgrade application may fail outside test scaffolding.
