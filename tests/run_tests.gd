extends Node

var _passed: int = 0
var _failed: int = 0
var _death_count: int = 0
var _shambler_death_count: int = 0
var _damaged_after_invulnerability: bool = false
var _damaged_after_death: bool = false


func _ready() -> void:
	_test_death_emits_once()
	_test_damage_applies_after_invulnerability_expires()
	_test_entities_cannot_receive_damage_after_death()
	_test_reset_clears_death_state()
	_test_weapon_fire_rate_blocks_spam()
	_test_ammo_never_negative()
	_test_dry_fire_blocks_fire_when_ammo_zero()
	_test_weapon_reset_restores_ammo()
	_test_weapon_data_separate_from_movement()
	_test_shambler_starts_idle()
	_test_noise_triggers_investigate()
	_test_noise_position_expires()
	_test_dead_enemy_ignores_noise()
	_test_shambler_dies_once()
	_test_shambler_reset_clears_death()
	_test_sight_visible_to_player()
	_test_sight_blocked_by_obstacle()
	_test_sight_outside_fov()
	_test_gunfire_starts_investigation()
	_test_inactive_enemy_ignores_events()
	_test_noise_position_expires()
	_test_expired_position_causes_idle()
	_print_summary()
	get_tree().quit(0 if _failed == 0 else 1)


func _on_death(_info: DamageInfo) -> void:
	_death_count += 1


func _test_death_emits_once() -> void:
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 10.0
	health.current_health = 10.0
	_death_count = 0
	health.died.connect(_on_death)
	health.take_damage(DamageInfo.new(15.0))
	health.take_damage(DamageInfo.new(5.0))
	_assert(_death_count == 1, "death should emit exactly once")


func _test_damage_applies_after_invulnerability_expires() -> void:
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 10.0
	health.current_health = 10.0
	health.invulnerability_duration = 0.5
	health.take_damage(DamageInfo.new(5.0))
	health._process(0.6)
	_damaged_after_invulnerability = false
	health.damaged.connect(func(_info: DamageInfo): _damaged_after_invulnerability = true)
	health.take_damage(DamageInfo.new(3.0))
	_assert(_damaged_after_invulnerability, "damage should apply after invulnerability expires")


func _test_entities_cannot_receive_damage_after_death() -> void:
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 10.0
	health.current_health = 10.0
	health.take_damage(DamageInfo.new(15.0))
	_assert(health.is_dead, "entity should be dead")
	_damaged_after_death = false
	health.damaged.connect(func(_info: DamageInfo): _damaged_after_death = true)
	health.take_damage(DamageInfo.new(5.0))
	_assert(not _damaged_after_death, "damage should be ignored after death")


func _test_reset_clears_death_state() -> void:
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 10.0
	health.current_health = 10.0
	health.take_damage(DamageInfo.new(15.0))
	_assert(health.is_dead, "entity should be dead")
	health.reset()
	_assert(not health.is_dead, "reset should clear death state")
	_assert(health.current_health == health.max_health, "reset should restore health")


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS: ", message)
	else:
		_failed += 1
		print("FAIL: ", message)


func _print_summary() -> void:
	print("\nTests: ", _passed, " passed, ", _failed, " failed, ", _passed + _failed, " total")


# --- S04 weapon tests ---

var _weapon_fire_count: int = 0
var _weapon_fired_count: int = 0

func _test_weapon_fire_rate_blocks_spam() -> void:
	var data: WeaponData = WeaponData.new()
	data.fire_rate = 0.3
	data.max_ammo = -1
	var weapon: WeaponBase = WeaponBase.new()
	weapon.data = data
	weapon.fired.connect(func(_w: WeaponBase, _o: Vector2, _d: Vector2): _weapon_fire_count += 1)
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	_assert(weapon.can_fire() == false, "weapon should not fire immediately after shot")
	weapon._process(0.2)
	_assert(not weapon.can_fire(), "weapon should still be on cooldown at 0.2s")
	weapon._process(0.15)
	_assert(weapon.can_fire(), "weapon should be ready after fire_rate elapsed")
	_assert(_weapon_fire_count == 1, "should have fired exactly once despite input spam")


func _test_ammo_never_negative() -> void:
	var data: WeaponData = WeaponData.new()
	data.max_ammo = 5
	data.ammo_per_shot = 1
	data.fire_rate = 0.01
	var weapon: WeaponBase = WeaponBase.new()
	weapon.data = data
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	weapon._process(0.02)
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	weapon._process(0.02)
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	weapon._process(0.02)
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	weapon._process(0.02)
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	weapon._process(0.02)
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	_assert(weapon.get_current_ammo() == 0, "ammo should be zero, not negative")
	_assert(not weapon.can_fire(), "cannot fire with zero ammo")
	weapon.add_ammo(3)
	_assert(weapon.get_current_ammo() == 3, "add_ammo should restore ammo")


