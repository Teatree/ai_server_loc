const SaveSchema = preload("res://scripts/save/save_schema.gd")

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
const FIELD_WEAPON_MAX_AMMO: StringName = &"max_ammo"
const FIELD_UPGRADE_ID: StringName = &"upgrade_id"
const FIELD_UPGRADE_STACKS: StringName = &"upgrade_stacks"

const CURRENT_VERSION: int = 1
const MIN_SUPPORTED_VERSION: int = 1

const DEFAULT_CHECKPOINT: Vector2 = Vector2(200, 600)
const DEFAULT_HEALTH_CURRENT: float = 100.0
const DEFAULT_HEALTH_MAX: float = 100.0
const DEFAULT_ENCOUNTER_COMPLETED: bool = false
const DEFAULT_SESSION_SEED: int = 0

const UNKNOWN_FIELD_PREFIX: String = "_unknown_"


static func sanitize(raw: Dictionary) -> Dictionary:
	if raw == null or raw.is_empty():
		return SaveSchema.create_empty()
	var data: Dictionary = raw.duplicate(true)
	if not data.has(FIELD_VERSION) or not _is_valid_version(data[FIELD_VERSION]):
		return SaveSchema.create_empty()
	var version: int = int(data[FIELD_VERSION])
	if version < CURRENT_VERSION:
		data = _migrate(data, version)
	_strip_unknown_fields(data)
	_ensure_required_fields(data)
	_repair_corrupt_fields(data)
	data[FIELD_VERSION] = CURRENT_VERSION
	return data


static func _is_valid_version(value) -> bool:
	if not _is_numeric(value):
		return false
	var v: int = int(value)
	return v >= MIN_SUPPORTED_VERSION and v <= CURRENT_VERSION


static func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	for v in range(from_version, CURRENT_VERSION):
		result = _apply_migration(result, v)
	return result


static func _apply_migration(data: Dictionary, from_version: int) -> Dictionary:
	match from_version:
		0:
			var migrated: Dictionary = data.duplicate(true)
			migrated[FIELD_CHECKPOINT] = DEFAULT_CHECKPOINT
			migrated[FIELD_HEALTH_CURRENT] = DEFAULT_HEALTH_CURRENT
			migrated[FIELD_HEALTH_MAX] = DEFAULT_HEALTH_MAX
			migrated[FIELD_WEAPONS] = []
			migrated[FIELD_UPGRADES] = []
			migrated[FIELD_ENCOUNTER_COMPLETED] = DEFAULT_ENCOUNTER_COMPLETED
			migrated[FIELD_SESSION_SEED] = DEFAULT_SESSION_SEED
			return migrated
		_:
			return data


static func _strip_unknown_fields(data: Dictionary) -> void:
	var known: Array = [
		FIELD_VERSION,
		FIELD_CHECKPOINT,
		FIELD_HEALTH_CURRENT,
		FIELD_HEALTH_MAX,
		FIELD_WEAPONS,
		FIELD_UPGRADES,
		FIELD_ENCOUNTER_COMPLETED,
		FIELD_SESSION_SEED,
		FIELD_WEAPON_ID,
		FIELD_CURRENT_AMMO,
		FIELD_RESERVE_AMMO,
		FIELD_WEAPON_MAX_AMMO,
		"max_ammo",
		FIELD_UPGRADE_ID,
		FIELD_UPGRADE_STACKS,
	]
	var to_remove: Array = []
	for key in data.keys():
		if not key in known:
			to_remove.append(key)
	for key in to_remove:
		data.erase(key)


static func _ensure_required_fields(data: Dictionary) -> void:
	if not data.has(FIELD_CHECKPOINT) or not data[FIELD_CHECKPOINT] is Vector2:
		data[FIELD_CHECKPOINT] = DEFAULT_CHECKPOINT
	if not data.has(FIELD_HEALTH_CURRENT) or not _is_float(data[FIELD_HEALTH_CURRENT]):
		data[FIELD_HEALTH_CURRENT] = DEFAULT_HEALTH_CURRENT
	if not data.has(FIELD_HEALTH_MAX) or not _is_float(data[FIELD_HEALTH_MAX]):
		data[FIELD_HEALTH_MAX] = DEFAULT_HEALTH_MAX
	if not data.has(FIELD_WEAPONS) or not data[FIELD_WEAPONS] is Array:
		data[FIELD_WEAPONS] = []
	if not data.has(FIELD_UPGRADES) or not data[FIELD_UPGRADES] is Array:
		data[FIELD_UPGRADES] = []
	if not data.has(FIELD_ENCOUNTER_COMPLETED) or not _is_bool(data[FIELD_ENCOUNTER_COMPLETED]):
		data[FIELD_ENCOUNTER_COMPLETED] = DEFAULT_ENCOUNTER_COMPLETED
	if not data.has(FIELD_SESSION_SEED) or not _is_int(data[FIELD_SESSION_SEED]):
		data[FIELD_SESSION_SEED] = DEFAULT_SESSION_SEED
	_sanitize_weapon_entries(data[FIELD_WEAPONS])
	_sanitize_upgrade_entries(data[FIELD_UPGRADES])


