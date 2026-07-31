extends CharacterBody2D

const SPEED := 280.0
const MOUSE_AIM_SPEED := 12.0

@export var _weapon_pivot: Node2D
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

var _mouse_world: Vector2 = global_position


func _ready() -> void:
	_weapon_pivot.look_at(get_global_mouse_position())


func _physics_process(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	).normalized()
	if input.length() > 1.0:
		input = input.normalized()

	velocity = input * SPEED
	move_and_slide()

	_mouse_world = get_global_mouse_position()
	_weapon_pivot.look_at(_mouse_world)

	if Input.is_action_just_pressed("ui_accept"):
		_shoot()


func _shoot() -> void:
	if _weapon_pivot.has_method("fire"):
		_weapon_pivot.fire()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameFlow.request_pause()
