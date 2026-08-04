extends Node

const CURRENT_VERSION: int = 1
const MIN_SUPPORTED_VERSION: int = 1

const FIELD_VERSION: StringName = &"version"
const FIELD_CHECKPOINT: StringName = &"checkpoint"
const FIELD_HEALTH_CURRENT: StringName = &"health_current"
const FIELD_HEALTH_MAX: StringName = &"health_max"
const FIELD_WEAPONS: StringName = &"weapons"
const FIELD_UPGRADES: StringName = &"upgrades"
const FIELD_ENCOUNTER_COMPLETED: StringName = &"encounter_completed"
const FIELD_SESSION_SEED: StringName = &"session_seed"

const FIELD_WEAPON_ID: StringName = &"weapon_id"
const FIELD_CURRENT_AMMO: StringName = &"current_ammo"
const FIELD_RESERVE_AMMO: StringName = &"reserve_ammo"
const FIELD_UPGRADE_ID: StringName = &"upgrade_id"
const FIELD_UPGRADE_STACKS: StringName = &"upgrade_stacks"

const DEFAULT_CHECKPOINT: Vector2 = Vector2(200, 600)
const DEFAULT_HEALTH_CURRENT: float = 100.0
const DEFAULT_HEALTH_MAX: float = 100.0
const DEFAULT_ENCOUNTER_COMPLETED: bool = false
const DEFAULT_SESSION_SEED: int = 0

static func create_empty() -> Dictionary:
	var data: Dictionary = {}
	data[FIELD_VERSION] = CURRENT_VERSION
	data[FIELD_CHECKPOINT] = DEFAULT_CHECKPOINT
	data[FIELD_HEALTH_CURRENT] = DEFAULT_HEALTH_CURRENT
	data[FIELD_HEALTH_MAX] = DEFAULT_HEALTH_MAX
	data[FIELD_WEAPONS] = []
	data[FIELD_UPGRADES] = []
	data[FIELD_ENCOUNTER_COMPLETED] = DEFAULT_ENCOUNTER_COMPLETED
	data[FIELD_SESSION_SEED] = DEFAULT_SESSION_SEED
	return data

static func is_supported_version(data: Dictionary) -> bool:
	if not data.has(FIELD_VERSION):
		return false
	var version: int = data[FIELD_VERSION]
	return version >= MIN_SUPPORTED_VERSION and version <= CURRENT_VERSION

static func weapon_entry(weapon_id: StringName, current_ammo: int, reserve_ammo: int) -> Dictionary:
	var entry: Dictionary = {}
	entry[FIELD_WEAPON_ID] = weapon_id
	entry[FIELD_CURRENT_AMMO] = current_ammo
	entry[FIELD_RESERVE_AMMO] = reserve_ammo
	return entry

static func upgrade_entry(upgrade_id: StringName, stacks: int) -> Dictionary:
	var entry: Dictionary = {}
	entry[FIELD_UPGRADE_ID] = upgrade_id
	entry[FIELD_UPGRADE_STACKS] = stacks
	return entry
