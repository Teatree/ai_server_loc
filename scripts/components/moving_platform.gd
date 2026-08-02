extends Node2D
class_name MovingPlatform

signal waypoint_reached(index: int)

@export var waypoints: Array[Vector2] = []
@export var speed: float = 120.0
@export var loop: bool = true
@export var ping_pong: bool = false

var _current_target: int = 1
var _ping_pong_dir: int = 1
var _initialized: bool = false

func _physics_process(delta: float) -> void:
	if not _initialized:
		if waypoints.size() >= 2:
			position = waypoints[0]
			_initialized = true
		else:
			return
	var target: Vector2 = waypoints[_current_target]
	var distance: float = position.distance_to(target)
	if distance < 1.0:
		waypoint_reached.emit(_current_target)
		_advance_target()
	else:
		var direction: Vector2 = (target - position).normalized()
		var step: float = min(speed * delta, distance)
		position += direction * step

func _advance_target() -> void:
	if ping_pong:
		_current_target += _ping_pong_dir
		if _current_target >= waypoints.size():
			_current_target = waypoints.size() - 2
			_ping_pong_dir = -1
		elif _current_target <= 0:
			_current_target = 1
			_ping_pong_dir = 1
	else:
		_current_target += 1
		if _current_target >= waypoints.size():
			if loop:
				_current_target = 0
			else:
				_current_target = waypoints.size() - 1
