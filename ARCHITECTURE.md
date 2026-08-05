# LAST SHIFT — Architecture

This document records durable architecture. Keep it concise. Do not turn it into a session transcript.

## Intended Repository Layout

```text
project.godot
scenes/
  game/
  levels/
  player/
  enemies/
  weapons/
  ui/
scripts/
  components
  game
  player
  enemies
  weapons
  ui
  save
resources/
  movement/
  weapons/
  enemies/
  upgrades/
tests/
tools/
```

The exact structure may evolve. Update this document only when the actual project diverges for a justified reason.

## System Boundaries

### Game Flow

Owns title, new game, continue, level lifecycle, pause, victory, and return-to-title. It must prevent duplicate autoload-like state and duplicate signal connections across repeated scene changes.

### Player

The player scene coordinates focused components rather than owning every system:

- Movement controller
- Aim controller
- Weapon inventory
- Health component
- Damage receiver
- Checkpoint/respawn integration
- Upgrade modifier access

### Weapons

Weapons are data-driven. Runtime weapon instances consume weapon data and expose a stable interface for fire, reload, equip, ammunition, state, modifiers, and feedback. Fire-rate and reload authority belong to the weapon runtime, not the input layer.

### Damage and Health

Damage is passed as a typed data object containing amount, type, source, position, direction, knockback, and optional metadata. Health owns invulnerability and one-shot death semantics.

### Enemies

Each enemy uses an explicit state machine. Shared capabilities should be components:

- Perception
- Health/damage
- Locomotion
- Platform navigation
- Attack execution
- Stagger handling

Implemented archetypes:

- **Shambler** (`scripts/enemies/shambler.gd`) — balanced melee chaser with sight/noise perception, investigate/chase/attack_telegraph/dead states.
- **Runner** (`scripts/enemies/runner.gd`) — fast lunge attacker with visible telegraph flash.
- **Spitter** (`scripts/enemies/spitter.gd`) — ranged projectile attacker with cooldown-based behavior.
- **Brute** (`scripts/enemies/brute.gd`) — heavy tank with stagger resistance, heavy damage, and crowd separation.

Enemy archetypes configure and compose these capabilities rather than duplicating a giant base script.

### Perception and Noise

A scoped noise-event service publishes short-lived events. Receivers unsubscribe or become inactive on death and scene exit. Perception combines sight, line of sight, noise, and last-known position.

### Platform Navigation

`scripts/navigation/platform_graph.gd` defines an authored graph of platform nodes and jump/drop links. `scripts/navigation/enemy_navigator.gd` consumes the graph to classify reachability (jump, drop, blocked, unreachable) and executes traversal with bounded stuck recovery. Use this pragmatic authored approach; do not attempt a general-purpose platformer pathfinder before this hybrid system is validated across all enemy archetypes.

### Encounter Director

The director owns threat budget and spawn selection, not individual enemy behavior. It consumes player condition, recent combat, encounter phase, spawn visibility, and living-enemy count. Seeded random decisions must be reproducible.

### Upgrades

Upgrade definitions are data (`resources/upgrades/*.tres`). `scripts/upgrades/upgrade_manager.gd` owns the active upgrade graph, stack limits, and mutual exclusion rules. `scripts/upgrades/upgrade_runtime.gd` is attached to the player and exposes `apply_upgrade()` for pickup/level events. `scripts/upgrades/upgrade_chooser.gd` presents a fixed-seed random selection of three valid choices when an upgrade is earned. Save data stores upgrade identifiers and stack counts, not serialized runtime objects.

### Save System

Save data is versioned and validated at the boundary. `scripts/save/save_schema.gd` declares the canonical field set and current version. `scripts/save/save_sanitizer.gd` enforces type constraints, strips unknown fields, fills defaults for missing data, repairs corrupt values, and applies deterministic migrations from older schema versions. `scripts/save/save_manager.gd` owns file I/O, coordinates with `GameFlow` for lifecycle events (load on continue, save on exit), and injects sanitized data into runtime services. Scene nodes reconstruct runtime state from sanitized data using stable StringName identifiers; no serialized runtime objects are persisted.

### UI and Feedback

UI observes gameplay state through signals or query interfaces. Camera shake, hit stop, transient effects, and audio emitters are centralized so concurrent events compose predictably.

#### Feedback System

`scripts/feedback/feedback_manager.gd` centralizes camera shake, hit stop, and transient visual effects. It is instantiated by GameFlow and discovers the active Camera2D, creating one if needed. Camera shake requests combine additively up to a configured intensity cap. Hit stop uses reference counting to restore `Engine.time_scale` exactly once when all concurrent stops expire. Transient effects are lightweight scene instances that queue_free themselves and disconnect signals on tree exit.

### Audio System

`scripts/audio/audio_manager.gd` centralizes audio playback with bounded object pooling. Transient SFX and UI sounds reuse `AudioEmitter` nodes from a capped pool; excess temporary emitters are freed after playback. Music uses a dedicated persistent emitter that survives scene changes. The manager creates `Music`, `SFX`, and `UI` audio buses at runtime and exposes stable linear-volume controls for each category. On scene change, SFX and UI emitters are stopped while music is retained, matching explicit ownership semantics.

## Dependency Direction

```text
data/resources
    ↓
small reusable components
    ↓
entities and gameplay systems
    ↓
scene/game flow
    ↓
UI presentation
```

Avoid gameplay code depending directly on concrete UI nodes.

## Global State Policy

Use the fewest autoloads possible. Suitable global responsibilities may include game/session flow, save service, and audio service. Enemy AI, weapons, player movement, and encounter-local state should not be global.

## Determinism and Testing

Extract deterministic logic from scene-bound behavior where possible:

- Ammunition and reload transitions
- Health/death rules
- Upgrade selection and stack limits
- Director budgets and spawn filtering
- Noise expiration
- Enemy state-transition predicates
- Coyote-time and jump-buffer boundaries

## Architecture Decision Log

### ADR-001 — One story per fresh context

**Decision:** Every implementation iteration handles one bounded story and terminates after validation and state update.

**Reason:** The local 24K context is sufficient for focused work but degraded during a monolithic implementation attempt.
