extends Node

signal modifiers_changed

@onready var player: Node = get_parent()
@onready var health_component: HealthComponent = player.get_node_or_null("HealthComponent")
@onready var movement_controller: MovementController = player.get_node_or_null("MovementController")

var _active_upgrades: Array = []
var _applied_ids: Array = []
var _regen_timer: float = 0.0
var _regen_rate: float = 0.0
var _regen_amount: float = 0.0
var _upgrade_manager = null

func _get_manager():
	if not _upgrade_manager:
		_upgrade_manager = get_node_or_null("/root/UpgradeManager")
		if not _upgrade_manager:
			_upgrade_manager = preload("res://scripts/upgrades/upgrade_manager.gd").new()
	return _upgrade_manager

func _ready() -> void:
	var mgr = _get_manager()
	if mgr and mgr.has_signal("modifier_changed"):
		mgr.modifier_changed.connect(_on_modifier_changed)

func apply_upgrade(upgrade_id: StringName) -> void:
	if upgrade_id in _applied_ids:
		return
	var mgr = _get_manager()
	if not mgr or not mgr.is_unlocked(upgrade_id):
		return
	if not upgrade_id in _active_upgrades:
		_active_upgrades.append(upgrade_id)
	_applied_ids.append(upgrade_id)
	mgr.apply_upgrade(upgrade_id)
	modifiers_changed.emit()

func remove_upgrade(upgrade_id: StringName) -> void:
	if upgrade_id in _active_upgrades:
		_active_upgrades.erase(upgrade_id)
	var mgr = _get_manager()
	if mgr:
		mgr.remove_upgrade(upgrade_id)
	modifiers_changed.emit()

func on_respawn() -> void:
	_applied_ids.clear()
	_regen_timer = 0.0
	var mgr = _get_manager()
	if mgr:
		mgr.on_respawn()
	modifiers_changed.emit()

func offer_choices(seed: int) -> void:
	var mgr = _get_manager()
	if not mgr:
		return
	var chooser = preload("res://scripts/upgrades/upgrade_chooser.gd").new()
	chooser.configure(seed, mgr.get_registry(), mgr.get_active_upgrades())
	var choices: Array[Dictionary] = chooser.generate_choices(3)
	chooser.queue_free()
	if choices.is_empty():
		return
	var ui = preload("res://scenes/ui/upgrade_selection.tscn").instantiate()
	ui.setup(choices, self)
	get_tree().root.add_child(ui)

func _on_modifier_changed(modifier: Resource, active: bool) -> void:
	var stat: StringName = modifier.stat
	if stat == &"speed":
		_apply_speed_modifier(modifier, active)
	elif stat == &"damage_mult":
		_apply_damage_modifier(modifier, active)
	elif stat == &"health_max":
		_apply_health_modifier(modifier, active)
	elif stat == &"fire_rate":
		_apply_fire_rate_modifier(modifier, active)
	elif stat == &"magazine_size":
		_apply_magazine_modifier(modifier, active)
	elif stat == &"knockback_resist":
		_apply_knockback_modifier(modifier, active)
	elif stat == &"health_regen":
		_apply_regen_modifier(modifier, active)
	elif stat == &"ammo_consumption":
		_apply_ammo_modifier(modifier, active)
	modifiers_changed.emit()

func _apply_speed_modifier(modifier: Resource, active: bool) -> void:
	if movement_controller and movement_controller.config:
		var base: float = movement_controller.config.walk_speed
		var delta: float = modifier.value if modifier.operation == 0 else 0.0
		if active:
			movement_controller.config.walk_speed = base + delta

func _apply_damage_modifier(modifier: Resource, active: bool) -> void:
	if player.has_method("set_damage_multiplier"):
		player.set_damage_multiplier(modifier.value if active else 1.0)

func _apply_health_modifier(modifier: Resource, active: bool) -> void:
	if health_component:
		var delta: float = modifier.value if active else -modifier.value
		health_component.max_health = health_component.max_health + delta

func _apply_fire_rate_modifier(modifier: Resource, active: bool) -> void:
	if player.has_method("set_fire_rate_multiplier"):
		player.set_fire_rate_multiplier(modifier.value if active else 1.0)

func _apply_magazine_modifier(modifier: Resource, active: bool) -> void:
	if player.has_method("set_magazine_bonus"):
		player.set_magazine_bonus(modifier.value if active else 0.0)

func _apply_knockback_modifier(modifier: Resource, active: bool) -> void:
	if movement_controller:
		var delta: float = modifier.value if active else -modifier.value
		movement_controller.knockback_resistance += delta

func _apply_regen_modifier(modifier: Resource, active: bool) -> void:
	if active:
		_regen_rate = modifier.value
		_regen_amount = modifier.value * 0.1
	else:
		_regen_rate = 0.0
		_regen_amount = 0.0

func _apply_ammo_modifier(modifier: Resource, active: bool) -> void:
	if player.has_method("set_ammo_conservation"):
		player.set_ammo_conservation(modifier.value if active else 0.0)

func _physics_process(delta: float) -> void:
	if _regen_rate > 0.0 and health_component and not health_component.is_dead:
		_regen_timer += delta
		if _regen_timer >= _regen_rate:
			_regen_timer = 0.0
			health_component.heal(_regen_amount)