static func _repair_corrupt_fields(data: Dictionary) -> void:
	if data[FIELD_HEALTH_CURRENT] is float and data[FIELD_HEALTH_MAX] is float:
		if data[FIELD_HEALTH_CURRENT] > data[FIELD_HEALTH_MAX]:
			data[FIELD_HEALTH_CURRENT] = data[FIELD_HEALTH_MAX]
		if data[FIELD_HEALTH_CURRENT] < 0.0:
			data[FIELD_HEALTH_CURRENT] = 0.0
	if data[FIELD_HEALTH_MAX] is float and data[FIELD_HEALTH_MAX] <= 0.0:
		data[FIELD_HEALTH_MAX] = DEFAULT_HEALTH_MAX
	_repair_weapon_entries(data[FIELD_WEAPONS])
	_repair_upgrade_entries(data[FIELD_UPGRADES])


static func _sanitize_weapon_entries(weapons: Array) -> void:
	var repaired: Array = []
	for entry in weapons:
		if not entry is Dictionary:
			continue
		var we: Dictionary = {}
		if entry.has(FIELD_WEAPON_ID) and entry[FIELD_WEAPON_ID] is StringName:
			we[FIELD_WEAPON_ID] = entry[FIELD_WEAPON_ID]
		elif entry.has(FIELD_WEAPON_ID) and entry[FIELD_WEAPON_ID] is String:
			we[FIELD_WEAPON_ID] = StringName(entry[FIELD_WEAPON_ID])
		else:
			continue
		if entry.has(FIELD_CURRENT_AMMO) and _is_int(entry[FIELD_CURRENT_AMMO]):
			we[FIELD_CURRENT_AMMO] = maxi(0, int(entry[FIELD_CURRENT_AMMO]))
		else:
			we[FIELD_CURRENT_AMMO] = 0
		if entry.has(FIELD_RESERVE_AMMO) and _is_int(entry[FIELD_RESERVE_AMMO]):
			we[FIELD_RESERVE_AMMO] = maxi(0, int(entry[FIELD_RESERVE_AMMO]))
		else:
			we[FIELD_RESERVE_AMMO] = 0
		repaired.append(we)
	weapons.clear()
	for entry in repaired:
		weapons.append(entry)


static func _repair_weapon_entries(weapons: Array) -> void:
	for entry in weapons:
		if not entry is Dictionary:
			continue
		if entry.has(FIELD_CURRENT_AMMO) and _is_int(entry[FIELD_CURRENT_AMMO]) and int(entry[FIELD_CURRENT_AMMO]) < 0:
			entry[FIELD_CURRENT_AMMO] = 0
		if entry.has(FIELD_RESERVE_AMMO) and _is_int(entry[FIELD_RESERVE_AMMO]) and int(entry[FIELD_RESERVE_AMMO]) < 0:
			entry[FIELD_RESERVE_AMMO] = 0


static func _sanitize_upgrade_entries(upgrades: Array) -> void:
	var repaired: Array = []
	for entry in upgrades:
		if not entry is Dictionary:
			continue
		var ue: Dictionary = {}
		if entry.has(FIELD_UPGRADE_ID) and entry[FIELD_UPGRADE_ID] is StringName:
			ue[FIELD_UPGRADE_ID] = entry[FIELD_UPGRADE_ID]
		elif entry.has(FIELD_UPGRADE_ID) and entry[FIELD_UPGRADE_ID] is String:
			ue[FIELD_UPGRADE_ID] = StringName(entry[FIELD_UPGRADE_ID])
		else:
			continue
		if entry.has(FIELD_UPGRADE_STACKS) and _is_int(entry[FIELD_UPGRADE_STACKS]):
			ue[FIELD_UPGRADE_STACKS] = maxi(0, int(entry[FIELD_UPGRADE_STACKS]))
		else:
			ue[FIELD_UPGRADE_STACKS] = 0
		repaired.append(ue)
	upgrades.clear()
	for entry in repaired:
		upgrades.append(entry)


static func _repair_upgrade_entries(upgrades: Array) -> void:
	for entry in upgrades:
		if not entry is Dictionary:
			continue
		if entry.has(FIELD_UPGRADE_STACKS) and _is_int(entry[FIELD_UPGRADE_STACKS]) and int(entry[FIELD_UPGRADE_STACKS]) < 0:
			entry[FIELD_UPGRADE_STACKS] = 0


static func _is_float(value) -> bool:
	return typeof(value) == TYPE_FLOAT


static func _is_int(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT and value == float(int(value)):
		return true
	return false


static func _is_bool(value) -> bool:
	return typeof(value) == TYPE_BOOL


static func _is_numeric(value) -> bool:
	var t = typeof(value)
	return t == TYPE_INT or t == TYPE_FLOAT
