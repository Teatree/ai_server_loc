extends Node

var _passed: int = 0
var _failed: int = 0
var _death_count: int = 0


func _ready() -> void:
	_test_death_emits_once()
	_test_invulnerability_blocks_damage()
	_test_entities_cannot_receive_damage_after_death()
	_test_reset_clears_death_state()
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


func _test_invulnerability_blocks_damage() -> void:
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 10.0
	health.current_health = 10.0
	health.invulnerability_duration = 0.5
	health.take_damage(DamageInfo.new(5.0))
	health._process(0.6)
	var damaged_after: bool = false
	health.damaged.connect(func(_info: DamageInfo): damaged_after = true)
	health.take_damage(DamageInfo.new(3.0))
	_assert(not damaged_after, "damage should be blocked during invulnerability")


func _test_entities_cannot_receive_damage_after_death() -> void:
	var health: HealthComponent = HealthComponent.new()
	health.max_health = 10.0
	health.current_health = 10.0
	health.take_damage(DamageInfo.new(15.0))
	_assert(health.is_dead, "entity should be dead")
	var damaged_after_death: bool = false
	health.damaged.connect(func(_info: DamageInfo): damaged_after_death = true)
	health.take_damage(DamageInfo.new(5.0))
	_assert(not damaged_after_death, "damage should be ignored after death")


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
