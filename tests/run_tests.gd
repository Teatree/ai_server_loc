extends Node

var _passed: int = 0
var _failed: int = 0
var _death_count: int = 0
var _shambler_death_count: int = 0
var _damaged_after_invulnerability: bool = false
var _damaged_after_death: bool = false
var _waiting_for_pistol: bool = false


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
	_test_pursuit_moves_toward_player()
	_test_telegraph_before_attack()
	_test_shambler_damages_player()
	_test_pistol_kills_shambler()
	_test_exit_zone_exists_in_level()
	_test_platforms_are_physically_distinct()
	_test_platforms_are_visually_distinct()
	_test_checkpoint_activates_and_respawns()
	_test_entry_to_exit_route_is_traversable()
	_test_moving_platform_follows_path()
	_test_hazard_damages_player_through_contract()
	_test_pickup_applies_once_and_cleans_up()
	_test_enemy_spawn_markers_are_categorized()
	_test_side_route_rejoins_safely()
	_test_integrated_arena_playability()
	set_process(true)

func _process(delta: float) -> void:
	if _waiting_for_pistol:
		_waiting_for_pistol = false
		set_process(false)
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
	shambler.free()

func _test_noise_triggers_investigate() -> void:
	var shambler: Node = _load_shambler_scene()
	_shambler_state_changes.clear()
	shambler.state_changed.connect(func(s: StringName): _shambler_state_changes.append(s))
	shambler.receive_noise(Vector2(100, 0), 1.0)
	_assert(shambler._state == &"investigate", "noise should set investigate state")
	_assert(shambler._last_known_position == Vector2(100, 0), "last known position should be noise origin")
	_assert(shambler._noise_timer > 0.0, "noise timer should be active")
	shambler.free()

func _test_noise_position_expires() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.noise_memory_duration = 0.1
	shambler.receive_noise(Vector2(100, 0), 1.0)
	shambler._physics_process(0.2)
	_assert(shambler._last_known_position == Vector2.ZERO, "last known position should expire")
	shambler.free()

func _test_dead_enemy_ignores_noise() -> void:
	var shambler: Node = _load_shambler_scene()
	var health: HealthComponent = shambler.health_component
	health.take_damage(DamageInfo.new(100.0))
	shambler.receive_noise(Vector2(100, 0), 1.0)
	_assert(shambler._state == &"dead", "dead shambler should stay dead")
	shambler.free()

func _test_shambler_dies_once() -> void:
	var shambler: Node = _load_shambler_scene()
	_shambler_death_count = 0
	shambler.health_component.died.connect(func(_info: DamageInfo): _shambler_death_count += 1)
	shambler.health_component.take_damage(DamageInfo.new(30.0))
	shambler.health_component._process(0.3)
	shambler.health_component.take_damage(DamageInfo.new(30.0))
	_assert(_shambler_death_count == 1, "death should emit exactly once")
	_assert(shambler._state == &"dead", "state should be dead")
	shambler.free()

func _test_shambler_reset_clears_death() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.health_component.take_damage(DamageInfo.new(100.0))
	shambler.reset()
	_assert(not shambler.health_component.is_dead, "reset should clear death")
	_assert(shambler._state == &"idle", "reset should restore idle state")
	shambler.free()

func _test_expired_position_causes_idle() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.noise_memory_duration = 0.1
	shambler.receive_noise(Vector2(100, 0), 1.0)
	_assert(shambler._state == &"investigate", "should investigate after noise")
	shambler._physics_process(0.2)
	_assert(shambler._state == &"idle", "should return to idle after position expires")
	shambler.free()


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
	obstacle.free()
	target.free()
	shambler.free()

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
	target.free()
	shambler.free()

func _test_gunfire_starts_investigation() -> void:
	var weapon: Pistol = Pistol.new()
	weapon.add_to_group("weapon")
	weapon.data = WeaponData.new()
	add_child(weapon)
	var shambler: Node = _load_shambler_scene()
	weapon.fire(Vector2(100, 0), Vector2.RIGHT)
	_assert(shambler._state == &"investigate", "gunfire noise should set investigate state")
	_assert(shambler._last_known_position == Vector2(100, 0), "last known position should be gunshot origin")
	weapon.free()
	shambler.free()

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
	shape.free()
	target.free()
	shambler.free()

func _test_inactive_enemy_ignores_events() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.health_component.take_damage(DamageInfo.new(100.0))
	shambler.receive_noise(Vector2(100, 0), 1.0)
	_assert(shambler._state == &"dead", "dead shambler should stay dead after noise")
	shambler.free()

func _load_shambler_scene() -> Node:
	var packed: PackedScene = load("res://scenes/enemies/shambler.tscn")
	var instance: Node = packed.instantiate()
	add_child(instance)
	return instance

