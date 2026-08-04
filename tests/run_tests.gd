extends Node

const SaveSchema = preload("res://scripts/save/save_schema.gd")
const RIFLE_DATA_SCRIPT = preload("res://scripts/weapons/rifle_data.gd")
const AUTOMATIC_RIFLE_SCRIPT = preload("res://scripts/weapons/automatic_rifle.gd")
const MELEE_ATTACK_SCRIPT = preload("res://scripts/weapons/melee_attack.gd")
const MELEE_DATA_SCRIPT = preload("res://scripts/weapons/melee_data.gd")

var _passed: int = 0
var _failed: int = 0
var _death_count: int = 0
var _shambler_death_count: int = 0
var _damaged_after_invulnerability: bool = false
var _damaged_after_death: bool = false
var _waiting_for_pistol: bool = false
var _async_pending: int = 0


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
	_test_shotgun_emits_configured_pellet_count_and_spread()
	_test_shotgun_damage_knockback_ammo_cooldown_bounded()
	_test_shotgun_empty_magazine_behavior()
	_test_automatic_rifle_fires_at_cadence_when_held()
	_test_rifle_recoil_accumulates_and_recovers()
	_test_rifle_reload_and_switching_preserve_ammo()
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
	_test_reload_completes_once_and_transfers_bounded_ammo()
	_test_switching_blocks_during_reload()
	_test_switching_blocks_during_cooldown()
	_test_weapon_state_correct_after_respawn()
	_test_melee_respects_range_and_cooldown()
	_test_melee_cannot_damage_repeatedly_per_swing()
	_test_melee_interrupts_weak_enemy_without_corrupting_death()
	_test_melee_signal_emitted_on_hit()
	_test_all_weapons_expose_consistent_signals()
	_test_navigation_classifies_reachable()
	_test_navigation_classifies_jump()
	_test_navigation_classifies_drop()
	_test_navigation_classifies_blocked_and_unreachable()
	_test_enemy_traverses_jump_and_drop_links()
	_test_failed_links_trigger_bounded_stuck_recovery()
	_test_brute_starts_idle()
	_test_brute_telegraph_has_visible_pulse()
	_test_brute_stagger_resistance_reduces_knockback()
	_test_brute_attack_deals_heavy_damage()
	_test_brute_dies_once_using_shared_contract()
	_test_brute_reset_clears_death_and_state()
	_test_crowd_separation_prevents_exact_stacking()
	_test_crowd_separation_uses_gentle_impulse()
	_test_mixed_archetypes_retain_navigation_and_attack()
	_test_director_fixed_seed_reproduces_selection()
	_test_director_respects_threat_budget_cap()
	_test_director_respects_living_enemy_cap()
	_test_director_select_spawn_respects_caps()
	_test_director_rejects_too_close_spawn_to_player()
	_test_director_rejects_too_close_spawn_to_recent()
	_test_director_pressure_escalates_through_phases()
	_test_director_phase_and_spawn_reproduce_from_seed()
	_test_director_victory_emitted_after_all_phases()
	_test_director_victory_emitted_once()
	_test_director_reset_clears_victory_state()
	_test_level_restart_clears_enemies_and_director()
	_test_upgrades_apply_and_survive_respawn()
	_test_upgrade_stack_limit_enforced()
	_test_upgrade_mutual_exclusion_enforced()
	_test_chooser_fixed_seed_reproduces_same_three_choices()
	_test_chooser_excludes_maxed_and_conflicting_upgrades()
	_test_chooser_descriptions_expose_numerical_effects()
	_test_upgrade_ui_displays_three_choices()
	_test_upgrade_selection_applies_once_and_closes()
	_test_checkpoint_respawn_does_not_double_apply()
	_test_scene_reload_does_not_double_apply()
	_test_save_schema_has_explicit_version_and_stable_identifiers()
	_test_save_schema_missing_fields_fall_back_to_defaults()
	_test_save_schema_corrupt_health_is_repaired()
	_test_save_schema_unknown_fields_are_stripped()
	_test_save_schema_invalid_version_returns_empty_defaults()
	_test_save_schema_old_version_migrates_deterministically()
	_test_save_sanitizer_repairs_negative_ammo()
	_test_save_sanitizer_skips_unknown_version_fields()
	_test_save_schema_weapon_entry_requires_valid_identifier()
	_test_save_schema_upgrade_entry_requires_valid_identifier()
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


func _sanitize(raw: Dictionary) -> Dictionary:
	var sanitizer = preload("res://scripts/save/save_sanitizer.gd").new()
	return sanitizer.sanitize(raw)


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


# --- S07B Shotgun tests ---

func _test_shotgun_emits_configured_pellet_count_and_spread() -> void:
	var data: ShotgunData = ShotgunData.new()
	data.weapon_id = "shotgun"
	data.display_name = "Shotgun"
	data.pellet_count = 5
	data.spread_angle_degrees = 10.0
	data.fire_rate = 0.01
	data.max_ammo = -1
	var weapon: Shotgun = Shotgun.new()
	weapon.data = data
	add_child(weapon)

	var origin: Vector2 = Vector2(1000, 1000)
	var direction: Vector2 = Vector2.RIGHT
	var pellet_dirs: Array[Vector2] = []
	weapon.pellet_spawned.connect(func(o: Vector2, d: Vector2):
		pellet_dirs.append(d)
	)

	weapon.fire(origin, direction)

	_assert(pellet_dirs.size() == data.pellet_count,
		"shotgun should emit %d pellet signals, got %d" % [data.pellet_count, pellet_dirs.size()])

	for pellet_dir in pellet_dirs:
		var angle_diff: float = abs(pellet_dir.normalized().angle_to(direction))
		_assert(angle_diff <= deg_to_rad(data.spread_angle_degrees / 2.0),
			"pellet direction should be within %.1f degree spread cone" % (data.spread_angle_degrees / 2.0))

	weapon.free()


func _test_shotgun_damage_knockback_ammo_cooldown_bounded() -> void:
	var data: ShotgunData = ShotgunData.new()
	data.weapon_id = "shotgun"
	data.display_name = "Shotgun"
	data.pellet_count = 3
	data.spread_angle_degrees = 5.0
	data.fire_rate = 0.3
	data.max_ammo = 10
	data.reserve_ammo = 20
	data.ammo_per_shot = 1
	data.damage = 12.0
	data.knockback = 200.0
	var weapon: Shotgun = Shotgun.new()
	weapon.data = data
	add_child(weapon)

	var pellet_dirs: Array[Vector2] = []
	weapon.pellet_spawned.connect(func(_o: Vector2, d: Vector2): pellet_dirs.append(d))

	weapon.fire(Vector2.ZERO, Vector2.RIGHT)

	_assert(pellet_dirs.size() == data.pellet_count, "should emit pellet_count signals")
	_assert(weapon.get_current_ammo() == data.max_ammo - data.ammo_per_shot, "ammo should decrease by ammo_per_shot")
	_assert(not weapon.can_fire(), "should be on cooldown")
	weapon._process(0.35)
	_assert(weapon.can_fire(), "should be off cooldown after fire_rate")

	weapon.free()


func _test_shotgun_empty_magazine_behavior() -> void:
	var data: ShotgunData = ShotgunData.new()
	data.weapon_id = "shotgun"
	data.display_name = "Shotgun"
	data.pellet_count = 5
	data.spread_angle_degrees = 10.0
	data.fire_rate = 0.01
	data.max_ammo = 5
	data.reserve_ammo = 0
	var weapon: Shotgun = Shotgun.new()
	weapon.data = data
	weapon._current_ammo = 0

	var fired_count: int = 0
	weapon.fired.connect(func(_w: WeaponBase, _o: Vector2, _d: Vector2): fired_count += 1)
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	_assert(fired_count == 0, "should not fire when ammo is empty")
	_assert(weapon.get_current_ammo() == 0, "ammo should remain zero")

	weapon.free()


# --- S07C Automatic Rifle tests ---

func _test_automatic_rifle_fires_at_cadence_when_held() -> void:
	var data: WeaponData = RIFLE_DATA_SCRIPT.new()
	data.fire_rate = 0.1
	data.max_ammo = 10
	data.reserve_ammo = 20
	data.automatic = true
	var weapon: WeaponBase = AUTOMATIC_RIFLE_SCRIPT.new()
	weapon.data = data
	add_child(weapon)

	_assert(data.automatic, "rifle data should be marked automatic")

	var initial_ammo: int = weapon.get_current_ammo()
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	weapon._process(0.1)
	_assert(weapon.get_current_ammo() == initial_ammo - 1, "rifle should fire once after fire_rate")

	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	weapon._process(0.1)
	_assert(weapon.get_current_ammo() == initial_ammo - 2, "rifle should fire twice at cadence")

	weapon._process(0.05)
	_assert(weapon.get_current_ammo() == initial_ammo - 2, "rifle should not fire before cooldown expires")

	weapon.free()


func _test_rifle_recoil_accumulates_and_recovers() -> void:
	var data: WeaponData = RIFLE_DATA_SCRIPT.new()
	data.fire_rate = 0.01
	data.max_ammo = -1
	data.recoil_kick = 5.0
	data.recoil_recovery = 10.0
	var weapon: WeaponBase = AUTOMATIC_RIFLE_SCRIPT.new()
	weapon.data = data
	add_child(weapon)

	_assert(weapon.get_recoil() == 0.0, "recoil should start at zero")
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	_assert(weapon.get_recoil() == 5.0, "recoil should increase by kick after first shot")
	weapon._process(0.1)
	_assert(weapon.get_recoil() == 4.0, "recoil should recover over time")
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	_assert(weapon.get_recoil() == 9.0, "recoil should accumulate with second shot")
	weapon._process(0.5)
	_assert(weapon.get_recoil() == 4.0, "recoil should recover over longer time")
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
	weapon._process(0.02)
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	_assert(weapon.get_recoil() >= 0.0, "recoil should remain non-negative")
	var limit: float = data.recoil_kick * 10.0
	_assert(weapon.get_recoil() <= limit, "recoil should not exceed configured limit")

	weapon._process(6.0)
	_assert(weapon.get_recoil() == 0.0, "recoil should fully recover after enough time")

	weapon.free()