func _test_dry_fire_blocks_fire_when_ammo_zero() -> void:
	var data: WeaponData = WeaponData.new()
	data.max_ammo = 2
	data.ammo_per_shot = 1
	data.fire_rate = 0.01
	var weapon: WeaponBase = WeaponBase.new()
	weapon.data = data
	weapon._current_ammo = 0
	_weapon_fired_count = 0
	weapon.fired.connect(func(_w: WeaponBase, _o: Vector2, _d: Vector2): _weapon_fired_count += 1)
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	_assert(_weapon_fired_count == 0, "should not fire when ammo is zero")
	_assert(weapon.get_current_ammo() == 0, "ammo should remain at zero")


func _test_weapon_reset_restores_ammo() -> void:
	var data: WeaponData = WeaponData.new()
	data.max_ammo = 10
	data.fire_rate = 0.01
	var weapon: WeaponBase = WeaponBase.new()
	weapon.data = data
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	weapon._process(0.02)
	weapon.reset()
	_assert(weapon.get_current_ammo() == 10, "reset should restore full ammo")
	_assert(weapon.can_fire(), "weapon should be ready after reset")


func _test_weapon_data_separate_from_movement() -> void:
	var data: WeaponData = WeaponData.new()
	_assert(data.weapon_id == "pistol", "weapon data has its own identity")
	_assert(data.fire_rate > 0.0, "weapon data stores fire rate")
	_assert(data.damage > 0.0, "weapon data stores damage")
	_assert(data.max_ammo >= 0, "weapon data stores ammo cap")


# --- S05 Shambler tests ---

var _shambler_state_changes: Array[StringName] = []

func _test_shambler_starts_idle() -> void:
	var shambler: Node = _load_shambler_scene()
	_shambler_state_changes.clear()
	shambler.state_changed.connect(func(s: StringName): _shambler_state_changes.append(s))
	_assert(shambler._state == &"idle", "shambler should start idle")
	shambler.queue_free()

func _test_noise_triggers_investigate() -> void:
	var shambler: Node = _load_shambler_scene()
	_shambler_state_changes.clear()
	shambler.state_changed.connect(func(s: StringName): _shambler_state_changes.append(s))
	shambler.receive_noise(Vector2(100, 0), 1.0)
	_assert(shambler._state == &"investigate", "noise should set investigate state")
	_assert(shambler._last_known_position == Vector2(100, 0), "last known position should be noise origin")
	_assert(shambler._noise_timer > 0.0, "noise timer should be active")
	shambler.queue_free()

func _test_noise_position_expires() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.noise_memory_duration = 0.1
	shambler.receive_noise(Vector2(100, 0), 1.0)
	shambler._physics_process(0.2)
	_assert(shambler._last_known_position == Vector2.ZERO, "last known position should expire")
	shambler.queue_free()

func _test_dead_enemy_ignores_noise() -> void:
	var shambler: Node = _load_shambler_scene()
	var health: HealthComponent = shambler.health_component
	health.take_damage(DamageInfo.new(100.0))
	shambler.receive_noise(Vector2(100, 0), 1.0)
	_assert(shambler._state == &"dead", "dead shambler should stay dead")
	shambler.queue_free()

func _test_shambler_dies_once() -> void:
	var shambler: Node = _load_shambler_scene()
	_shambler_death_count = 0
	shambler.health_component.died.connect(func(_info: DamageInfo): _shambler_death_count += 1)
	shambler.health_component.take_damage(DamageInfo.new(30.0))
	shambler.health_component._process(0.3)
	shambler.health_component.take_damage(DamageInfo.new(30.0))
	_assert(_shambler_death_count == 1, "death should emit exactly once")
	_assert(shambler._state == &"dead", "state should be dead")
	shambler.queue_free()

func _test_shambler_reset_clears_death() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.health_component.take_damage(DamageInfo.new(100.0))
	shambler.reset()
	_assert(not shambler.health_component.is_dead, "reset should clear death")
	_assert(shambler._state == &"idle", "reset should restore idle state")
	shambler.queue_free()

func _test_expired_position_causes_idle() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.noise_memory_duration = 0.1
	shambler.receive_noise(Vector2(100, 0), 1.0)
	_assert(shambler._state == &"investigate", "should investigate after noise")
	shambler._physics_process(0.2)
	_assert(shambler._state == &"idle", "should return to idle after position expires")
	shambler.queue_free()


func _test_sight_blocked_by_obstacle() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.global_position = Vector2(0, 0)
	shambler._sprite.scale = Vector2.ONE
	var obstacle: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(10, 40)
	obstacle.add_child(shape)
	obstacle.global_position = Vector2(25, 0)
	add_child(obstacle)
	var target: Node2D = Node2D.new()
	target.global_position = Vector2(50, 0)
	target.add_to_group("player")
	add_child(target)
	_assert(not shambler._has_clear_sight(target.global_position), "blocked sight should return false")
	obstacle.queue_free()
	target.queue_free()
	shambler.queue_free()