func _create_test_player() -> CharacterBody2D:
	var player: CharacterBody2D = CharacterBody2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(30, 0)
	var health: HealthComponent = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = 100.0
	player.add_child(health)
	var script: GDScript = GDScript.new()
	script.source_code = "extends CharacterBody2D\n\nfunc take_damage(info: DamageInfo) -> void:\n\tvar h = get_node_or_null(\"HealthComponent\") as HealthComponent\n\tif h:\n\t\th.take_damage(info)\n\nfunc apply_knockback(velocity: Vector2, duration: float) -> void:\n\tpass"
	script.reload()
	player.set_script(script)
	add_child(player)
	return player


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
	_assert(shambler.velocity.x > 0.0, "shambler should have chase velocity toward player")
	player.free()
	shambler.free()


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
	shambler.free()
	player.free()


func _test_shambler_damages_player() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.global_position = Vector2(0, 0)
	shambler._sprite.scale = Vector2.ONE
	shambler.attack_range = 100.0
	shambler.attack_damage = 15.0
	var player: CharacterBody2D = _create_test_player()
	player.global_position = Vector2(30, 0)
	var health: HealthComponent = player.get_node("HealthComponent") as HealthComponent
	shambler._physics_process(0.1)
	_assert(shambler._state == &"attack_telegraph", "should telegraph first")
	shambler._telegraph_timer = 0.0
	shambler._physics_process(0.1)
	_assert(health.current_health < 100.0, "player should take damage from shambler attack")
	player.free()
	shambler.free()


func _test_pistol_kills_shambler() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler.global_position = Vector2(0, 0)
	shambler._sprite.scale = Vector2.ONE
	var data: WeaponData = WeaponData.new()
	data.damage = 100.0
	data.fire_rate = 0.01
	data.max_ammo = -1
	var weapon: Pistol = Pistol.new()
	weapon.add_to_group("weapon")
	weapon.data = data
	add_child(weapon)
	_assert(not shambler.health_component.is_dead, "shambler should start alive")
	weapon.fire(shambler.global_position, Vector2.RIGHT)
	var timer: Timer = Timer.new()
	timer.wait_time = 0.05
	timer.one_shot = true
	timer.timeout.connect(func():
		_assert(shambler.health_component.is_dead, "pistol shot should kill shambler")
		weapon.free()
		shambler.free()
		_waiting_for_pistol = true
	)
	add_child(timer)
	timer.start()


# --- S06A arena traversal and checkpoint tests ---

func _test_exit_zone_exists_in_level() -> void:
	var level: Node2D = _load_level_scene()
	var exit_zone: Area2D = level.get_node_or_null("ExitZone") as Area2D
	_assert(exit_zone != null, "level should contain an ExitZone node")
	var shape: CollisionShape2D = exit_zone.get_node_or_null("CollisionShape2D") as CollisionShape2D if exit_zone else null
	_assert(shape != null and shape.shape is RectangleShape2D, "ExitZone should have a RectangleShape2D")
	level.free()


func _test_platforms_are_physically_distinct() -> void:
	var level: Node2D = _load_level_scene()
	var static_bodies: Array[Node] = _find_nodes_by_type(level, "StaticBody2D")
	var one_way_areas: Array[Node] = _find_nodes_by_type(level, "Area2D")
	_assert(static_bodies.size() > 0, "level should have static body platforms")
	_assert(one_way_areas.size() > 0, "level should have one-way platform areas")
	var has_platform_layer: bool = false
	for area in one_way_areas:
		if area.name.begins_with("OneWay"):
			has_platform_layer = has_platform_layer or (area.collision_layer & 7) != 0
			var shapes: Array = _find_nodes_by_type(area, "CollisionShape2D")
			_assert(shapes.size() > 0, "one-way platform %s should have CollisionShape2D" % area.name)
	_assert(has_platform_layer, "one-way platforms should use the platforms physics layer (7)")
	for body in static_bodies:
		if body.name.begins_with("Ground") or body.name.begins_with("Elevated"):
			_assert(body.collision_layer == 1, "static platform %s should use world layer (1)" % body.name)
	level.free()


