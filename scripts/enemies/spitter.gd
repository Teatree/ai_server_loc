extends CharacterBody2D
class_name Spitter

signal state_changed(state: StringName)
signal attack_telegraph_started()

@export var sight_range: float = 300.0
@export var fov_degrees: float = 90.0
@export var chase_speed: float = 80.0
@export var attack_range: float = 250.0
@export var attack_damage: float = 10.0
@export var attack_knockback: float = 100.0
@export var attack_cooldown: float = 2.0
@export var attack_telegraph_duration: float = 0.6
@export var projectile_speed: float = 300.0
@export var noise_memory_duration: float = 4.0
@export var investigation_speed: float = 50.0

@onready var health_component: HealthComponent = $HealthComponent
@onready var _raycast: RayCast2D = $RayCast2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _navigator: Node2D = $EnemyNavigator

var _state: StringName = &"idle"
var _target: Node2D = null
var _last_known_position: Vector2 = Vector2.ZERO
var _noise_timer: float = 0.0
var _attack_timer: float = 0.0
var _telegraph_timer: float = 0.0
var _base_modulate: Color = Color.WHITE

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
	if _navigator:
		_navigator.set_body(self)
	if _sprite:
		_base_modulate = _sprite.modulate

func _physics_process(delta: float) -> void:
	if health_component and health_component.is_dead:
		return

	if _attack_timer > 0.0:
		_attack_timer -= delta

	if _noise_timer > 0.0:
		_noise_timer -= delta
		if _noise_timer <= 0.0:
			_last_known_position = Vector2.ZERO

	_update_telegraph_visual(delta)
	_update_perception()
	_run_state(delta)
	_apply_crowd_separation(delta)
	move_and_slide()

func _apply_crowd_separation(delta: float) -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for other: Node in enemies:
		if other == self or not is_instance_valid(other):
			continue
		if not other is CharacterBody2D:
			continue
		var other_body: CharacterBody2D = other as CharacterBody2D
		var dir: Vector2 = global_position - other_body.global_position
		var dist: float = dir.length()
		if dist < 30.0 and dist > 0.01:
			var push: Vector2 = dir.normalized() * 60.0 * delta
			velocity += push
			other_body.velocity -= push

func _update_telegraph_visual(delta: float) -> void:
	if _state == &"telegraph":
		_telegraph_timer -= delta
		if _sprite:
			_sprite.modulate = Color.RED
	else:
		if _sprite and _sprite.modulate != _base_modulate:
			_sprite.modulate = _base_modulate

func _update_perception() -> void:
	if not _target or not is_instance_valid(_target):
		_target = _find_player()

	if _target:
		var dist: float = global_position.distance_to(_target.global_position)
		if dist <= sight_range:
			var to_target: Vector2 = (_target.global_position - global_position).normalized()
			var forward: Vector2 = Vector2.RIGHT if _sprite.scale.x >= 0 else Vector2.LEFT
			var angle_to_target: float = forward.angle_to(to_target)
			if abs(angle_to_target) < deg_to_rad(fov_degrees * 0.5):
				if dist <= attack_range and _has_clear_sight(_target.global_position):
					if _attack_timer <= 0.0:
						_set_state(&"telegraph")
					else:
						_set_state(&"attack_cooldown")
					_last_known_position = _target.global_position
					_noise_timer = noise_memory_duration
					return
				if _state != &"telegraph" and _state != &"attack_cooldown":
					_set_state(&"chase")
				_last_known_position = _target.global_position
				_noise_timer = noise_memory_duration
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
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node.global_position.distance_to(target_pos) < 5.0:
			return true
	return false

