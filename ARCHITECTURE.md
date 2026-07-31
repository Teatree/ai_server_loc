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
  components/
  game/
  player/
  enemies/
  weapons/
  ui/
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

Enemy archetypes configure and compose these capabilities rather than duplicating a giant base script.

### Perception and Noise

A scoped noise-event service publishes short-lived events. Receivers unsubscribe or become inactive on death and scene exit. Perception combines sight, line of sight, noise, and last-known position.

### Platform Navigation

Use a pragmatic authored graph or hybrid system with platform nodes, jump/drop links, reachability classification, and stuck recovery. Do not attempt a general-purpose platformer pathfinder before a smaller authored approach is validated.

### Encounter Director

The director owns threat budget and spawn selection, not individual enemy behavior. It consumes player condition, recent combat, encounter phase, spawn visibility, and living-enemy count. Seeded random decisions must be reproducible.

### Upgrades

Upgrade definitions are data. A runtime modifier service applies validated stacks and exclusions exactly once. Save data stores upgrade identifiers and stack counts, not serialized runtime objects.

### Save System

Save data is versioned and validated at the boundary. Loading must tolerate missing, corrupt, old, unknown, and invalid data. Scene nodes reconstruct runtime state from sanitized data.

### UI and Feedback

UI observes gameplay state through signals or query interfaces. Camera shake, hit stop, transient effects, and audio emitters are centralized so concurrent events compose predictably.

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
