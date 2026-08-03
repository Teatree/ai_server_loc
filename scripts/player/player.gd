extends CharacterBody2D

@export var _weapon_pivot: Node2D
@export var _weapon_inventory: Array[WeaponData] = []
@onready var movement_controller: MovementController = $MovementController
@onready var health_component: HealthComponent = $HealthComponent
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _aim: AimController = $AimController

var _last_checkpoint: Vector2 = Vector2(200, 600)
var _respawn_invulnerability: float = 0.0
var _facing: int = 1
var _current_weapon_index: int = 0
var _melee_attack = null


func _ready() -> void:
	add_to_group("player")
	if movement_controller:
		movement_controller.facing_changed.connect(_on_facing_changed)
	if health_component:
		health_component.died.connect(_on_died)
	_last_checkpoint = global_position
	if _aim:
		_aim.target_node = self
	if _weapon_pivot and _weapon_inventory.size() > 0:
		_weapon_pivot.data = _weapon_inventory[0]
		_weapon_pivot.reset()
	if _weapon_pivot and _weapon_pivot.has_signal("equipped"):
		_weapon_pivot.equipped.emit(_weapon_pivot)
	_melee_attack = load("res://scripts/weapons/melee_attack.gd").new()
	_melee_attack.collision_mask = 2
	add_child(_melee_attack)


var _melee_swing_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if movement_controller:
		movement_controller._physics_process(delta)
	if _aim and _weapon_pivot:
		_aim.update_aim(global_position, _facing)
	if _respawn_invulnerability > 0.0:
		_respawn_invulnerability -= delta
	if _melee_swing_timer > 0.0:
		_melee_swing_timer -= delta
		if _melee_swing_timer <= 0.0 and _melee_attack:
			_melee_attack.end_swing()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		_try_fire()
	if event.is_action_pressed("reload"):
		_try_reload()
	if event.is_action_pressed("switch_weapon"):
		_try_switch_weapon()
	if event.is_action_pressed("melee"):
		_try_melee()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameFlow.request_pause()


func _try_fire() -> void:
	if _weapon_pivot and _weapon_pivot.has_method("fire"):
		var muzzle: Vector2 = _weapon_pivot.global_position
		var dir: Vector2 = Vector2.RIGHT.rotated(_weapon_pivot.global_rotation)
		if _weapon_pivot.get_node_or_null("Muzzle"):
			muzzle = _weapon_pivot.get_node("Muzzle").global_position
		_weapon_pivot.fire(muzzle, dir)


func _try_reload() -> void:
	if _weapon_pivot and _weapon_pivot.has_method("reload"):
		_weapon_pivot.reload()


func _try_switch_weapon() -> bool:
	if _weapon_inventory.size() <= 1:
		return false
	if not _weapon_pivot or not _weapon_pivot.has_method("can_fire") or not _weapon_pivot.has_method("reset"):
		return false
	var weapon: WeaponBase = _weapon_pivot as WeaponBase
	if not weapon.can_fire():
		return false
	if weapon._reloading:
		return false
	var next_index: int = (_current_weapon_index + 1) % _weapon_inventory.size()
	_current_weapon_index = next_index
	_weapon_pivot.data = _weapon_inventory[_current_weapon_index]
	_weapon_pivot.reset()
	if _weapon_pivot.has_signal("equipped"):
		_weapon_pivot.equipped.emit(_weapon_pivot)
	return true


func _try_melee() -> void:
	if not _melee_attack or not _weapon_pivot:
		return
	var origin: Vector2 = global_position
	var data: WeaponData = null
	if _weapon_pivot.has_method("data"):
		data = _weapon_pivot.data
	if not data or data.melee_range <= 0.0:
		return
	_melee_attack.attack(origin, _facing, data)
	_melee_swing_timer = 0.15


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
	_current_weapon_index = 0
	if _weapon_pivot and _weapon_inventory.size() > 0:
		_weapon_pivot.data = _weapon_inventory[0]
		_weapon_pivot.reset()
	if _weapon_pivot and _weapon_pivot.has_signal("equipped"):
		_weapon_pivot.equipped.emit(_weapon_pivot)
	if _melee_attack:
		_melee_attack.reset()
	_melee_swing_timer = 0.0
	_respawn_invulnerability = 1.0


func is_respawn_invulnerable() -> bool:
	return _respawn_invulnerability > 0.0


func _on_facing_changed(new_facing: int) -> void:
	_sprite.scale.x = new_facing
	_facing = new_facing


func _on_died(damage_info: DamageInfo) -> void:
	respawn()