func _run_state(delta: float) -> void:
	match _state:
		&"idle":
			velocity = Vector2.ZERO
		&"investigate":
			_approach(_last_known_position, investigation_speed, delta)
		&"chase":
			if _target and is_instance_valid(_target):
				var dist: float = global_position.distance_to(_target.global_position)
				if dist <= attack_range:
					_approach(_target.global_position, chase_speed * 0.5, delta)
					if _has_clear_sight(_target.global_position) and _attack_timer <= 0.0:
						_set_state(&"telegraph")
				else:
					_approach(_target.global_position, chase_speed, delta)
			else:
				_set_state(&"investigate")
		&"telegraph":
			velocity = Vector2.ZERO
			if _telegraph_timer <= 0.0:
				_start_attack()
		&"attack_cooldown":
			velocity = Vector2.ZERO
			if _target and is_instance_valid(_target):
				var dist: float = global_position.distance_to(_target.global_position)
				if dist > attack_range * 1.1:
					_set_state(&"chase")
				elif dist <= attack_range and _has_clear_sight(_target.global_position):
					if _attack_timer <= 0.0:
						_set_state(&"telegraph")
			else:
				_set_state(&"investigate")

func _approach(target: Vector2, speed: float, delta: float) -> void:
	var dir: Vector2 = (target - global_position).normalized()
	velocity = dir * speed
	_sprite.scale.x = 1 if dir.x >= 0 else -1

func _start_attack() -> void:
	if not _target or not is_instance_valid(_target):
		_set_state(&"chase")
		return
	if not _has_clear_sight(_target.global_position):
		_set_state(&"chase")
		return
	_spawn_projectile()
	_attack_timer = attack_cooldown
	attack_telegraph_started.emit()
	_set_state(&"attack_cooldown")

func _spawn_projectile() -> void:
	if not _target or not is_instance_valid(_target):
		return
	var dir: Vector2 = (_target.global_position - global_position).normalized()
	_sprite.scale.x = 1 if dir.x >= 0 else -1
	var origin: Vector2 = global_position
	var proj: Area2D = Area2D.new()
	proj.set_script(preload("res://scripts/weapons/projectile.gd"))
	proj.global_position = origin
	if proj.has_method("configure"):
		proj.configure(attack_damage, attack_knockback, dir * projectile_speed, self)
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 4.0
	proj.add_child(shape)
	get_tree().root.add_child.call_deferred(proj)

func _on_damaged(info: DamageInfo) -> void:
	if _state != &"dead":
		_telegraph_timer = 0.0
		_attack_timer = 0.0
		_set_state(&"chase")
		if info.knockback > 0.0:
			velocity = info.hit_direction * info.knockback * 0.05
			move_and_slide()

func interrupt() -> void:
	if _state == &"dead":
		return
	_telegraph_timer = 0.0
	_attack_timer = 0.0
	_set_state(&"chase")

func _on_died(info: DamageInfo) -> void:
	_set_state(&"dead")
	velocity = Vector2.ZERO
	if _collision:
		_collision.set_deferred("disabled", true)
	if _raycast:
		_raycast.set_deferred("enabled", false)

func _set_state(new_state: StringName) -> void:
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(_state)
	if _state != &"telegraph":
		if _sprite and _sprite.modulate != _base_modulate:
			_sprite.modulate = _base_modulate
	if _state == &"telegraph":
		attack_telegraph_started.emit()

func reset() -> void:
	_set_state(&"idle")
	_target = null
	_last_known_position = Vector2.ZERO
	_noise_timer = 0.0
	_attack_timer = 0.0
	_telegraph_timer = 0.0
	velocity = Vector2.ZERO
	if health_component:
		health_component.reset()
	if _collision:
		_collision.disabled = false
	if _raycast:
		_raycast.enabled = true
	if _sprite:
		_sprite.modulate = _base_modulate
	if _navigator:
		_navigator.reset()

func set_navigation_graph(graph: PlatformGraph) -> void:
	if _navigator and _navigator.has_method("set_graph"):
		_navigator.set_graph(graph)

func receive_noise(position: Vector2, strength: float) -> void:
	if not is_active():
		return
	_last_known_position = position
	_noise_timer = noise_memory_duration * clamp(strength, 0.5, 1.0)
	_set_state(&"investigate")

func take_damage(info: DamageInfo) -> void:
	if health_component:
		health_component.take_damage(info)

func is_active() -> bool:
	return _state != &"dead"