func _test_rifle_reload_and_switching_preserve_ammo() -> void:
	var data: WeaponData = RIFLE_DATA_SCRIPT.new()
	data.max_ammo = 30
	data.reserve_ammo = 60
	data.fire_rate = 0.01
	var data_b: WeaponData = RIFLE_DATA_SCRIPT.new()
	data_b.weapon_id = "rifle_2"
	data_b.display_name = "Rifle 2"
	data_b.max_ammo = 20
	data_b.reserve_ammo = 40
	data_b.fire_rate = 0.01
	var player: CharacterBody2D = _create_inventory_player([data, data_b])
	var original_weapon: WeaponBase = player._weapon_pivot as WeaponBase
	var rifle: WeaponBase = AUTOMATIC_RIFLE_SCRIPT.new()
	rifle.name = "WeaponPivot"
	add_child(rifle)
	player._weapon_pivot = rifle
	rifle.data = data
	rifle.reset()

	for i in range(5):
		rifle.fire(Vector2.ZERO, Vector2.RIGHT)
		rifle._process(0.02)
	_assert(rifle.get_current_ammo() == 25, "rifle should have 25 rounds after 5 shots")
	_assert(rifle.get_reserve_ammo() == 60, "reserve should be untouched before reload")

	rifle.reload()
	_assert(rifle.get_current_ammo() == 30, "reload should refill magazine")
	_assert(rifle.get_reserve_ammo() == 55, "reload should transfer 5 rounds")

	var switched: bool = player._try_switch_weapon()
	_assert(switched, "switch should work when not reloading or on cooldown")
	_assert(player._current_weapon_index == 1, "weapon index should change")
	_assert(rifle.get_current_ammo() >= 0, "rifle ammo should remain valid after switch")
	_assert(rifle.get_reserve_ammo() >= 0, "rifle reserve should remain valid after switch")

	original_weapon.free()
	rifle.free()
	player.free()


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
	var body: StaticBody2D = StaticBody2D.new()
	body.add_to_group("player")
	body.collision_layer = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(10, 40)
	body.add_child(shape)
	player.add_child(body)
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
	timer.wait_time = 0.2
	timer.one_shot = true
	_async_pending += 1
	timer.timeout.connect(func():
		_assert(shambler.health_component.is_dead, "pistol shot should kill shambler")
		weapon.free()
		shambler.free()
		_async_pending -= 1
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


# --- S07A inventory, reload, and switching tests ---

# --- S07D melee and weapon integration tests ---

func _test_melee_respects_range_and_cooldown() -> void:
	var melee: Node = load("res://scripts/weapons/melee_attack.gd").new()
	add_child(melee)
	melee.set_process(true)
	var data: WeaponData = load("res://scripts/weapons/melee_data.gd").new()
	data.melee_range = 50.0
	data.melee_cooldown = 0.3
	_assert(melee.can_melee(), "melee should be ready initially")
	melee.attack(Vector2.ZERO, 1, data)
	_assert(not melee.can_melee(), "melee should be on cooldown after attack")
	melee._process(0.2)
	_assert(not melee.can_melee(), "melee should still be on cooldown at 0.2s")
	melee._process(0.15)
	_assert(melee.can_melee(), "melee should be ready after cooldown expires")
	melee.free()


var _melee_signal_test_received: bool = false

func _on_melee_signal_test(_t: Node, _d: float, _k: float) -> void:
	_melee_signal_test_received = true

func _test_melee_signal_emitted_on_hit() -> void:
	var melee: Node = load("res://scripts/weapons/melee_attack.gd").new()
	add_child(melee)
	_melee_signal_test_received = false
	melee.melee_hit.connect(Callable(self, "_on_melee_signal_test"))
	melee.melee_hit.emit(null, 0.0, 0.0)
	_assert(_melee_signal_test_received, "melee_hit signal should be receivable")
	melee.free()

func _test_melee_cannot_damage_repeatedly_per_swing() -> void:
	var melee: Node = load("res://scripts/weapons/melee_attack.gd").new()
	add_child(melee)
	melee.set_process(true)
	var data: WeaponData = load("res://scripts/weapons/melee_data.gd").new()
	data.melee_range = 100.0
	data.melee_cooldown = 0.3
	var enemy: StaticBody2D = StaticBody2D.new()
	enemy.add_to_group("enemy")
	enemy.global_position = Vector2(20, 0)
	enemy.collision_layer = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(10, 40)
	enemy.add_child(shape)
	add_child(enemy)
	melee.attack(Vector2.ZERO, 1, data)
	melee._process(0.1)
	_assert(melee._hit_bodies.size() == 1, "initial scan should register one hit target, got %d" % melee._hit_bodies.size())
	_assert(melee._scanned_bodies.size() == 1, "initial scan should track scanned target")
	melee._on_body_entered(enemy)
	melee._on_body_entered(enemy)
	_assert(melee._hit_bodies.size() == 1, "body should not be re-added after initial scan")
	melee.end_swing()
	_assert(melee._hit_bodies.size() == 0, "end_swing should clear hit bodies")
	_assert(melee._scanned_bodies.size() == 0, "end_swing should clear scanned bodies")
	melee._process(0.35)
	melee.attack(Vector2.ZERO, 1, data)
	melee._process(0.1)
	_assert(melee._scanned_bodies.size() == 1 or melee._hit_bodies.size() == 1,
		"second swing should detect enemy again via scan or physics, hit=%d scanned=%d" % [melee._hit_bodies.size(), melee._scanned_bodies.size()])
	melee.free()
	enemy.free()


func _test_melee_interrupts_weak_enemy_without_corrupting_death() -> void:
	var shambler: Node = _load_shambler_scene()
	shambler._set_state(&"attack_telegraph")
	var melee: Node = load("res://scripts/weapons/melee_attack.gd").new()
	add_child(melee)
	melee.set_process(true)
	melee.melee_hit.connect(func(_t: Node, _d: float, _k: float) -> void:
		if shambler.has_method("interrupt"):
			shambler.interrupt()
	)
	var data: WeaponData = load("res://scripts/weapons/melee_data.gd").new()
	data.melee_range = 100.0
	data.melee_damage = 5.0
	data.melee_knockback = 100.0
	shambler.global_position = Vector2(20, 0)
	melee.attack(Vector2.ZERO, 1, data)
	melee._process(0.1)
	_assert(melee._hit_bodies.size() == 1, "melee scan should detect shambler, got %d" % melee._hit_bodies.size())
	_assert(shambler._state == &"chase", "melee should interrupt telegraph state via signal, got %s" % shambler._state)
	shambler.health_component.take_damage(DamageInfo.new(100.0))
	_assert(shambler._state == &"dead", "shambler should be dead after lethal damage")
	melee.attack(Vector2.ZERO, 1, data)
	melee._process(0.1)
	melee._on_body_entered(shambler)
	_assert(shambler._state == &"dead", "melee should not corrupt dead state, got %s" % shambler._state)
	melee.free()
	shambler.free()


func _test_all_weapons_expose_consistent_signals() -> void:
	var signals_array: Array[StringName] = [
		&"fired",
		&"dry_fire",
		&"ammo_changed",
		&"state_changed",
		&"noise_emitted",
		&"reload_completed",
		&"equipped"
	]
	for signal_name in signals_array:
		var data: WeaponData = WeaponData.new()
		var weapon: WeaponBase = WeaponBase.new()
		weapon.data = data
		_assert(weapon.has_signal(signal_name), "weapon should expose %s signal" % signal_name)
		weapon.free()


# --- S07A inventory, reload, and switching tests ---

func _test_reload_completes_once_and_transfers_bounded_ammo() -> void:
	var data: WeaponData = WeaponData.new()
	data.max_ammo = 10
	data.reserve_ammo = 20
	data.fire_rate = 0.01
	var weapon: WeaponBase = WeaponBase.new()
	weapon.data = data
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	weapon._process(0.02)
	_assert(weapon.get_current_ammo() == 9, "should have consumed one round")
	_assert(weapon.get_reserve_ammo() == 20, "reserve should be untouched before reload")
	weapon.reload()
	_assert(weapon.get_current_ammo() == 10, "reload should refill magazine")
	_assert(weapon.get_reserve_ammo() == 19, "reload should transfer exactly one round from reserve")
	weapon.reload()
	_assert(weapon.get_current_ammo() == 10, "reload should not run when magazine full")
	_assert(weapon.get_reserve_ammo() == 19, "reserve should not change when magazine full")


func _test_switching_blocks_during_reload() -> void:
	var data_a: WeaponData = WeaponData.new()
	data_a.max_ammo = 10
	data_a.reserve_ammo = 10
	data_a.fire_rate = 0.01
	var data_b: WeaponData = WeaponData.new()
	data_b.weapon_id = "rifle"
	data_b.display_name = "Rifle"
	data_b.max_ammo = 20
	data_b.reserve_ammo = 40
	data_b.fire_rate = 0.01
	var player: CharacterBody2D = _create_inventory_player([data_a, data_b])
	var weapon: WeaponBase = player._weapon_pivot as WeaponBase
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	weapon._process(0.02)
	weapon.reload()
	_assert(not weapon._reloading, "weapon should finish reload synchronously")
	var switched: bool = player._try_switch_weapon()
	_assert(switched, "switch should work after reload completes")
	_assert(player._current_weapon_index == 1, "weapon index should change")


func _test_switching_blocks_during_cooldown() -> void:
	var data_a: WeaponData = WeaponData.new()
	data_a.max_ammo = 10
	data_a.reserve_ammo = 10
	data_a.fire_rate = 0.3
	var data_b: WeaponData = WeaponData.new()
	data_b.weapon_id = "rifle"
	data_b.display_name = "Rifle"
	data_b.max_ammo = 20
	data_b.reserve_ammo = 40
	data_b.fire_rate = 0.3
	var player: CharacterBody2D = _create_inventory_player([data_a, data_b])
	var weapon: WeaponBase = player._weapon_pivot as WeaponBase
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	_assert(not weapon.can_fire(), "weapon should be on cooldown")
	var switched: bool = player._try_switch_weapon()
	_assert(not switched, "switch should be blocked during cooldown")
	_assert(player._current_weapon_index == 0, "weapon index should not change")


func _test_weapon_state_correct_after_respawn() -> void:
	var data: WeaponData = WeaponData.new()
	data.max_ammo = 12
	data.reserve_ammo = 60
	data.fire_rate = 0.01
	var player: CharacterBody2D = _create_inventory_player([data])
	var weapon: WeaponBase = player._weapon_pivot as WeaponBase
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	weapon._process(0.02)
	weapon.fire(Vector2.ZERO, Vector2.RIGHT)
	weapon._process(0.02)
	_assert(weapon.get_current_ammo() == 10, "ammo should be reduced before respawn")
	_assert(weapon.get_reserve_ammo() == 60, "reserve should be untouched before respawn")
	player.global_position = Vector2(9999, 9999)
	var mc: MovementController = MovementController.new()
	mc.body = player
	var config: MovementConfig = load("res://resources/movement/movement_config.tres") as MovementConfig
	mc.config = config
	player.movement_controller = mc
	player.respawn()
	_assert(weapon.get_current_ammo() == data.max_ammo, "current ammo should reset to max after respawn")
	_assert(weapon.get_reserve_ammo() == data.reserve_ammo, "reserve ammo should reset after respawn")
	_assert(weapon.can_fire(), "weapon should be ready after respawn")
	player.free()


func _create_inventory_player(inventory: Array[WeaponData]) -> CharacterBody2D:
	var player: CharacterBody2D = CharacterBody2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(0, 0)
	var health: HealthComponent = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = 100.0
	player.add_child(health)
	var player_script: GDScript = load("res://scripts/player/player.gd") as GDScript
	if player_script:
		player.set_script(player_script)
	var weapon: WeaponBase = Pistol.new()
	weapon.name = "WeaponPivot"
	add_child(weapon)
	player._weapon_pivot = weapon
	player._weapon_inventory = inventory
	player._current_weapon_index = 0
	if inventory.size() > 0:
		weapon.data = inventory[0]
		weapon.reset()
	return player


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


# --- S08B Runner tests ---

var _runner_state_changes: Array[StringName] = []

func _load_runner_scene() -> Node:
	var packed: PackedScene = load("res://scenes/enemies/runner.tscn")
	var instance: Node = packed.instantiate()
	add_child(instance)
	return instance

func _test_runner_starts_idle() -> void:
	var runner: Node = _load_runner_scene()
	_assert(runner._state == &"idle", "runner should start idle")
	runner.free()

func _test_runner_chase_speed_is_faster_than_shambler() -> void:
	var runner: Node = _load_runner_scene()
	_assert(runner.chase_speed > 150.0, "runner chase speed should be faster than shambler baseline, got %f" % runner.chase_speed)
	runner.free()

func _test_runner_has_distinct_states() -> void:
	var runner: Node = _load_runner_scene()
	var has_telegraph: bool = runner.has_method("_start_lunge")
	_assert(has_telegraph, "runner should have distinct lunge attack path")
	runner.free()

func _test_runner_telegraph_has_visible_flash() -> void:
	var runner: Node = _load_runner_scene()
	runner.global_position = Vector2(0, 0)
	runner._sprite.scale = Vector2.ONE
	runner.lunge_damage_radius = 100.0
	runner.attack_cooldown = 0.01
	runner.telegraph_duration = 0.2
	var player: Node2D = Node2D.new()
	player.global_position = Vector2(20, 0)
	player.add_to_group("player")
	add_child(player)
	runner._physics_process(0.1)
	_assert(runner._state == &"telegraph", "runner should enter telegraph state when in lunge range")
	_assert(runner._sprite.modulate != runner._base_modulate, "runner sprite should flash during telegraph")
	player.free()
	runner.free()

func _test_runner_telegraph_signal_fires() -> void:
	var runner: Node = _load_runner_scene()
	runner.global_position = Vector2(0, 0)
	runner._sprite.scale = Vector2.ONE
	runner.lunge_damage_radius = 100.0
	runner.attack_cooldown = 0.01
	runner.telegraph_duration = 0.2
	var signal_fired: bool = false
	runner.attack_telegraph_started.connect(func(): signal_fired = true)
	var player: Node2D = Node2D.new()
	player.global_position = Vector2(20, 0)
	player.add_to_group("player")
	add_child(player)
	runner._physics_process(0.1)
	_assert(signal_fired, "attack_telegraph_started signal should fire in telegraph state")
	player.free()
	runner.free()

func _test_runner_lunge_deals_damage() -> void:
	var runner: Node = _load_runner_scene()
	runner.global_position = Vector2(0, 0)
	runner._sprite.scale = Vector2.ONE
	runner.lunge_damage_radius = 200.0
	runner.attack_cooldown = 0.01
	runner.telegraph_duration = 0.1
	runner.lunge_duration = 0.2
	runner.lunge_speed = 500.0
	runner.attack_damage = 15.0
	var player: CharacterBody2D = _create_test_player()
	player.global_position = Vector2(30, 0)
	var health: HealthComponent = player.get_node("HealthComponent") as HealthComponent
	runner._physics_process(0.1)
	_assert(runner._state == &"telegraph", "runner should telegraph first")
	runner._telegraph_timer = 0.0
	runner._physics_process(0.1)
	_assert(runner._state == &"lunge", "runner should enter lunge state after telegraph")
	runner._lunge_timer = 0.0
	runner._physics_process(0.1)
	_assert(health.current_health < 100.0, "lunge should damage player")
	player.free()
	runner.free()

func _test_runner_dies_once_using_shared_contract() -> void:
	var runner: Node = _load_runner_scene()
	var death_count: int = 0
	runner.health_component.died.connect(func(_info: DamageInfo): death_count += 1)
	runner.health_component.take_damage(DamageInfo.new(50.0))
	runner.health_component.take_damage(DamageInfo.new(10.0))
	_assert(death_count == 1, "runner death should emit exactly once via HealthComponent")
	_assert(runner._state == &"dead", "runner state should be dead")
	runner.free()

func _test_runner_reset_clears_death_and_state() -> void:
	var runner: Node = _load_runner_scene()
	runner.health_component.take_damage(DamageInfo.new(50.0))
	runner.reset()
	_assert(not runner.health_component.is_dead, "reset should clear death via HealthComponent")
	_assert(runner._state == &"idle", "reset should restore idle state")
	runner.free()

func _test_runner_perception_reuses_noise_contract() -> void:
	var runner: Node = _load_runner_scene()
	runner.noise_memory_duration = 0.1
	runner.receive_noise(Vector2(100, 0), 1.0)
	_assert(runner._state == &"investigate", "runner should investigate on noise")
	_assert(runner._last_known_position == Vector2(100, 0), "runner should store noise origin")
	runner._physics_process(0.2)
	_assert(runner._last_known_position == Vector2.ZERO, "runner noise position should expire")
	runner.free()

func _test_runner_navigation_uses_enemy_navigator() -> void:
	var runner: Node = _load_runner_scene()
	var navigator: Node = runner.get_node("EnemyNavigator")
	_assert(navigator != null, "runner should have EnemyNavigator node")
	_assert(navigator is Node2D, "navigator should be Node2D")
	runner.free()

# --- S08A authored platform navigation tests ---

func _test_navigation_classifies_reachable() -> void:
	var PlatformGraph = load("res://scripts/navigation/platform_graph.gd")
	var PlatformNode = load("res://scripts/navigation/platform_node.gd")
	var PlatformLink = load("res://scripts/navigation/platform_link.gd")
	var graph = PlatformGraph.new()
	var a = PlatformNode.new(&"plat_a", Vector2(0, 100))
	var b = PlatformNode.new(&"plat_b", Vector2(60, 100))
	graph.add_node(a)
	graph.add_node(b)
	graph.add_link(a, b, PlatformLink.LinkType.REACHABLE)
	_assert(graph.classify_target(a, b) == PlatformLink.LinkType.REACHABLE,
		"close same-level nodes should be reachable")
	graph.free()

func _test_navigation_classifies_jump() -> void:
	var PlatformGraph = load("res://scripts/navigation/platform_graph.gd")
	var PlatformNode = load("res://scripts/navigation/platform_node.gd")
	var PlatformLink = load("res://scripts/navigation/platform_link.gd")
	var graph = PlatformGraph.new()
	var a = PlatformNode.new(&"plat_a", Vector2(0, 200))
	var b = PlatformNode.new(&"plat_b", Vector2(50, 120))
	graph.add_node(a)
	graph.add_node(b)
	graph.add_link(a, b, PlatformLink.LinkType.JUMP)
	_assert(graph.classify_target(a, b) == PlatformLink.LinkType.JUMP,
		"higher target should classify as jump")
	graph.free()

func _test_navigation_classifies_drop() -> void:
	var PlatformGraph = load("res://scripts/navigation/platform_graph.gd")
	var PlatformNode = load("res://scripts/navigation/platform_node.gd")
	var PlatformLink = load("res://scripts/navigation/platform_link.gd")
	var graph = PlatformGraph.new()
	var a = PlatformNode.new(&"plat_a", Vector2(0, 100))
	var b = PlatformNode.new(&"plat_b", Vector2(50, 200))
	graph.add_node(a)
	graph.add_node(b)
	graph.add_link(a, b, PlatformLink.LinkType.DROP)
	_assert(graph.classify_target(a, b) == PlatformLink.LinkType.DROP,
		"lower target should classify as drop")
	graph.free()

func _test_navigation_classifies_blocked_and_unreachable() -> void:
	var PlatformGraph = load("res://scripts/navigation/platform_graph.gd")
	var PlatformNode = load("res://scripts/navigation/platform_node.gd")
	var PlatformLink = load("res://scripts/navigation/platform_link.gd")
	var graph = PlatformGraph.new()
	var a = PlatformNode.new(&"plat_a", Vector2(0, 100))
	var b = PlatformNode.new(&"plat_b", Vector2(300, 100))
	var c = PlatformNode.new(&"plat_c", Vector2(50, 350))
	graph.add_node(a)
	graph.add_node(b)
	graph.add_node(c)
	graph.add_link(a, b, PlatformLink.LinkType.BLOCKED)
	_assert(graph.classify_target(a, b) == PlatformLink.LinkType.BLOCKED,
		"far same-level target should be blocked")
	_assert(graph.classify_target(a, c) == PlatformLink.LinkType.UNREACHABLE,
		"excessive vertical gap should be unreachable")
	graph.free()

func _test_enemy_traverses_jump_and_drop_links() -> void:
	var PlatformGraph = load("res://scripts/navigation/platform_graph.gd")
	var PlatformNode = load("res://scripts/navigation/platform_node.gd")
	var PlatformLink = load("res://scripts/navigation/platform_link.gd")
	var EnemyNavigator = load("res://scripts/navigation/enemy_navigator.gd")
	var graph = PlatformGraph.new()
	var ground = PlatformNode.new(&"ground", Vector2(0, 200))
	var mid = PlatformNode.new(&"mid", Vector2(80, 120))
	var low = PlatformNode.new(&"low", Vector2(80, 220))
	graph.add_node(ground)
	graph.add_node(mid)
	graph.add_node(low)
	graph.add_link(ground, mid, PlatformLink.LinkType.JUMP)
	graph.add_link(mid, low, PlatformLink.LinkType.DROP)
	var body: CharacterBody2D = CharacterBody2D.new()
	body.global_position = ground.position
	add_child(body)
	var navigator = EnemyNavigator.new()
	navigator.set_graph(graph)
	navigator.set_body(body)
	add_child(navigator)
	_assert(navigator.request_jump_to(mid), "jump request should succeed")
	_assert(navigator.is_navigating(), "navigator should be traversing after jump request")
	_assert(navigator.get_state() == &"traversing", "state should be traversing")
	_assert(navigator.get_target_node() == mid, "target should be mid platform")
	_assert(navigator.request_drop_to(low), "drop request should succeed after reaching mid")
	_assert(navigator.get_target_node() == low, "target should be low platform")
	navigator.free()
	body.free()
	graph.free()

func _test_failed_links_trigger_bounded_stuck_recovery() -> void:
	var PlatformGraph = load("res://scripts/navigation/platform_graph.gd")
	var PlatformNode = load("res://scripts/navigation/platform_node.gd")
	var PlatformLink = load("res://scripts/navigation/platform_link.gd")
	var EnemyNavigator = load("res://scripts/navigation/enemy_navigator.gd")
	var graph = PlatformGraph.new()
	graph.max_stuck_retries = 2
	var ground = PlatformNode.new(&"ground", Vector2(0, 200))
	var blocked = PlatformNode.new(&"blocked", Vector2(500, 200))
	graph.add_node(ground)
	graph.add_node(blocked)
	graph.add_link(ground, blocked, PlatformLink.LinkType.BLOCKED)
	var body: CharacterBody2D = CharacterBody2D.new()
	body.global_position = ground.position
	add_child(body)
	var navigator = EnemyNavigator.new()
	navigator.set_graph(graph)
	navigator.set_body(body)
	add_child(navigator)
	_assert(not navigator.request_jump_to(blocked), "first jump to blocked node should fail")
	_assert(navigator.get_state() == &"stuck", "navigator should be stuck after failed traversal")
	navigator.request_recovery()
	_assert(navigator.get_state() == &"idle", "recovery should reset state to idle without infinite retries")
	_assert(graph._stuck_count == 0, "graph stuck count should be zero after bounded recovery")
	navigator.free()
	body.free()
	graph.free()


# --- S08C Spitter tests ---

func _test_spitter_starts_idle() -> void:
	var spitter: Node = load("res://scenes/enemies/spitter.tscn").instantiate()
	add_child(spitter)
	_assert(spitter._state == &"idle", "spitter should start idle")
	spitter.free()

func _test_spitter_telegraphs_before_attack() -> void:
	var spitter: Node = load("res://scenes/enemies/spitter.tscn").instantiate()
	add_child(spitter)
	spitter.global_position = Vector2(0, 0)
	spitter._sprite.scale = Vector2.ONE
	spitter.attack_range = 200.0
	spitter.attack_telegraph_duration = 0.2
	var signal_fired: bool = false
	spitter.attack_telegraph_started.connect(func(): signal_fired = true)
	var player: Node2D = Node2D.new()
	player.global_position = Vector2(30, 0)
	player.add_to_group("player")
	add_child(player)
	spitter._physics_process(0.1)
	_assert(spitter._state == &"telegraph", "spitter should enter telegraph when in range")
	_assert(signal_fired, "telegraph signal should fire")
	spitter.free()
	player.free()

func _test_spitter_maintains_range() -> void:
	var spitter: Node = load("res://scenes/enemies/spitter.tscn").instantiate()
	add_child(spitter)
	spitter.global_position = Vector2(0, 0)
	spitter._sprite.scale = Vector2.ONE
	spitter.attack_range = 100.0
	spitter.attack_cooldown = 0.01
	var player: Node2D = Node2D.new()
	player.global_position = Vector2(150, 0)
	player.add_to_group("player")
	add_child(player)
	spitter._physics_process(0.1)
	_assert(spitter._state == &"chase", "spitter should chase when player is outside attack range")
	spitter.free()
	player.free()

func _test_spitter_attack_cooldown_prevents_spam() -> void:
	var spitter: Node = load("res://scenes/enemies/spitter.tscn").instantiate()
	add_child(spitter)
	spitter.global_position = Vector2(0, 0)
	spitter._sprite.scale = Vector2.ONE
	spitter.attack_range = 200.0
	spitter.attack_cooldown = 0.5
	spitter.attack_telegraph_duration = 0.1
	var player: Node2D = Node2D.new()
	player.global_position = Vector2(30, 0)
	player.add_to_group("player")
	add_child(player)
	spitter._physics_process(0.1)
	_assert(spitter._state == &"telegraph", "should telegraph first")
	spitter._telegraph_timer = 0.0
	spitter._physics_process(0.1)
	_assert(spitter._state == &"attack_cooldown", "should enter cooldown after attack")
	spitter._attack_timer = 0.3
	spitter._physics_process(0.1)
	_assert(spitter._state == &"attack_cooldown", "should remain in cooldown while timer active")
	spitter.free()
	player.free()

func _test_spitter_projectile_has_shared_damage_ownership() -> void:
	var spitter: Node = load("res://scenes/enemies/spitter.tscn").instantiate()
	add_child(spitter)
	spitter.global_position = Vector2(0, 0)
	spitter._sprite.scale = Vector2.ONE
	spitter.attack_range = 200.0
	spitter.attack_telegraph_duration = 0.1
	spitter.attack_damage = 15.0
	spitter.projectile_speed = 300.0
	var player: Node2D = Node2D.new()
	player.global_position = Vector2(30, 0)
	player.add_to_group("player")
	add_child(player)
	spitter._physics_process(0.1)
	_assert(spitter._state == &"telegraph", "should telegraph first")
	spitter._telegraph_timer = 0.0
	spitter._physics_process(0.1)
	var projectiles: Array[Node] = get_tree().get_nodes_in_group("projectile")
	var enemy_projectile: Projectile = null
	for p in projectiles:
		if p.source == spitter:
			enemy_projectile = p as Projectile
			break
	_assert(enemy_projectile != null, "spitter projectile should exist with spitter as source")
	_assert(enemy_projectile.damage == 15.0, "projectile should carry spitter damage value")
	if enemy_projectile:
		enemy_projectile.queue_free()
	spitter.free()
	player.free()

func _test_spitter_projectile_cleans_up_after_hit() -> void:
	var spitter: Node = load("res://scenes/enemies/spitter.tscn").instantiate()
	add_child(spitter)
	spitter.global_position = Vector2(0, 0)
	spitter._sprite.scale = Vector2.ONE
	spitter.attack_range = 200.0
	spitter.attack_telegraph_duration = 0.1
	var player: Node2D = Node2D.new()
	player.global_position = Vector2(30, 0)
	player.add_to_group("player")
	add_child(player)
	spitter._physics_process(0.1)
	spitter._telegraph_timer = 0.0
	spitter._physics_process(0.1)
	var projectiles: Array[Node] = get_tree().get_nodes_in_group("projectile")
	var enemy_projectile: Projectile = null
	for p in projectiles:
		if p.source == spitter:
			enemy_projectile = p as Projectile
			break
	_assert(enemy_projectile != null, "projectile should be spawned")
	var was_alive: bool = is_instance_valid(enemy_projectile)
	enemy_projectile.body_entered.emit(player)
	await get_tree().process_frame
	_assert(not is_instance_valid(enemy_projectile), "projectile should queue_free after hitting body")
	spitter.free()
	player.free()

func _test_spitter_blocked_los_prevents_ranged_damage() -> void:
	var spitter: Node = load("res://scenes/enemies/spitter.tscn").instantiate()
	add_child(spitter)
	spitter.global_position = Vector2(0, 0)
	spitter._sprite.scale = Vector2.ONE
	spitter.attack_range = 300.0
	spitter.attack_telegraph_duration = 0.1
	var obstacle: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(10, 40)
	obstacle.add_child(shape)
	obstacle.global_position = Vector2(25, 0)
	add_child(obstacle)
	var player: Node2D = Node2D.new()
	player.global_position = Vector2(50, 0)
	player.add_to_group("player")
	add_child(player)
	spitter._physics_process(0.1)
	_assert(spitter._state == &"chase", "blocked LOS should prevent attack, spitter should chase instead")
	obstacle.free()
	player.free()
	spitter.free()

# --- S08D Brute and crowd separation tests ---

func _load_brute_scene() -> Node:
	var packed: PackedScene = load("res://scenes/enemies/brute.tscn")
	var instance: Node = packed.instantiate()
	add_child(instance)
	return instance

func _test_brute_starts_idle() -> void:
	var brute: Node = _load_brute_scene()
	_assert(brute._state == &"idle", "brute should start idle")
	brute.free()

func _test_brute_telegraph_has_visible_pulse() -> void:
	var brute: Node = _load_brute_scene()
	brute.global_position = Vector2(0, 0)
	brute._sprite.scale = Vector2.ONE
	brute.attack_range = 100.0
	brute.attack_telegraph_duration = 0.2
	var player: Node2D = Node2D.new()
	player.global_position = Vector2(30, 0)
	player.add_to_group("player")
	add_child(player)
	brute._physics_process(0.1)
	_assert(brute._state == &"attack_telegraph", "brute should enter telegraph when in range")
	_assert(brute._sprite.modulate != brute._base_modulate, "brute sprite should pulse during telegraph")
	player.free()
	brute.free()


func _test_brute_stagger_resistance_reduces_knockback() -> void:
	var brute: Node = _load_brute_scene()
	brute.global_position = Vector2(0, 0)
	brute._sprite.scale = Vector2.ONE
	var info: DamageInfo = DamageInfo.new(10.0, DamageInfo.DamageType.BALLISTIC, null, Vector2.ZERO, Vector2.RIGHT, 200.0)
	brute._on_damaged(info)
	_assert(brute._state == &"stagger", "brute should stagger when hit")
	_assert(brute.velocity.x < 5.0, "brute knockback should be heavily resisted")
	brute.free()

func _test_brute_attack_deals_heavy_damage() -> void:
	var brute: Node = _load_brute_scene()
	brute.global_position = Vector2(0, 0)
	brute._sprite.scale = Vector2.ONE
	brute.attack_range = 100.0
	brute.attack_damage = 30.0
	brute.attack_telegraph_duration = 0.1
	var player: CharacterBody2D = _create_test_player()
	player.global_position = Vector2(30, 0)
	var health: HealthComponent = player.get_node("HealthComponent") as HealthComponent
	brute._physics_process(0.1)
	_assert(brute._state == &"attack", "brute should enter attack after telegraph expires")
	_assert(brute._attack_timer > 0.0, "attack cooldown should be set after brute attack")
	_assert(brute._target == player, "brute target should be the player")
	_assert(health.current_health < 100.0, "brute attack should deal at least 30 damage, got health %.1f" % health.current_health)
	player.free()
	brute.free()


func _test_brute_dies_once_using_shared_contract() -> void:
	var brute: Node = _load_brute_scene()
	brute.health_component.take_damage(DamageInfo.new(120.0))
	_assert(brute.health_component.is_dead, "brute should be dead after lethal damage")
	_assert(brute._state == &"dead", "brute state should be dead")
	brute.free()

func _test_brute_reset_clears_death_and_state() -> void:
	var brute: Node = _load_brute_scene()
	brute.health_component.take_damage(DamageInfo.new(120.0))
	brute.reset()
	_assert(not brute.health_component.is_dead, "reset should clear death via HealthComponent")
	_assert(brute._state == &"idle", "reset should restore idle state")
	brute.free()

func _test_crowd_separation_prevents_exact_stacking() -> void:
	var brute: Node = _load_brute_scene()
	var shambler: Node = _load_shambler_scene()
	brute.global_position = Vector2(0, 0)
	shambler.global_position = Vector2(5, 0)
	brute._physics_process(0.1)
	shambler._physics_process(0.1)
	_assert(brute.global_position.x <= -5.0 or shambler.global_position.x >= 10.0,
		"enemies should separate when close, brute=%.1f shambler=%.1f" % [brute.global_position.x, shambler.global_position.x])
	brute.free()
	shambler.free()

func _test_crowd_separation_uses_gentle_impulse() -> void:
	var brute: Node = _load_brute_scene()
	var shambler: Node = _load_shambler_scene()
	brute.global_position = Vector2(0, 0)
	shambler.global_position = Vector2(10, 0)
	var initial_brute_vx: float = brute.velocity.x
	var initial_shambler_vx: float = shambler.velocity.x
	brute._physics_process(0.1)
	shambler._physics_process(0.1)
	var brute_delta: float = abs(brute.velocity.x - initial_brute_vx)
	var shambler_delta: float = abs(shambler.velocity.x - initial_shambler_vx)
	_assert(brute_delta < 15.0, "brute separation impulse should stay gentle, got %.1f" % brute_delta)
	_assert(shambler_delta < 15.0, "shambler separation impulse should stay gentle, got %.1f" % shambler_delta)
	brute.free()
	shambler.free()

# --- S09A Director tests ---

func _test_director_fixed_seed_reproduces_selection() -> void:
	var marker_a: SpawnMarker = SpawnMarker.new()
	marker_a.global_position = Vector2(100, 0)
	marker_a.enemy_type = &"shambler"
	marker_a.active = true
	add_child(marker_a)

	var marker_b: SpawnMarker = SpawnMarker.new()
	marker_b.global_position = Vector2(200, 0)
	marker_b.enemy_type = &"runner"
	marker_b.active = true
	add_child(marker_b)

	var director_a: Director = Director.new()
	director_a.configure(42, [marker_a, marker_b], Vector2.ZERO)
	var result_a: Dictionary = director_a.select_spawn(0.0)

	var director_b: Director = Director.new()
	director_b.configure(42, [marker_a, marker_b], Vector2.ZERO)
	var result_b: Dictionary = director_b.select_spawn(0.0)

	_assert(result_a.has("enemy_type"), "first run should select an enemy")
	_assert(result_b.has("enemy_type"), "second run should select an enemy")
	_assert(result_a.enemy_type == result_b.enemy_type, "same seed should produce same selection")

	marker_a.free()
	marker_b.free()
	director_a.free()
	director_b.free()


func _test_director_respects_threat_budget_cap() -> void:
	var marker: SpawnMarker = SpawnMarker.new()
	marker.global_position = Vector2(100, 0)
	marker.enemy_type = &"brute"
	marker.active = true
	add_child(marker)

	var director: Director = Director.new()
	director.max_threat_budget = 30.0
	director.configure(1, [marker], Vector2.ZERO)

	var first: bool = director.register_spawn(30.0)
	_assert(first, "first spawn within budget should succeed")
	_assert(director.get_remaining_threat() == 0.0, "budget should be exhausted")

	var second: bool = director.register_spawn(10.0)
	_assert(not second, "spawn exceeding remaining budget should fail")
	_assert(director.get_remaining_threat() == 0.0, "budget should remain at zero")

	marker.free()
	director.free()


func _test_director_respects_living_enemy_cap() -> void:
	var marker: SpawnMarker = SpawnMarker.new()
	marker.global_position = Vector2(100, 0)
	marker.enemy_type = &"shambler"
	marker.active = true
	add_child(marker)

	var director: Director = Director.new()
	director.max_living_enemies = 2
	director.configure(1, [marker], Vector2.ZERO)

	var first: bool = director.register_spawn(10.0)
	_assert(first, "first spawn within cap should succeed")
	var second: bool = director.register_spawn(10.0)
	_assert(second, "second spawn within cap should succeed")
	_assert(director.get_remaining_slots() == 0, "slots should be exhausted")

	var third: bool = director.register_spawn(10.0)
	_assert(not third, "spawn exceeding living cap should fail")
	_assert(director.get_remaining_slots() == 0, "slots should remain at zero")

	marker.free()
	director.free()


func _test_director_select_spawn_respects_caps() -> void:
	var marker: SpawnMarker = SpawnMarker.new()
	marker.global_position = Vector2(100, 0)
	marker.enemy_type = &"brute"
	marker.active = true
	add_child(marker)

	var director: Director = Director.new()
	director.max_threat_budget = 20.0
	director.max_living_enemies = 1
	director.configure(1, [marker], Vector2.ZERO)

	var result: Dictionary = director.select_spawn(0.0)
	_assert(result.is_empty(), "selection should fail when brute threat exceeds remaining budget")

	marker.free()
	director.free()


func _test_director_rejects_too_close_spawn_to_player() -> void:
	var marker: SpawnMarker = SpawnMarker.new()
	marker.global_position = Vector2(30, 0)
	marker.enemy_type = &"shambler"
	marker.active = true
	add_child(marker)

	var player: Node2D = Node2D.new()
	player.global_position = Vector2(0, 0)
	add_child(player)

	var director: Director = Director.new()
	director.min_spawn_distance = 50.0
	director.configure(1, [marker], player.global_position)

	var result: Dictionary = director.select_spawn(0.0)
	_assert(result.is_empty(), "spawn too close to player should be rejected")

	marker.free()
	player.free()
	director.free()


func _test_director_rejects_too_close_spawn_to_recent() -> void:
	var marker_a: SpawnMarker = SpawnMarker.new()
	marker_a.global_position = Vector2(100, 0)
	marker_a.enemy_type = &"shambler"
	marker_a.active = true
	add_child(marker_a)

	var marker_b: SpawnMarker = SpawnMarker.new()
	marker_b.global_position = Vector2(120, 0)
	marker_b.enemy_type = &"shambler"
	marker_b.active = true
	add_child(marker_b)

	var director: Director = Director.new()
	director.min_spawn_distance = 50.0
	director.configure(1, [marker_a, marker_b], Vector2(0, 100))

	var first: Dictionary = director.select_spawn(0.0)
	_assert(first.has("enemy_type"), "first spawn should succeed")

	var second: Dictionary = director.select_spawn(0.0)
	_assert(second.is_empty(), "spawn too close to recently used position should be rejected")

	marker_a.free()
	marker_b.free()
	director.free()


func _test_director_pressure_escalates_through_phases() -> void:
	var marker: SpawnMarker = SpawnMarker.new()
	marker.global_position = Vector2(100, 0)
	marker.enemy_type = &"shambler"
	marker.active = true
	add_child(marker)

	var director: Director = Director.new()
	director.recovery_duration = 2.0
	director.pressure_duration = 2.0
	director.escalation_duration = 2.0
	director.configure(1, [marker], Vector2(0, 100))

	_assert(director._phase == Director.Phase.RECOVERY, "should start in recovery")

	director._step_phase(2.1)
	_assert(director._phase == Director.Phase.PRESSURE, "should escalate to pressure after recovery")

	director.register_spawn(10.0)
	director._step_phase(2.1)
	_assert(director._phase == Director.Phase.ESCALATION, "should escalate after pressure duration")

	director._step_phase(2.1)
	_assert(director._phase == Director.Phase.PEAK, "should peak after escalation duration")

	marker.free()
	director.free()


func _test_director_phase_and_spawn_reproduce_from_seed() -> void:
	var marker_a: SpawnMarker = SpawnMarker.new()
	marker_a.global_position = Vector2(100, 0)
	marker_a.enemy_type = &"shambler"
	marker_a.active = true
	add_child(marker_a)

	var marker_b: SpawnMarker = SpawnMarker.new()
	marker_b.global_position = Vector2(200, 0)
	marker_b.enemy_type = &"runner"
	marker_b.active = true
	add_child(marker_b)

	var director_a: Director = Director.new()
	director_a.configure(99, [marker_a, marker_b], Vector2(0, 100))
	director_a._step_phase(1.0)
	var spawn_a: Dictionary = director_a.select_spawn(0.0)

	var director_b: Director = Director.new()
	director_b.configure(99, [marker_a, marker_b], Vector2(0, 100))
	director_b._step_phase(1.0)
	var spawn_b: Dictionary = director_b.select_spawn(0.0)

	_assert(director_a._phase == director_b._phase, "same seed should produce same phase")
	_assert(spawn_a.enemy_type == spawn_b.enemy_type, "same seed should produce same spawn type")
	_assert(spawn_a.position == spawn_b.position, "same seed should produce same spawn position")

	marker_a.free()
	marker_b.free()
	director_a.free()
	director_b.free()


func _test_mixed_archetypes_retain_navigation_and_attack() -> void:
	var brute: Node = _load_brute_scene()
	var runner: Node = _load_runner_scene()
	var spitter: Node = load("res://scenes/enemies/spitter.tscn").instantiate()
	add_child(spitter)
	brute.global_position = Vector2(0, 0)
	runner.global_position = Vector2(50, 0)
	spitter.global_position = Vector2(100, 0)
	_assert(brute.has_method("set_navigation_graph"), "brute should support navigation graph")
	_assert(runner.has_method("set_navigation_graph"), "runner should support navigation graph")
	_assert(spitter.has_method("set_navigation_graph"), "spitter should support navigation graph")
	_assert(brute._state == &"idle", "brute should retain idle state")
	_assert(runner._state == &"idle", "runner should retain idle state")
	_assert(spitter._state == &"idle", "spitter should retain idle state")
	var player: Node2D = Node2D.new()
	player.global_position = Vector2(150, 0)
	player.add_to_group("player")
	add_child(player)
	brute._physics_process(0.1)
	runner._physics_process(0.1)
	spitter._physics_process(0.1)
	_assert(brute._state == &"attack_telegraph" or brute._state == &"chase", "brute should transition to attack or chase")
	_assert(runner._state == &"telegraph" or runner._state == &"chase", "runner should transition to telegraph or chase")
	_assert(spitter._state == &"telegraph" or spitter._state == &"chase" or spitter._state == &"attack_cooldown", "spitter should transition to telegraph, chase, or cooldown")
	player.free()
	brute.free()
	runner.free()
	spitter.free()


# --- S09C holdout and victory tests ---

func _test_director_victory_emitted_after_all_phases() -> void:
	var marker: SpawnMarker = SpawnMarker.new()
	marker.global_position = Vector2(100, 0)
	marker.enemy_type = &"shambler"
	marker.active = true
	add_child(marker)

	var director: Director = Director.new()
	director.recovery_duration = 1.0
	director.pressure_duration = 1.0
	director.escalation_duration = 1.0
	director.peak_duration = 1.0
	director.configure(1, [marker], Vector2(0, 100))

	director.register_spawn(10.0)
	director._step_phase(1.1)
	director._step_phase(1.1)
	director._step_phase(1.1)
	director._step_phase(1.1)
	director.register_death(10.0)
	director._step_phase(0.1)
	_assert(director.has_victory(), "victory should be true after all phases visited")

	marker.free()
	director.free()


func _test_director_victory_emitted_once() -> void:
	var marker: SpawnMarker = SpawnMarker.new()
	marker.global_position = Vector2(100, 0)
	marker.enemy_type = &"shambler"
	marker.active = true
	add_child(marker)

	var director: Director = Director.new()
	director.recovery_duration = 1.0
	director.pressure_duration = 1.0
	director.escalation_duration = 1.0
	director.peak_duration = 1.0
	director.configure(1, [marker], Vector2(0, 100))

	director.register_spawn(10.0)
	director._step_phase(1.1)
	director._step_phase(1.1)
	director._step_phase(1.1)
	director._step_phase(1.1)
	director.register_death(10.0)
	director._step_phase(0.1)

	var blocked: Dictionary = director.select_spawn(0.0)
	_assert(blocked.is_empty(), "spawn should be blocked after victory")

	marker.free()
	director.free()


func _test_director_reset_clears_victory_state() -> void:
	var marker: SpawnMarker = SpawnMarker.new()
	marker.global_position = Vector2(100, 0)
	marker.enemy_type = &"shambler"
	marker.active = true
	add_child(marker)

	var director: Director = Director.new()
	director.recovery_duration = 1.0
	director.pressure_duration = 1.0
	director.escalation_duration = 1.0
	director.peak_duration = 1.0
	director.configure(1, [marker], Vector2(0, 100))

	director.register_spawn(10.0)
	director._step_phase(1.1)
	director._step_phase(1.1)
	director._step_phase(1.1)
	director._step_phase(1.1)
	director.register_death(10.0)
	director._step_phase(0.1)
	_assert(director.has_victory(), "victory should be set after holdout")

	director.reset()
	_assert(not director.has_victory(), "victory should be cleared after reset")

	marker.free()
	director.free()


func _test_level_restart_clears_enemies_and_director() -> void:
	var level: Node2D = _load_level_scene()
	var director: Director = level.get_node_or_null("Director") as Director
	_assert(director != null, "level should contain a Director node")

	var victory_label: Label = level.get_node_or_null("VictoryLabel") as Label
	_assert(victory_label != null, "level should contain a VictoryLabel")
	_assert(not victory_label.visible, "VictoryLabel should start hidden")

	level.queue_free()
	director = null


# --- S10A upgrade tests ---

func _test_upgrades_apply_and_survive_respawn() -> void:
	var manager = preload("res://scripts/upgrades/upgrade_manager.gd").new()
	add_child(manager)
	var speed_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	speed_data.upgrade_id = &"speed_boost"
	speed_data.max_stacks = 3
	speed_data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	speed_data.modifiers[0].stat = &"speed"
	speed_data.modifiers[0].value = 15.0
	var health_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	health_data.upgrade_id = &"health_up"
	health_data.max_stacks = 4
	health_data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	health_data.modifiers[0].stat = &"health_max"
	health_data.modifiers[0].value = 25.0
	var regen_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	regen_data.upgrade_id = &"health_regen"
	regen_data.max_stacks = 1
	regen_data.applies_once = true
	regen_data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	regen_data.modifiers[0].stat = &"health_regen"
	regen_data.modifiers[0].value = 1.0
	manager.call("register_upgrade", speed_data)
	manager.call("register_upgrade", health_data)
	manager.call("register_upgrade", regen_data)
	_assert(manager.call("apply_upgrade", &"speed_boost"), "speed_boost should apply")
	_assert(manager.call("apply_upgrade", &"health_up"), "health_up should apply")
	_assert(manager.call("apply_upgrade", &"health_regen"), "health_regen should apply once")
	_assert(manager.call("get_stack_count", &"speed_boost") == 1, "speed_boost should have 1 stack")
	_assert(manager.call("get_stack_count", &"health_up") == 1, "health_up should have 1 stack")
	_assert(manager.call("get_stack_count", &"health_regen") == 1, "health_regen should have 1 stack")
	manager.call("on_respawn")
	_assert(manager.call("get_stack_count", &"speed_boost") == 1, "speed_boost should survive respawn")
	_assert(manager.call("get_stack_count", &"health_up") == 1, "health_up should survive respawn")
	_assert(manager.call("get_stack_count", &"health_regen") == 1, "health_regen should survive respawn")
	manager.queue_free()


func _test_upgrade_stack_limit_enforced() -> void:
	var manager = preload("res://scripts/upgrades/upgrade_manager.gd").new()
	add_child(manager)
	var data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	data.upgrade_id = &"damage_boost"
	data.max_stacks = 5
	data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	data.modifiers[0].stat = &"damage_mult"
	data.modifiers[0].value = 0.25
	manager.call("register_upgrade", data)
	for i in range(data.max_stacks):
		_assert(manager.call("apply_upgrade", &"damage_boost"), "damage_boost stack %d should apply" % (i + 1))
	_assert(not manager.call("apply_upgrade", &"damage_boost"), "damage_boost beyond max_stacks should be rejected")
	_assert(manager.call("get_stack_count", &"damage_boost") == data.max_stacks, "stack count should equal max_stacks")
	manager.queue_free()


func _test_upgrade_mutual_exclusion_enforced() -> void:
	var manager = preload("res://scripts/upgrades/upgrade_manager.gd").new()
	add_child(manager)
	var data_a = preload("res://scripts/upgrades/upgrade_data.gd").new()
	data_a.upgrade_id = &"speed_boost"
	data_a.max_stacks = 3
	data_a.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	data_a.modifiers[0].stat = &"speed"
	data_a.modifiers[0].value = 15.0
	var data_b = preload("res://scripts/upgrades/upgrade_data.gd").new()
	data_b.upgrade_id = &"damage_boost"
	data_b.max_stacks = 5
	data_b.mutual_exclusions = [StringName("speed_boost")]
	data_b.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	data_b.modifiers[0].stat = &"damage_mult"
	data_b.modifiers[0].value = 0.25
	manager.call("register_upgrade", data_a)
	manager.call("register_upgrade", data_b)
	_assert(manager.call("apply_upgrade", &"speed_boost"), "speed_boost should apply")
	_assert(not manager.call("apply_upgrade", &"damage_boost"), "damage_boost should be excluded by speed_boost")
	_assert(manager.call("get_stack_count", &"speed_boost") == 1, "speed_boost should remain active")
	_assert(manager.call("get_stack_count", &"damage_boost") == 0, "damage_boost should not be active")
	manager.queue_free()


# --- S10B upgrade chooser tests ---

func _test_chooser_fixed_seed_reproduces_same_three_choices() -> void:
	var registry: Dictionary = {}
	var speed_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	speed_data.upgrade_id = &"speed_boost"
	speed_data.display_name = "Speed Boost"
	speed_data.description = "Increases movement speed by 15% per stack."
	speed_data.max_stacks = 3
	speed_data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	speed_data.modifiers[0].stat = &"speed"
	speed_data.modifiers[0].value = 15.0
	speed_data.modifiers[0].operation = 3
	registry[speed_data.upgrade_id] = speed_data

	var health_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	health_data.upgrade_id = &"health_up"
	health_data.display_name = "Health Up"
	health_data.description = "Increases maximum health by 25 points per stack."
	health_data.max_stacks = 4
	health_data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	health_data.modifiers[0].stat = &"health_max"
	health_data.modifiers[0].value = 25.0
	health_data.modifiers[0].operation = 0
	registry[health_data.upgrade_id] = health_data

	var damage_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	damage_data.upgrade_id = &"damage_boost"
	damage_data.display_name = "Damage Boost"
	damage_data.description = "Increases damage dealt by 25% per stack."
	damage_data.max_stacks = 5
	damage_data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	damage_data.modifiers[0].stat = &"damage_mult"
	damage_data.modifiers[0].value = 0.25
	damage_data.modifiers[0].operation = 1
	registry[damage_data.upgrade_id] = damage_data

	var active: Dictionary = {}

	var chooser_a = preload("res://scripts/upgrades/upgrade_chooser.gd").new()
	chooser_a.configure(42, registry, active)
	var choices_a: Array[Dictionary] = chooser_a.generate_choices(3)

	var chooser_b = preload("res://scripts/upgrades/upgrade_chooser.gd").new()
	chooser_b.configure(42, registry, active)
	var choices_b: Array[Dictionary] = chooser_b.generate_choices(3)

	_assert(choices_a.size() == 3, "chooser should return three choices, got %d" % choices_a.size())
	_assert(choices_b.size() == 3, "chooser should return three choices, got %d" % choices_b.size())
	for i in range(3):
		_assert(choices_a[i].upgrade_id == choices_b[i].upgrade_id,
			"same seed should produce same choice %d: %s vs %s" % [i, choices_a[i].upgrade_id, choices_b[i].upgrade_id])

	chooser_a.queue_free()
	chooser_b.queue_free()


func _test_chooser_excludes_maxed_and_conflicting_upgrades() -> void:
	var registry: Dictionary = {}
	var speed_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	speed_data.upgrade_id = &"speed_boost"
	speed_data.display_name = "Speed Boost"
	speed_data.description = "Increases movement speed."
	speed_data.max_stacks = 1
	speed_data.modifiers = []
	registry[speed_data.upgrade_id] = speed_data

	var damage_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	damage_data.upgrade_id = &"damage_boost"
	damage_data.display_name = "Damage Boost"
	damage_data.description = "Increases damage."
	damage_data.max_stacks = 5
	damage_data.mutual_exclusions = [StringName("speed_boost")]
	damage_data.modifiers = []
	registry[damage_data.upgrade_id] = damage_data

	var health_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	health_data.upgrade_id = &"health_up"
	health_data.display_name = "Health Up"
	health_data.description = "Increases health."
	health_data.max_stacks = 4
	health_data.modifiers = []
	registry[health_data.upgrade_id] = health_data

	var active: Dictionary = {}
	active[&"speed_boost"] = 1

	var chooser = preload("res://scripts/upgrades/upgrade_chooser.gd").new()
	chooser.configure(7, registry, active)
	var choices: Array[Dictionary] = chooser.generate_choices(3)

	for choice in choices:
		_assert(choice.upgrade_id != &"speed_boost", "maxed speed_boost should not appear")
		_assert(choice.upgrade_id != &"damage_boost", "excluded damage_boost should not appear")

	chooser.queue_free()


func _test_chooser_descriptions_expose_numerical_effects() -> void:
	var registry: Dictionary = {}
	var data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	data.upgrade_id = &"fire_rate_up"
	data.display_name = "Fire Rate Up"
	data.description = "Increases fire rate."
	data.max_stacks = 3
	data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	data.modifiers[0].stat = &"fire_rate"
	data.modifiers[0].value = 0.15
	data.modifiers[0].operation = 0
	registry[data.upgrade_id] = data

	var chooser = preload("res://scripts/upgrades/upgrade_chooser.gd").new()
	chooser.configure(1, registry, {})
	var choices: Array[Dictionary] = chooser.generate_choices(1)

	_assert(not choices.is_empty(), "should produce at least one choice")
	var description: String = choices[0].description
	_assert(description.find("fire_rate") >= 0, "description should expose stat name, got: %s" % description)
	_assert(description.find("0.15") >= 0 or description.find("15") >= 0,
		"description should expose modifier value, got: %s" % description)

	chooser.queue_free()


# --- S10C upgrade UI tests ---

func _test_upgrade_ui_displays_three_choices() -> void:
	var runtime = preload("res://scripts/upgrades/upgrade_runtime.gd").new()
	add_child(runtime)
	var manager = preload("res://scripts/upgrades/upgrade_manager.gd").new()
	add_child(manager)
	var speed_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	speed_data.upgrade_id = &"speed_boost"
	speed_data.display_name = "Speed Boost"
	speed_data.description = "Increases speed."
	speed_data.max_stacks = 3
	speed_data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	speed_data.modifiers[0].stat = &"speed"
	speed_data.modifiers[0].value = 15.0
	speed_data.modifiers[0].operation = 3
	var health_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	health_data.upgrade_id = &"health_up"
	health_data.display_name = "Health Up"
	health_data.description = "Increases health."
	health_data.max_stacks = 4
	health_data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	health_data.modifiers[0].stat = &"health_max"
	health_data.modifiers[0].value = 25.0
	health_data.modifiers[0].operation = 0
	var damage_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	damage_data.upgrade_id = &"damage_boost"
	damage_data.display_name = "Damage Boost"
	damage_data.description = "Increases damage."
	damage_data.max_stacks = 5
	damage_data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	damage_data.modifiers[0].stat = &"damage_mult"
	damage_data.modifiers[0].value = 0.25
	damage_data.modifiers[0].operation = 1
	manager.call("register_upgrade", speed_data)
	manager.call("register_upgrade", health_data)
	manager.call("register_upgrade", damage_data)
	manager.call("unlock_upgrade", &"speed_boost")
	manager.call("unlock_upgrade", &"health_up")
	manager.call("unlock_upgrade", &"damage_boost")
	runtime._upgrade_manager = manager

	var ui = preload("res://scenes/ui/upgrade_selection.tscn").instantiate()
	var choices: Array[Dictionary] = [
		{"upgrade_id": &"speed_boost", "display_name": "Speed Boost", "description": "speed +15.00"},
		{"upgrade_id": &"health_up", "display_name": "Health Up", "description": "health_max +25.00"},
		{"upgrade_id": &"damage_boost", "display_name": "Damage Boost", "description": "damage_mult x0.25"}
	]
	add_child(ui)
	ui.setup(choices, runtime)

	_assert(ui.get_node("VBox/Choice1").text.find("Speed Boost") >= 0, "choice 1 should show upgrade name")
	_assert(ui.get_node("VBox/Choice1").text.find("15.00") >= 0, "choice 1 should show numerical effect")
	_assert(ui.get_node("VBox/Choice2").text.find("Health Up") >= 0, "choice 2 should show upgrade name")
	_assert(ui.get_node("VBox/Choice2").text.find("25.00") >= 0, "choice 2 should show numerical effect")
	_assert(ui.get_node("VBox/Choice3").text.find("Damage Boost") >= 0, "choice 3 should show upgrade name")
	_assert(ui.get_node("VBox/Choice3").text.find("0.25") >= 0, "choice 3 should show numerical effect")

	ui.queue_free()
	runtime.queue_free()
	manager.queue_free()


func _test_upgrade_selection_applies_once_and_closes() -> void:
	var runtime = preload("res://scripts/upgrades/upgrade_runtime.gd").new()
	add_child(runtime)
	var manager = preload("res://scripts/upgrades/upgrade_manager.gd").new()
	add_child(manager)
	var speed_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	speed_data.upgrade_id = &"speed_boost"
	speed_data.display_name = "Speed Boost"
	speed_data.description = "Increases speed."
	speed_data.max_stacks = 3
	speed_data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	speed_data.modifiers[0].stat = &"speed"
	speed_data.modifiers[0].value = 15.0
	speed_data.modifiers[0].operation = 3
	manager.call("register_upgrade", speed_data)
	manager.call("unlock_upgrade", &"speed_boost")
	runtime._upgrade_manager = manager

	var ui = preload("res://scenes/ui/upgrade_selection.tscn").instantiate()
	var choices: Array[Dictionary] = [
		{"upgrade_id": &"speed_boost", "display_name": "Speed Boost", "description": "speed +15.00"}
	]
	add_child(ui)
	ui.setup(choices, runtime)

	_assert(is_instance_valid(ui), "UI should exist before selection")
	ui._select_choice(0)
	await get_tree().process_frame
	_assert(not is_instance_valid(ui), "UI should be freed after selection")
	_assert(manager.call("get_stack_count", &"speed_boost") == 1, "upgrade should apply once")

	runtime.queue_free()
	manager.queue_free()


func _test_checkpoint_respawn_does_not_double_apply() -> void:
	var manager = preload("res://scripts/upgrades/upgrade_manager.gd").new()
	add_child(manager)
	var speed_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	speed_data.upgrade_id = &"speed_boost"
	speed_data.max_stacks = 3
	speed_data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	speed_data.modifiers[0].stat = &"speed"
	speed_data.modifiers[0].value = 15.0
	manager.call("register_upgrade", speed_data)
	manager.call("unlock_upgrade", &"speed_boost")
	manager.call("apply_upgrade", &"speed_boost")
	_assert(manager.call("get_stack_count", &"speed_boost") == 1, "should start with 1 stack")

	var runtime = preload("res://scripts/upgrades/upgrade_runtime.gd").new()
	runtime._upgrade_manager = manager
	add_child(runtime)
	runtime.on_respawn()
	_assert(manager.call("get_stack_count", &"speed_boost") == 1, "respawn should not double apply")

	runtime.queue_free()
	manager.queue_free()


func _test_scene_reload_does_not_double_apply() -> void:
	var manager = preload("res://scripts/upgrades/upgrade_manager.gd").new()
	var speed_data = preload("res://scripts/upgrades/upgrade_data.gd").new()
	speed_data.upgrade_id = &"speed_boost"
	speed_data.max_stacks = 3
	speed_data.modifiers = [preload("res://scripts/upgrades/modifier_data.gd").new()]
	speed_data.modifiers[0].stat = &"speed"
	speed_data.modifiers[0].value = 15.0
	manager.call("register_upgrade", speed_data)
	manager.call("unlock_upgrade", &"speed_boost")
	manager.call("apply_upgrade", &"speed_boost")
	_assert(manager.call("get_stack_count", &"speed_boost") == 1, "should start with 1 stack")

	var runtime = preload("res://scripts/upgrades/upgrade_runtime.gd").new()
	runtime._upgrade_manager = manager
	add_child(runtime)
	runtime.on_respawn()
	_assert(manager.call("get_stack_count", &"speed_boost") == 1, "scene reload should not double apply")

	runtime.queue_free()
	manager.queue_free()


# --- S11A save schema and sanitization tests ---

func _test_save_schema_has_explicit_version_and_stable_identifiers() -> void:
	var data: Dictionary = SaveSchema.create_empty()
	_assert(data.has(SaveSchema.FIELD_VERSION), "save data must contain version field")
	_assert(data[SaveSchema.FIELD_VERSION] == SaveSchema.CURRENT_VERSION, "version must be current")
	var weapon: Dictionary = SaveSchema.weapon_entry(&"pistol", 10, 20)
	_assert(weapon[SaveSchema.FIELD_WEAPON_ID] is StringName, "weapon_id must be a stable StringName")
	var upgrade: Dictionary = SaveSchema.upgrade_entry(&"speed_boost", 2)
	_assert(upgrade[SaveSchema.FIELD_UPGRADE_ID] is StringName, "upgrade_id must be a stable StringName")


func _test_save_schema_missing_fields_fall_back_to_defaults() -> void:
	var partial: Dictionary = {}
	partial[SaveSchema.FIELD_VERSION] = 1
	var sanitized: Dictionary = _sanitize(partial)
	_assert(sanitized.has(SaveSchema.FIELD_CHECKPOINT), "missing checkpoint should be filled")
	_assert(sanitized.has(SaveSchema.FIELD_HEALTH_CURRENT), "missing health_current should be filled")
	_assert(sanitized.has(SaveSchema.FIELD_HEALTH_MAX), "missing health_max should be filled")
	_assert(sanitized.has(SaveSchema.FIELD_WEAPONS), "missing weapons should be filled")
	_assert(sanitized.has(SaveSchema.FIELD_UPGRADES), "missing upgrades should be filled")
	_assert(sanitized.has(SaveSchema.FIELD_ENCOUNTER_COMPLETED), "missing encounter_completed should be filled")
	_assert(sanitized.has(SaveSchema.FIELD_SESSION_SEED), "missing session_seed should be filled")
	_assert(sanitized[SaveSchema.FIELD_CHECKPOINT] == SaveSchema.DEFAULT_CHECKPOINT, "default checkpoint should be applied")


func _test_save_schema_corrupt_health_is_repaired() -> void:
	var data: Dictionary = SaveSchema.create_empty()
	data[SaveSchema.FIELD_HEALTH_CURRENT] = 200.0
	data[SaveSchema.FIELD_HEALTH_MAX] = 100.0
	var sanitized: Dictionary = _sanitize(data)
	_assert(sanitized[SaveSchema.FIELD_HEALTH_CURRENT] == sanitized[SaveSchema.FIELD_HEALTH_MAX],
		"health_current exceeding max should be clamped to max")
	data[SaveSchema.FIELD_HEALTH_CURRENT] = -10.0
	sanitized = _sanitize(data)
	_assert(sanitized[SaveSchema.FIELD_HEALTH_CURRENT] == 0.0,
		"negative health_current should be clamped to zero")
	data[SaveSchema.FIELD_HEALTH_MAX] = 0.0
	sanitized = _sanitize(data)
	_assert(sanitized[SaveSchema.FIELD_HEALTH_MAX] == SaveSchema.DEFAULT_HEALTH_MAX,
		"zero health_max should be repaired to default")


func _test_save_schema_unknown_fields_are_stripped() -> void:
	var data: Dictionary = SaveSchema.create_empty()
	data["_unknown_field"] = "should disappear"
	data["another_unknown"] = 42
	var sanitized: Dictionary = _sanitize(data)
	_assert(not sanitized.has("_unknown_field"), "unknown fields should be stripped")
	_assert(not sanitized.has("another_unknown"), "unknown fields should be stripped")
	_assert(sanitized[SaveSchema.FIELD_VERSION] == SaveSchema.CURRENT_VERSION, "known fields should remain")


func _test_save_schema_invalid_version_returns_empty_defaults() -> void:
	var no_version: Dictionary = {}
	no_version[SaveSchema.FIELD_CHECKPOINT] = Vector2(500, 500)
	var sanitized: Dictionary = _sanitize(no_version)
	_assert(sanitized[SaveSchema.FIELD_CHECKPOINT] == SaveSchema.DEFAULT_CHECKPOINT,
		"missing version should reset to defaults, ignoring other fields")
	var bad_version: Dictionary = {}
	bad_version[SaveSchema.FIELD_VERSION] = "not_a_number"
	sanitized = _sanitize(bad_version)
	_assert(sanitized[SaveSchema.FIELD_VERSION] == SaveSchema.CURRENT_VERSION,
		"invalid version type should reset to defaults")
	var future_version: Dictionary = {}
	future_version[SaveSchema.FIELD_VERSION] = 99
	sanitized = _sanitize(future_version)
	_assert(sanitized == SaveSchema.create_empty(),
		"future version beyond current should reset to empty defaults")


func _test_save_schema_old_version_migrates_deterministically() -> void:
	var old_data: Dictionary = {}
	old_data[SaveSchema.FIELD_VERSION] = 0
	old_data["legacy_field"] = "removed"
	old_data[SaveSchema.FIELD_HEALTH_CURRENT] = 50.0
	var sanitized_a: Dictionary = _sanitize(old_data)
	var old_data_b: Dictionary = {}
	old_data_b[SaveSchema.FIELD_VERSION] = 0
	old_data_b["legacy_field"] = "removed"
	old_data_b[SaveSchema.FIELD_HEALTH_CURRENT] = 50.0
	var sanitized_b: Dictionary = _sanitize(old_data_b)
	_assert(sanitized_a == sanitized_b, "migration must be deterministic across repeated calls")
	_assert(sanitized_a[SaveSchema.FIELD_VERSION] == SaveSchema.CURRENT_VERSION, "migrated version must be current")
	_assert(not sanitized_a.has("legacy_field"), "migration must strip legacy unknown fields")
	_assert(sanitized_a[SaveSchema.FIELD_CHECKPOINT] == SaveSchema.DEFAULT_CHECKPOINT,
		"migration from version 0 must fill checkpoint default")
	_assert(sanitized_a[SaveSchema.FIELD_HEALTH_CURRENT] == SaveSchema.DEFAULT_HEALTH_CURRENT,
		"migration from version 0 must reset health to safe default (ancient format)")


func _test_save_sanitizer_repairs_negative_ammo() -> void:
	var data: Dictionary = SaveSchema.create_empty()
	data[SaveSchema.FIELD_WEAPONS] = [
		SaveSchema.weapon_entry(&"pistol", -5, -3),
	]
	var sanitized: Dictionary = _sanitize(data)
	var weapons: Array = sanitized[SaveSchema.FIELD_WEAPONS]
	_assert(weapons.size() == 1, "valid weapon entry should be kept")
	_assert(weapons[0][SaveSchema.FIELD_CURRENT_AMMO] == 0, "negative ammo should be clamped to zero")
	_assert(weapons[0][SaveSchema.FIELD_RESERVE_AMMO] == 0, "negative reserve ammo should be clamped to zero")


func _test_save_sanitizer_skips_unknown_version_fields() -> void:
	var data: Dictionary = SaveSchema.create_empty()
	data["extra_key"] = "value"
	var sanitized: Dictionary = _sanitize(data)
	_assert(not sanitized.has("extra_key"), "unknown top-level field must be stripped")


func _test_save_schema_weapon_entry_requires_valid_identifier() -> void:
	var data: Dictionary = SaveSchema.create_empty()
	data[SaveSchema.FIELD_WEAPONS] = [
		{"wrong_key": "pistol", SaveSchema.FIELD_CURRENT_AMMO: 5},
		SaveSchema.weapon_entry(&"pistol", 5, 10),
	]
	var sanitized: Dictionary = _sanitize(data)
	var weapons: Array = sanitized[SaveSchema.FIELD_WEAPONS]
	_assert(weapons.size() == 1, "entries without valid weapon_id should be dropped")
	_assert(weapons[0][SaveSchema.FIELD_WEAPON_ID] == &"pistol", "valid entry should be preserved")


func _test_save_schema_upgrade_entry_requires_valid_identifier() -> void:
	var data: Dictionary = SaveSchema.create_empty()
	data[SaveSchema.FIELD_UPGRADES] = [
		{"upgrade_id": 123, SaveSchema.FIELD_UPGRADE_STACKS: 2},
		SaveSchema.upgrade_entry(&"health_up", 1),
	]
	var sanitized: Dictionary = _sanitize(data)
	var upgrades: Array = sanitized[SaveSchema.FIELD_UPGRADES]
	_assert(upgrades.size() == 1, "entries without valid upgrade_id should be dropped")
	_assert(upgrades[0][SaveSchema.FIELD_UPGRADE_ID] == &"health_up", "valid entry should be preserved")


