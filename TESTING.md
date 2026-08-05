# Testing

## Overview

The test suite is deterministic GDScript executed headlessly via a dedicated test runner scene. No external test framework is required beyond the Godot executable.

## Test Runner

- Scene: `scenes/tests/test_runner.tscn`
- Script: `tests/run_tests.gd`
- Execution: `godot.exe --headless --scene res://scenes/tests/test_runner.tscn --quit-after 5`

Tests run in `_ready()` and print `PASS:` or `FAIL:` lines. A summary is printed on completion. Exit code is 0 when all tests pass, non-zero otherwise.

## Running Tests

```powershell
# Full validation (import + startup + tests)
powershell -NoProfile -File ./tools/validate.ps1

# Tests only
powershell -NoProfile -File ./tools/validate.ps1 -TestsOnly

# Story-specific validation
powershell -NoProfile -File ./tools/validate-story.ps1 -StoryId S13B
```

## Current Coverage

135 test functions covering:

- **Health and Damage** (4): death emits once, invulnerability timing, post-death immunity, reset clears death
- **Weapons - Core** (5): fire-rate cooldown, ammo non-negative, dry-fire blocking, reset restores ammo, data separation
- **Shotgun** (3): pellet count and spread, bounded damage/knockback/ammo/cooldown, empty magazine behavior
- **Automatic Rifle** (3): held-fire cadence, recoil accumulate/recover, reload/switching preserve ammo
- **Shambler Enemy** (10): idle start, noise investigation, position expiry, dead ignores noise, dies once, reset clears death, sight checks (visible, blocked, FOV), gunfire triggers investigation
- **Shambler Integration** (5): pursuit movement, telegraph before attack, damages player, pistol kills shambler
- **Level / Arena** (8): exit zone, platform physics, platform visuals, checkpoint respawn, entry-to-exit route, moving platform, hazard damage, pickup apply-once
- **Level Integration** (4): spawn markers categorized, side route rejoin, integrated playability, enemy spawn markers
- **Weapon Inventory** (4): reload bounded ammo transfer, switching blocks during reload, switching blocks during cooldown, state correct after respawn
- **Melee** (5): range/cooldown, cannot damage repeatedly per swing, interrupts weak enemy without corrupting death, signal emitted on hit, all weapons expose consistent signals
- **Navigation Graph** (8): reachable/jump/drop/blocked classification, traverses jump/drop links, stuck recovery, enemy archetypes support graph
- **Brute Enemy** (7): idle start, telegraph pulse, stagger resistance, heavy damage, dies once via shared contract, reset clears state, crowd separation
- **Director** (11): deterministic selection, threat budget, living cap, spawn distance rejection, pressure escalation phases, victory emission and reset, level restart clears state
- **Upgrades** (13): apply and survive respawn, stack limits, mutual exclusion, chooser reproducibility, excluded/maxed filtering, description exposure, UI display, selection apply-once
- **Save System** (16): schema version and identifiers, missing fields, corrupt repair, unknown field stripping, invalid version handling, old version migration, weapon/upgrade entry validation, manager file round-trip, clear save, lifecycle cycles, checkpoint+restart reconstruct
- **Feedback** (8): shake combine within limits, hit stop reference counting, transient effects release, transient sounds pool, music/SFX/UI volume stability, scene change audio ownership
- **UI** (2): upgrade UI freed after selection, upgrade applies once

## Known Test Limitations

- Headless test runner leaks RIDs and ObjectDB instances at exit (non-fatal; functionality verified).
- Tests instantiate nodes without full scene-tree lifecycle; behavior is validated via direct method calls and `_process()` advances.
- No integration test for title screen or full game flow; those are exercised by `godot-startup` only.