func _test_platforms_are_visually_distinct() -> void:
	var level: Node2D = _load_level_scene()
	var static_platforms: Array[Node] = []
	var one_way_platforms: Array[Node] = []
	for child in level.get_children():
		if child is StaticBody2D:
			static_platforms.append(child)
		elif child is Area2D and child.name.begins_with("OneWay"):
			one_way_platforms.append(child)
	_assert(static_platforms.size() > 0, "should have static platforms")
	_assert(one_way_platforms.size() > 0, "should have one-way platforms")
	var static_colors: Array[Color] = []
	for plat in static_platforms:
		var rect: ColorRect = plat.get_node_or_null("ColorRect") as ColorRect
		if rect:
			static_colors.append(rect.color)
	var one_way_colors: Array[Color] = []
	for plat in one_way_platforms:
		var rect: ColorRect = plat.get_node_or_null("ColorRect") as ColorRect
		if rect:
			one_way_colors.append(rect.color)
	_assert(static_colors.size() > 0 and one_way_colors.size() > 0, "both platform types should have color rects")
	var all_different: bool = true
	for sc in static_colors:
		for oc in one_way_colors:
			if sc == oc:
				all_different = false
	_assert(all_different, "static and one-way platform colors should be visually distinct")
	level.free()


func _test_checkpoint_activates_and_respawns() -> void:
	var level: Node2D = _load_level_scene()
	var checkpoint: Checkpoint = level.get_node_or_null("Checkpoint") as Checkpoint
	_assert(checkpoint != null, "level should contain a Checkpoint node")
	var player: CharacterBody2D = level.get_node_or_null("Player") as CharacterBody2D
	_assert(player != null, "level should contain a Player node")
	_assert(player.has_method("set_checkpoint"), "player should expose set_checkpoint")
	_assert(player.has_method("respawn"), "player should expose respawn")
	checkpoint.activated.emit(checkpoint.global_position)
	_assert(player._last_checkpoint == checkpoint.global_position, "checkpoint activation should update player respawn position")
	player.global_position = Vector2(9999, 9999)
	var mc: MovementController = MovementController.new()
	mc.body = player
	player.movement_controller = mc
	player.respawn()
	_assert(player.global_position == checkpoint.global_position, "respawn should teleport to checkpoint position")
	_assert(player._respawn_invulnerability > 0.0, "respawn should grant invulnerability")
	level.free()


func _test_entry_to_exit_route_is_traversable() -> void:
	var level: Node2D = _load_level_scene()
	var ground1: StaticBody2D = level.get_node_or_null("Ground1") as StaticBody2D
	var ground2: StaticBody2D = level.get_node_or_null("Ground2") as StaticBody2D
	var elev1: StaticBody2D = level.get_node_or_null("ElevatedPlatform1") as StaticBody2D
	var elev2: StaticBody2D = level.get_node_or_null("ElevatedPlatform2") as StaticBody2D
	var elev3: StaticBody2D = level.get_node_or_null("ElevatedPlatform3") as StaticBody2D
	var exit_zone: Area2D = level.get_node_or_null("ExitZone") as Area2D
	_assert(ground1 != null, "entry ground platform should exist")
	_assert(ground2 != null, "exit ground platform should exist")
	_assert(elev1 != null, "first elevated platform should exist")
	_assert(elev2 != null, "second elevated platform should exist")
	_assert(elev3 != null, "third elevated platform should exist")
	_assert(exit_zone != null, "exit zone should exist")
	var elev1_right := elev1.position.x + 100.0
	var elev2_right := elev2.position.x + 100.0
	var elev3_right := elev3.position.x + 100.0
	_assert(elev1_right <= elev2.position.x or elev2.position.y < elev1.position.y, "route should progress via elevation or rightward")
	_assert(elev2_right <= elev3.position.x or elev3.position.y < elev2.position.y, "route should progress via elevation or rightward")
	_assert(elev3.position.x < exit_zone.position.x, "exit should be reachable from final platform")
	level.free()


func _test_moving_platform_follows_path() -> void:
	var level: Node2D = _load_level_scene()
	var platform: MovingPlatform = level.get_node_or_null("MovingPlatform") as MovingPlatform
	_assert(platform != null, "level should contain a MovingPlatform")
	_assert(platform.waypoints.size() >= 2, "moving platform should have at least two waypoints")
	var start_pos: Vector2 = platform.position
	platform._physics_process(0.5)
	_assert(platform.position.distance_to(start_pos) > 0.0, "moving platform should change position")
	level.free()


func _test_hazard_damages_player_through_contract() -> void:
	var level: Node2D = _load_level_scene()
	var hazard: Hazard = level.get_node_or_null("Hazard") as Hazard
	_assert(hazard != null, "level should contain a Hazard")
	var player: CharacterBody2D = _create_test_player()
	player.global_position = hazard.global_position
	var health: HealthComponent = player.get_node("HealthComponent") as HealthComponent
	var initial_health: float = health.current_health
	hazard.body_entered.emit(player)
	_assert(health.current_health < initial_health, "hazard should reduce player health through DamageInfo")
	level.free()
	player.free()


