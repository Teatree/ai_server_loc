extends Node2D
class_name AimController

signal aim_changed(direction: Vector2, angle: float)

@export var target_node: Node2D :
	set(value):
		target_node = value
		if target_node and target_node is Node2D:
			_global_target = target_node

var _global_target: Node2D = null
var _direction: Vector2 = Vector2.RIGHT
var _angle: float = 0.0

func _ready() -> void:
	pass

func get_aim_direction() -> Vector2:
	return _direction

func get_aim_angle() -> float:
	return _angle

func update_aim(player_global_position: Vector2, player_facing: int) -> void:
	var raw_dir: Vector2 = _compute_direction(player_global_position, player_facing)
	_direction = raw_dir.normalized()
	_angle = _direction.angle()
	aim_changed.emit(_direction, _angle)

func _compute_direction(player_global_position: Vector2, player_facing: int) -> Vector2:
	var mouse_world: Vector2 = _get_mouse_world()
	var diff: Vector2 = mouse_world - player_global_position

	if diff.length() > 1.0:
		return diff

	var right_stick: Vector2 = _get_right_stick()
	if right_stick.length() > 0.3:
		return right_stick

	var keyboard_dir: Vector2 = _get_keyboard_aim()
	if keyboard_dir.length() > 0.0:
		return keyboard_dir

	return Vector2(player_facing, 0.0)

func _get_mouse_world() -> Vector2:
	if get_viewport():
		return get_viewport().get_mouse_position()
	return Vector2.ZERO

func _get_right_stick() -> Vector2:
	var x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var y: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(x) < 0.3 and abs(y) < 0.3:
		return Vector2.ZERO
	return Vector2(x, y)

func _get_keyboard_aim() -> Vector2:
	var dir: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("aim_up"):
		dir.y -= 1.0
	if Input.is_action_pressed("aim_down"):
		dir.y += 1.0
	if Input.is_action_pressed("aim_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("aim_right"):
		dir.x += 1.0
	return dir
