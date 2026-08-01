extends CharacterBody2D

@export var movement_controller: MovementController
@export var _weapon_pivot: Node2D
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

var _mouse_world: Vector2 = global_position


func _ready() -> void:
	if movement_controller:
		movement_controller.facing_changed.connect(_on_facing_changed)
	_mouse_world = get_global_mouse_position()


func _physics_process(delta: float) -> void:
	if movement_controller:
		movement_controller._physics_process(delta)
	_mouse_world = get_global_mouse_position()
	if _weapon_pivot:
		_weapon_pivot.look_at(_mouse_world)


func _shoot() -> void:
	if _weapon_pivot.has_method("fire"):
		_weapon_pivot.fire()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameFlow.request_pause()


func _on_facing_changed(new_facing: int) -> void:
	_sprite.scale.x = new_facing