func _test_sight_outside_fov() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.global_position = Vector2(0, 0)
	shambler._sprite.scale = Vector2.ONE
	shambler.fov_degrees = 90.0
	shambler.sight_range = 200.0
	var target: Node2D = Node2D.new()
	target.global_position = Vector2(100, 100)
	target.add_to_group("player")
	add_child(target)
	_assert(not shambler._has_clear_sight(target.global_position), "target outside FOV should not be seen")
	target.queue_free()
	shambler.queue_free()

func _test_gunfire_starts_investigation() -> void:
	var weapon: Pistol = Pistol.new()
	weapon.add_to_group("weapon")
	weapon.data = WeaponData.new()
	add_child(weapon)
	var shambler: Node = _load_shambler_scene()
	weapon.fire(Vector2(100, 0), Vector2.RIGHT)
	_assert(shambler._state == &"investigate", "gunfire noise should set investigate state")
	_assert(shambler._last_known_position == Vector2(100, 0), "last known position should be gunshot origin")
	weapon.queue_free()
	shambler.queue_free()

func _test_sight_visible_to_player() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.global_position = Vector2(0, 0)
	shambler._sprite.scale = Vector2.ONE
	shambler.fov_degrees = 360.0
	shambler.sight_range = 200.0
	var target: StaticBody2D = StaticBody2D.new()
	target.global_position = Vector2(50, 0)
	target.add_to_group("player")
	target.collision_layer = 2
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(10, 40)
	target.add_child(shape)
	add_child(target)
	_assert(shambler._has_clear_sight(target.global_position), "visible target within range and FOV should be seen")
	shape.queue_free()
	target.queue_free()
	shambler.queue_free()

func _test_inactive_enemy_ignores_events() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.health_component.take_damage(DamageInfo.new(100.0))
	shambler.receive_noise(Vector2(100, 0), 1.0)
	_assert(shambler._state == &"dead", "dead shambler should stay dead after noise")
	shambler.queue_free()

func _load_shambler_scene() -> Node:
	var packed: PackedScene = load("res://scenes/enemies/shambler.tscn")
	var instance: Node = packed.instantiate()
	add_child(instance)
	return instance


# --- S05C integration tests ---

var _telegraph_fired: bool = false
var _telegraph_damage_applied: bool = false

func _test_pursuit_moves_toward_player() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.global_position = Vector2(0, 0)
	shambler._sprite.scale = Vector2.ONE
	shambler.sight_range = 200.0
	shambler.chase_speed = 100.0
	var player: Node2D = Node2D.new()
	player.global_position = Vector2(100, 0)
	player.add_to_group("player")
	add_child(player)
	var start_pos: Vector2 = shambler.global_position
	shambler._physics_process(0.1)
	_assert(shambler._state == &"chase", "shambler should chase visible player")
	shambler._physics_process(0.2)
	_assert(shambler.global_position.x > start_pos.x, "shambler should move toward player")
	player.queue_free()
	shambler.queue_free()


func _test_telegraph_before_attack() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.global_position = Vector2(0, 0)
	shambler._sprite.scale = Vector2.ONE
	shambler.attack_range = 100.0
	shambler.attack_damage = 10.0
	shambler.attack_telegraph_duration = 0.2
	_telegraph_fired = false
	_telegraph_damage_applied = false
	shambler.attack_telegraph_started.connect(func(): _telegraph_fired = true)
	var player: Node2D = Node2D.new()
	player.global_position = Vector2(30, 0)
	player.add_to_group("player")
	add_child(player)
	shambler._physics_process(0.1)
	_assert(shambler._state == &"attack_telegraph", "should enter telegraph state when in range")
	_assert(_telegraph_fired, "telegraph signal should fire")
	_assert(shambler._attack_timer > 0.0, "attack cooldown should be set after telegraph")
	shambler.queue_free()
	player.queue_free()


func _test_shambler_damages_player() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.global_position = Vector2(0, 0)
	shambler._sprite.scale = Vector2.ONE
	shambler.attack_range = 100.0
	shambler.attack_damage = 15.0
	var player: CharacterBody2D = CharacterBody2D.new()
	player.global_position = Vector2(30, 0)
	player.add_to_group("player")
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 100.0
	player.add_child(health)
	add_child(player)
	shambler._physics_process(0.1)
	_assert(shambler._state == &"attack_telegraph", "should telegraph first")
	shambler._telegraph_timer = 0.0
	shambler._physics_process(0.1)
	_assert(health.current_health < 100.0, "player should take damage from shambler attack")
	player.queue_free()
	shambler.queue_free()


func _test_pistol_kills_shambler() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.global_position = Vector2(0, 0)
	shambler._sprite.scale = Vector2.ONE
	var weapon: Pistol = Pistol.new()
	weapon.add_to_group("weapon")
	weapon.data = WeaponData.new()
	weapon.data.damage = 100.0
	weapon.data.fire_rate = 0.01
	weapon.data.max_ammo = -1
	add_child(weapon)
	_assert(not shambler.health_component.is_dead, "shambler should start alive")
	weapon.fire(shambler.global_position, Vector2.RIGHT)
	weapon._process(0.02)
	_assert(shambler.health_component.is_dead, "pistol shot should kill shambler")
	weapon.queue_free()
	shambler.queue_free()


