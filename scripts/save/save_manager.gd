extends Node
class_name SaveManager

const SaveSchema = preload("res://scripts/save/save_schema.gd")
const SaveSanitizer = preload("res://scripts/save/save_sanitizer.gd")

signal game_saved(data: Dictionary)
signal game_loaded(data: Dictionary)

var _player: Node = null
var _upgrade_manager: Node = null
var _director: Node = null

const SAVE_PATH: String = "user://savegame.json"
var _pending_load_data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree():
		_player = get_tree().get_first_node_in_group("player")
	_upgrade_manager = get_node_or_null("/root/UpgradeManager")
	_director = get_node_or_null("/root/Director")


func save_game() -> Dictionary:
	var data: Dictionary = SaveSchema.create_empty()
	data[SaveSchema.FIELD_VERSION] = SaveSchema.CURRENT_VERSION
	if _player and _player.has_method("serialize_state"):
		var player_state: Dictionary = _player.serialize_state()
		data[SaveSchema.FIELD_CHECKPOINT] = player_state.get(SaveSchema.FIELD_CHECKPOINT, SaveSchema.DEFAULT_CHECKPOINT)
		data[SaveSchema.FIELD_HEALTH_CURRENT] = player_state.get(SaveSchema.FIELD_HEALTH_CURRENT, SaveSchema.DEFAULT_HEALTH_CURRENT)
		data[SaveSchema.FIELD_HEALTH_MAX] = player_state.get(SaveSchema.FIELD_HEALTH_MAX, SaveSchema.DEFAULT_HEALTH_MAX)
		data[SaveSchema.FIELD_WEAPONS] = player_state.get(SaveSchema.FIELD_WEAPONS, [])
		_enrich_weapon_data(data[SaveSchema.FIELD_WEAPONS])
	if _upgrade_manager and _upgrade_manager.has_method("serialize_state"):
		data[SaveSchema.FIELD_UPGRADES] = _upgrade_manager.serialize_state()
	if _director and _director.has_method("serialize_state"):
		var director_state: Dictionary = _director.serialize_state()
		data[SaveSchema.FIELD_ENCOUNTER_COMPLETED] = director_state.get(SaveSchema.FIELD_ENCOUNTER_COMPLETED, false)
		data[SaveSchema.FIELD_SESSION_SEED] = director_state.get(SaveSchema.FIELD_SESSION_SEED, 0)
	game_saved.emit(data.duplicate(true))
	return data


func _enrich_weapon_data(weapons: Array) -> void:
	if weapons.is_empty():
		return
	var max_ammo: int = -1
	if _player and _player.has_method("get"):
		var pivot = _player.get("_weapon_pivot")
		if pivot and pivot.has_method("get"):
			var weapon_data = pivot.get("data")
			if weapon_data:
				max_ammo = weapon_data.max_ammo
	for entry in weapons:
		if entry is Dictionary and not entry.has("max_ammo"):
			entry["max_ammo"] = max_ammo


func load_game(data: Dictionary) -> void:
	var sanitized: Dictionary = SaveSanitizer.sanitize(data)
	if _player and _player.has_method("apply_state"):
		_player.apply_state(sanitized)
	if _upgrade_manager and _upgrade_manager.has_method("apply_state"):
		_upgrade_manager.apply_state(sanitized)
	if _director and _director.has_method("apply_state"):
		_director.apply_state(sanitized)
	game_loaded.emit(sanitized.duplicate(true))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_to_disk() -> void:
	var data: Dictionary = save_game()
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()


func load_from_disk() -> Dictionary:
	if not has_save():
		_pending_load_data.clear()
		return SaveSchema.create_empty()
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_pending_load_data.clear()
		return SaveSchema.create_empty()
	var data: Dictionary = file.get_var()
	file.close()
	if not data is Dictionary:
		_pending_load_data.clear()
		return SaveSchema.create_empty()
	_pending_load_data = SaveSanitizer.sanitize(data)
	return _pending_load_data


func clear_save() -> void:
	_pending_load_data.clear()
	if has_save():
		var absolute_path: String = ProjectSettings.globalize_path(SAVE_PATH)
		DirAccess.remove_absolute(absolute_path)


func has_pending_load() -> bool:
	return not _pending_load_data.is_empty()


func apply_pending_load() -> void:
	if not _pending_load_data.is_empty():
		load_game(_pending_load_data)
		_pending_load_data.clear()


static func _convert_keys_to_stringname(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in data.keys():
		var string_key: StringName = StringName(str(key))
		var value = data[key]
		if value is Dictionary:
			value = _convert_keys_to_stringname(value)
		elif value is Array:
			value = _convert_array_values_to_stringname(value)
		result[string_key] = value
	return result


static func _convert_array_values_to_stringname(arr: Array) -> Array:
	var result: Array = []
	for item in arr:
		if item is Dictionary:
			result.append(_convert_keys_to_stringname(item))
		else:
			result.append(item)
	return result