func _test_pickup_applies_once_and_cleans_up() -> void:
	var level: Node2D = _load_level_scene()
	var pickup: Pickup = level.get_node_or_null("HealthPickup") as Pickup
	_assert(pickup != null, "level should contain a Pickup")
	var player: CharacterBody2D = _create_test_player()
	player.global_position = pickup.global_position
	var health: HealthComponent = player.get_node("HealthComponent") as HealthComponent
	health.take_damage(DamageInfo.new(30.0))
	var health_after_damage: float = health.current_health
	pickup.body_entered.emit(player)
	_assert(health.current_health > health_after_damage, "pickup should restore health")
	_assert(pickup._collected, "pickup should be marked collected")
	level.free()
	player.free()


func _test_enemy_spawn_markers_are_categorized() -> void:
	var level: Node2D = _load_level_scene()
	var shambler_a: Marker2D = level.get_node_or_null("EnemySpawnShambler_A") as Marker2D
	var shambler_b: Marker2D = level.get_node_or_null("EnemySpawnShambler_B") as Marker2D
	var ranged_a: Marker2D = level.get_node_or_null("EnemySpawnRanged_A") as Marker2D
	var shambler_c: Marker2D = level.get_node_or_null("EnemySpawnShambler_C") as Marker2D
	_assert(shambler_a != null, "level should have shambler spawn A")
	_assert(shambler_b != null, "level should have shambler spawn B")
	_assert(ranged_a != null, "level should have ranged spawn A")
	_assert(shambler_c != null, "level should have shambler spawn C")
	_assert(shambler_a.category == &"shambler", "shambler spawn A should be categorized")
	_assert(ranged_a.category == &"ranged", "ranged spawn A should be categorized")
	level.free()


func _test_side_route_rejoins_safely() -> void:
	var level: Node2D = _load_level_scene()
	var side_start: StaticBody2D = level.get_node_or_null("SideRouteStart") as StaticBody2D
	var side_mid: StaticBody2D = level.get_node_or_null("SideRouteMid") as StaticBody2D
	var side_rejoin: StaticBody2D = level.get_node_or_null("SideRouteRejoin") as StaticBody2D
	var exit_zone: Area2D = level.get_node_or_null("ExitZone") as Area2D
	_assert(side_start != null, "side route should have an entrance")
	_assert(side_mid != null, "side route should have a middle platform")
	_assert(side_rejoin != null, "side route should have a rejoin point")
	_assert(side_rejoin.position.y > exit_zone.position.y - 100.0, "rejoin should be above exit for safe descent")
	_assert(side_rejoin.position.x < exit_zone.position.x + 100.0, "rejoin should be within exit reach")
	level.free()


func _test_integrated_arena_playability() -> void:
	var level: Node2D = _load_level_scene()
	var player: CharacterBody2D = level.get_node_or_null("Player") as CharacterBody2D
	var checkpoint: Checkpoint = level.get_node_or_null("Checkpoint") as Checkpoint
	var hazard: Hazard = level.get_node_or_null("Hazard") as Hazard
	var pickup: Pickup = level.get_node_or_null("HealthPickup") as Pickup
	var exit_zone: Area2D = level.get_node_or_null("ExitZone") as Area2D
	var side_rejoin: StaticBody2D = level.get_node_or_null("SideRouteRejoin") as StaticBody2D
	_assert(player != null, "player should exist")
	_assert(checkpoint != null, "checkpoint should exist")
	_assert(hazard != null, "hazard should exist")
	_assert(pickup != null, "pickup should exist")
	_assert(exit_zone != null, "exit should exist")
	_assert(side_rejoin != null, "side route should rejoin critical path")
	_assert(player.has_method("respawn"), "player should support respawn")
	checkpoint.activated.emit(checkpoint.global_position)
	_assert(player._last_checkpoint == checkpoint.global_position, "checkpoint activation should set respawn point")
	player.global_position = Vector2(9999, 9999)
	var mc: MovementController = MovementController.new()
	mc.body = player
	player.movement_controller = mc
	player.respawn()
	_assert(player.global_position == checkpoint.global_position, "respawn should work after checkpoint")
	_assert(player._respawn_invulnerability > 0.0, "respawn should grant invulnerability")
	level.free()


func _load_level_scene() -> Node2D:
	var packed: PackedScene = load("res://scenes/levels/placeholder_level.tscn")
	var instance: Node2D = packed.instantiate()
	add_child(instance)
	return instance


func _find_nodes_by_type(parent: Node, type_name: String) -> Array[Node]:
	var result: Array[Node] = []
	_collect_nodes_by_type(parent, type_name, result)
	return result


func _collect_nodes_by_type(parent: Node, type_name: String, out: Array[Node]) -> void:
	for child in parent.get_children():
		if child.get_class() == type_name:
			out.append(child)
		_collect_nodes_by_type(child, type_name, out)


