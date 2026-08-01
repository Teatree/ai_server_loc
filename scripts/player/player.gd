extends CharacterBody2D

@export var _weapon_pivot: Node2D
@onready var movement_controller: MovementController = $MovementController
@onready var health_component: HealthComponent = $HealthComponent
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

var _mouse_world: Vector2 = global_position
var _last_checkpoint: Vector2 = Vector2(200, 600)
var _respawn_invulnerability: float = 0.0


func _ready() -> void:
	add_to_group("player")
	if movement_controller:
		movement_controller.facing_changed.connect(_on_facing_changed)
	if health_component:
		health_component.died.connect(_on_died)
	_last_checkpoint = global_position


func _physics_process(delta: float) -> void:
	if movement_controller:
		movement_controller._physics_process(delta)
	_mouse_world = get_global_mouse_position()
	if _weapon_pivot:
		_weapon_pivot.look_at(_mouse_world)
	if _respawn_invulnerability > 0.0:
		_respawn_invulnerability -= delta


func _shoot() -> void:
	if _weapon_pivot.has_method("fire"):
		_weapon_pivot.fire()


func apply_knockback(velocity: Vector2, duration: float) -> void:
	if movement_controller:
		movement_controller.apply_knockback(velocity, duration)


func drop_through() -> void:
	if movement_controller:
		movement_controller.drop_through()


func set_checkpoint(position: Vector2) -> void:
	_last_checkpoint = position


func respawn() -> void:
	global_position = _last_checkpoint
	if health_component:
		health_component.reset()
	if movement_controller:
		movement_controller.reset()
	_respawn_invulnerability = 1.0


func is_respawn_invulnerable() -> bool:
	return _respawn_invulnerability > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameFlow.request_pause()


func _on_facing_changed(new_facing: int) -> void:
	_sprite.scale.x = new_facing


func _on_died(damage_info: DamageInfo) -> void:
	respawn()
