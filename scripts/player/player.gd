extends CharacterBody2D

@export var _weapon_pivot: Node2D
@onready var movement_controller: MovementController = $MovementController
@onready var health_component: HealthComponent = $HealthComponent
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _aim: AimController = $AimController

var _last_checkpoint: Vector2 = Vector2(200, 600)
var _respawn_invulnerability: float = 0.0
var _facing: int = 1


func _ready() -> void:
	add_to_group("player")
	if movement_controller:
		movement_controller.facing_changed.connect(_on_facing_changed)
	if health_component:
		health_component.died.connect(_on_died)
	_last_checkpoint = global_position
	if _aim:
		_aim.target_node = self


func _physics_process(delta: float) -> void:
	if movement_controller:
		movement_controller._physics_process(delta)
	if _aim and _weapon_pivot:
		_aim.update_aim(global_position, _facing)
	if _respawn_invulnerability > 0.0:
		_respawn_invulnerability -= delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		_try_fire()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameFlow.request_pause()


func _try_fire() -> void:
	if _weapon_pivot and _weapon_pivot.has_method("fire"):
		var muzzle: Vector2 = _weapon_pivot.global_position
		var dir: Vector2 = Vector2.RIGHT.rotated(_weapon_pivot.global_rotation)
		if _weapon_pivot.get_node_or_null("Muzzle"):
			muzzle = _weapon_pivot.get_node("Muzzle").global_position
		_weapon_pivot.fire(muzzle, dir)


func take_damage(info: DamageInfo) -> void:
	if health_component:
		health_component.take_damage(info)


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
	if _weapon_pivot and _weapon_pivot.has_method("reset"):
		_weapon_pivot.reset()
	_respawn_invulnerability = 1.0


func is_respawn_invulnerable() -> bool:
	return _respawn_invulnerability > 0.0


func _on_facing_changed(new_facing: int) -> void:
	_sprite.scale.x = new_facing
	_facing = new_facing


func _on_died(damage_info: DamageInfo) -> void:
	respawn()
