extends Node

class_name MovementController

signal facing_changed(new_facing: int)
signal jumped()
signal left_ground()
signal landed()
signal dodge_started()
signal dodge_ended()
signal knockback_started()

@export var config: MovementConfig
@export var body: CharacterBody2D

var _facing: int = 1
var _jump_held: bool = false
var _was_on_floor: bool = true
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _dodge_direction: float = 0.0
var _knockback_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _input_locked: bool = false


func _physics_process(delta: float) -> void:
	if not body:
		return
	_update_dodge(delta)
	_update_knockback(delta)
	_handle_jump_input()
	_apply_gravity(delta)
	if not _input_locked:
		_apply_horizontal_movement(delta)
	_update_facing()
	body.move_and_slide()
	_update_ground_transitions(delta)
	_handle_dodge_input()


func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = config.jump_buffer_time
		_jump_held = true
		_try_jump()
	elif Input.is_action_just_released("jump"):
		_jump_held = false
		if body.velocity.y < 0.0:
			body.velocity.y *= config.jump_cut_multiplier
			body.velocity.y = min(body.velocity.y, 0.0)

	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= get_physics_process_delta_time()
		if _jump_buffer_timer <= 0.0:
			_jump_buffer_timer = 0.0
			if body.is_on_floor():
				_try_jump()


func _handle_dodge_input() -> void:
	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0.0 and _dodge_timer <= 0.0:
		var input_dir := Input.get_axis("move_left", "move_right")
		if input_dir == 0.0:
			input_dir = _facing
		_dodge_direction = input_dir
		_dodge_timer = config.dodge_duration
		_dodge_cooldown_timer = config.dodge_cooldown
		body.velocity.x = _dodge_direction * config.dodge_speed
		body.velocity.y = 0.0
		dodge_started.emit()


func _update_dodge(delta: float) -> void:
	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		if _dodge_timer <= 0.0:
			_dodge_timer = 0.0
			dodge_ended.emit()
	if _dodge_cooldown_timer > 0.0:
		_dodge_cooldown_timer -= delta
		if _dodge_cooldown_timer < 0.0:
			_dodge_cooldown_timer = 0.0
	if _dodge_timer > 0.0:
		body.velocity.x = _dodge_direction * config.dodge_speed
		if not body.is_on_floor():
			body.velocity.y += config.gravity * config.dodge_gravity_scale * delta
			body.velocity.y = min(body.velocity.y, config.max_fall_speed)


func _update_knockback(delta: float) -> void:
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		if _knockback_timer <= 0.0:
			_knockback_timer = 0.0
			_knockback_velocity = Vector2.ZERO
	body.velocity = _knockback_velocity


func apply_knockback(velocity: Vector2, duration: float) -> void:
	_knockback_velocity = velocity
	_knockback_timer = duration
	knockback_started.emit()


func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		body.velocity.x = 0.0


func drop_through() -> void:
	if body.is_on_floor():
		body.velocity.y = config.drop_through_speed
		body.set_collision_mask_value(config.one_way_platform_layer, false)
		await get_tree().physics_frame
		body.set_collision_mask_value(config.one_way_platform_layer, true)


func _try_jump() -> void:
	if body.is_on_floor():
		_perform_jump()
		return
	if _coyote_timer > 0.0 and not body.is_on_floor():
		_perform_jump()
		return


func _perform_jump() -> void:
	body.velocity.y = config.jump_velocity
	_was_on_floor = false
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	jumped.emit()


func _apply_gravity(delta: float) -> void:
	if body.is_on_floor():
		return
	if not _jump_held and body.velocity.y < 0.0:
		body.velocity.y += config.variable_jump_gravity * delta
	else:
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


func _update_ground_transitions(delta: float) -> void:
	var on_floor: bool = body.is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit()
		_coyote_timer = 0.0
	elif not on_floor and _was_on_floor:
		_coyote_timer = config.coyote_time
		left_ground.emit()
	if not on_floor and _coyote_timer > 0.0:
		_coyote_timer -= delta
		if _coyote_timer < 0.0:
			_coyote_timer = 0.0
	_was_on_floor = on_floor


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
	_jump_held = false
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_was_on_floor = true
	_dodge_timer = 0.0
	_dodge_cooldown_timer = 0.0
	_dodge_direction = 0.0
	_knockback_timer = 0.0
	_knockback_velocity = Vector2.ZERO
	_input_locked = false


func get_facing() -> int:
	return _facing
