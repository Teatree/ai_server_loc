extends Node
class_name SaveManager

const SaveSchema = preload("res://scripts/save/save_schema.gd")
const SaveSanitizer = preload("res://scripts/save/save_sanitizer.gd")

signal game_saved(data: Dictionary)
signal game_loaded(data: Dictionary)

var _player: Node = null
var _upgrade_manager: Node = null
var _director: Node = null

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
	if _upgrade_manager and _upgrade_manager.has_method("serialize_state"):
		data[SaveSchema.FIELD_UPGRADES] = _upgrade_manager.serialize_state()
	if _director and _director.has_method("serialize_state"):
		var director_state: Dictionary = _director.serialize_state()
		data[SaveSchema.FIELD_ENCOUNTER_COMPLETED] = director_state.get(SaveSchema.FIELD_ENCOUNTER_COMPLETED, false)
		data[SaveSchema.FIELD_SESSION_SEED] = director_state.get(SaveSchema.FIELD_SESSION_SEED, 0)
	game_saved.emit(data.duplicate(true))
	return data


func load_game(data: Dictionary) -> void:
	var sanitized: Dictionary = SaveSanitizer.sanitize(data)
	if _player and _player.has_method("apply_state"):
		_player.apply_state(sanitized)
	if _upgrade_manager and _upgrade_manager.has_method("apply_state"):
		_upgrade_manager.apply_state(sanitized)
	if _director and _director.has_method("apply_state"):
		_director.apply_state(sanitized)
	game_loaded.emit(sanitized.duplicate(true))
