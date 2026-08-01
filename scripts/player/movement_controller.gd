extends Node

class_name MovementController

signal facing_changed(new_facing: int)

@export var config: MovementConfig
@export var body: CharacterBody2D

var _facing: int = 1


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_horizontal_movement(delta)
	_update_facing()
	body.move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y += config.gravity * delta
		body.velocity.y = min(body.velocity.y, config.max_fall_speed)


func _apply_horizontal_movement(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")
	if input_dir == 0.0:
		_apply_deceleration(delta)
	else:
		_apply_acceleration(input_dir, delta)


func _apply_acceleration(input_dir: float, delta: float) -> void:
	var max_speed: float = config.max_ground_speed if body.is_on_floor() else config.max_air_speed
	var accel: float = config.ground_acceleration if body.is_on_floor() else config.air_acceleration
	body.velocity.x = move_toward(body.velocity.x, input_dir * max_speed, accel * delta)


func _apply_deceleration(delta: float) -> void:
	var decel: float = config.ground_deceleration if body.is_on_floor() else config.air_deceleration
	body.velocity.x = move_toward(body.velocity.x, 0.0, decel * delta)


func _update_facing() -> void:
	if body.velocity.x > 0.0 and _facing != 1:
		_facing = 1
		facing_changed.emit(_facing)
	elif body.velocity.x < 0.0 and _facing != -1:
		_facing = -1
		facing_changed.emit(_facing)


func reset() -> void:
	body.velocity = Vector2.ZERO
	_facing = 1


func get_facing() -> int:
	return _facing
