extends CharacterBody2D
class_name Shambler

signal state_changed(state: StringName)

@export var sight_range: float = 300.0
@export var fov_degrees: float = 90.0
@export var chase_speed: float = 80.0
@export var attack_range: float = 40.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var noise_memory_duration: float = 4.0
@export var investigation_speed: float = 50.0

@onready var health_component: HealthComponent = $HealthComponent
@onready var _raycast: RayCast2D = $RayCast2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D

var _state: StringName = &"idle"
var _target: Node2D = null
var _last_known_position: Vector2 = Vector2.ZERO
var _noise_timer: float = 0.0
var _attack_timer: float = 0.0
var _stagger_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	if health_component:
		health_component.died.connect(_on_died)
		health_component.damaged.connect(_on_damaged)
	_set_state(&"idle")
	for weapon: Node in get_tree().get_nodes_in_group("weapon"):
		if weapon.has_signal("noise_emitted"):
			weapon.noise_emitted.connect(receive_noise)
	if _raycast:
		_raycast.add_exception(self)

func _physics_process(delta: float) -> void:
	if health_component and health_component.is_dead:
		return

	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		if _stagger_timer <= 0.0:
			_set_state(&"chase" if _has_clear_sight(_target.global_position if _target else _last_known_position) else &"investigate")
		return

	if _attack_timer > 0.0:
		_attack_timer -= delta

	if _noise_timer > 0.0:
		_noise_timer -= delta
		if _noise_timer <= 0.0:
			_last_known_position = Vector2.ZERO

	_update_perception()
	_run_state(delta)

func _update_perception() -> void:
	if not _target or not is_instance_valid(_target):
		_target = _find_player()

	if _target:
		var dist: float = global_position.distance_to(_target.global_position)
		if dist <= sight_range:
			var to_target: Vector2 = (_target.global_position - global_position).normalized()
			var forward: Vector2 = Vector2.RIGHT if _sprite.scale.x >= 0 else Vector2.LEFT
			var angle_to_target: float = forward.angle_to(to_target)
			if abs(angle_to_target) < deg_to_rad(fov_degrees * 0.5) and _has_clear_sight(_target.global_position):
				_last_known_position = _target.global_position
				_noise_timer = noise_memory_duration
				if dist <= attack_range:
					_set_state(&"attack")
				else:
					_set_state(&"chase")
				return

	if _last_known_position != Vector2.ZERO and _noise_timer > 0.0:
		if global_position.distance_to(_last_known_position) < 5.0:
			_last_known_position = Vector2.ZERO
			_set_state(&"idle")
		else:
			_set_state(&"investigate")
	else:
		_set_state(&"idle")

func _find_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	return players[0] as Node2D if players.size() > 0 else null

func _has_clear_sight(target_pos: Vector2) -> bool:
	if not _raycast:
		return true

	var forward: Vector2 = Vector2.RIGHT if _sprite.scale.x >= 0 else Vector2.LEFT
	var to_target: Vector2 = (target_pos - global_position).normalized()
	var angle_to_target: float = forward.angle_to(to_target)
	if abs(angle_to_target) >= deg_to_rad(fov_degrees * 0.5):
		return false

	_raycast.global_position = global_position
	_raycast.target_position = target_pos - global_position
	_raycast.force_raycast_update()

	if _raycast.is_colliding():
		var collider: Object = _raycast.get_collider()
		if collider and collider.is_in_group("player"):
			return true
		return false
	return true

func _run_state(delta: float) -> void:
	match _state:
		&"idle":
			velocity = Vector2.ZERO
		&"investigate":
			_approach(_last_known_position, investigation_speed, delta)
		&"chase":
			if _target and is_instance_valid(_target):
				_approach(_target.global_position, chase_speed, delta)
			else:
				_set_state(&"investigate")
		&"attack":
			velocity = Vector2.ZERO
			if _attack_timer <= 0.0:
				_perform_attack()

	move_and_slide()

func _approach(target: Vector2, speed: float, delta: float) -> void:
	var dir: Vector2 = (target - global_position).normalized()
	velocity = dir * speed
	_sprite.scale.x = 1 if dir.x >= 0 else -1

func _perform_attack() -> void:
	if not _target or not is_instance_valid(_target):
		return
	_attack_timer = attack_cooldown
	if _target.has_method("take_damage"):
		var dir: Vector2 = (_target.global_position - global_position).normalized()
		var info: DamageInfo = DamageInfo.new(attack_damage, DamageInfo.DamageType.BALLISTIC, self, _target.global_position, dir, 200.0)
		_target.take_damage(info)
	if _target.has_method("apply_knockback"):
		_target.apply_knockback(Vector2.RIGHT.rotated(global_rotation) * 200.0, 0.3)

func _on_damaged(info: DamageInfo) -> void:
	if _state != &"dead":
		_stagger_timer = 0.4
		_set_state(&"stagger")
		if info.knockback > 0.0:
			velocity = info.hit_direction * info.knockback * 0.05
			move_and_slide()

func _on_died(info: DamageInfo) -> void:
	_set_state(&"dead")
	velocity = Vector2.ZERO
	_collision.disabled = true
	if _raycast:
		_raycast.enabled = false

func _set_state(new_state: StringName) -> void:
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(_state)

func reset() -> void:
	_set_state(&"idle")
	_target = null
	_last_known_position = Vector2.ZERO
	_noise_timer = 0.0
	_attack_timer = 0.0
	_stagger_timer = 0.0
	velocity = Vector2.ZERO
	if health_component:
		health_component.reset()
	if _collision:
		_collision.disabled = false
	if _raycast:
		_raycast.enabled = true

func receive_noise(position: Vector2, strength: float) -> void:
	if not is_active():
		return
	_last_known_position = position
	_noise_timer = noise_memory_duration * clamp(strength, 0.5, 1.0)
	_set_state(&"investigate")

func is_active() -> bool:
	return _state != &"dead"
