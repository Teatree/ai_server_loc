extends Node
class_name Director

signal spawned(enemy_type: StringName, position: Vector2)
signal budget_changed(remaining: float)
signal slot_changed(remaining: int)

@export var max_threat_budget: float = 100.0
@export var max_living_enemies: int = 10
@export var spawn_visibility_range: float = 600.0

var _seed: int = 0
var _rng: RandomNumberGenerator
var _current_threat: float = 0.0
var _living_enemies: int = 0
var _player_position: Vector2 = Vector2.ZERO
var _spawn_markers: Array = []

func _init() -> void:
	_rng = RandomNumberGenerator.new()


func configure(seed: int, spawn_markers: Array, player_position: Vector2) -> void:
	_seed = seed
	_rng.seed = seed
	_spawn_markers = spawn_markers.duplicate()
	_player_position = player_position
	_current_threat = 0.0
	_living_enemies = 0


func get_remaining_threat() -> float:
	return max_threat_budget - _current_threat


func get_remaining_slots() -> int:
	return max_living_enemies - _living_enemies


func can_afford(threat_cost: float) -> bool:
	return threat_cost <= get_remaining_threat() and get_remaining_slots() > 0


func register_spawn(threat_cost: float) -> bool:
	if not can_afford(threat_cost):
		return false
	_current_threat += threat_cost
	_living_enemies += 1
	budget_changed.emit(get_remaining_threat())
	slot_changed.emit(get_remaining_slots())
	return true


func register_death(threat_cost: float) -> void:
	_current_threat = max(0.0, _current_threat - threat_cost)
	_living_enemies = max(0, _living_enemies - 1)
	budget_changed.emit(get_remaining_threat())
	slot_changed.emit(get_remaining_slots())


func select_spawn() -> Dictionary:
	var available: Array[Dictionary] = []
	for marker in _spawn_markers:
		if not marker.has_method("is_active"):
			continue
		if not marker.is_active():
			continue
		var enemy_type: StringName = &"unknown"
		if marker.has_method("get_enemy_type"):
			enemy_type = marker.get_enemy_type()
		elif "enemy_type" in marker:
			enemy_type = marker.enemy_type
		var threat: float = _get_threat_cost(enemy_type)
		if threat <= 0.0:
			continue
		if not can_afford(threat):
			continue
		var pos: Vector2 = marker.global_position if marker.has_method("get_global_position") else Vector2.ZERO
		if not _is_visible(pos):
			continue
		available.append({
			"marker": marker,
			"enemy_type": enemy_type,
			"threat": threat,
			"position": pos
		})

	if available.is_empty():
		return {}

	var idx: int = _rng.randi_range(0, available.size() - 1)
	var choice: Dictionary = available[idx]
	if register_spawn(choice.threat):
		spawned.emit(choice.enemy_type, choice.position)
		return choice
	return {}


func _is_visible(position: Vector2) -> bool:
	return _player_position.distance_to(position) <= spawn_visibility_range


func _get_threat_cost(enemy_type: StringName) -> float:
	match enemy_type:
		&"shambler": return 10.0
		&"runner": return 15.0
		&"ranged": return 20.0
		&"brute": return 30.0
		_: return 10.0


func reset() -> void:
	_current_threat = 0.0
	_living_enemies = 0
	_rng.seed = _seed
