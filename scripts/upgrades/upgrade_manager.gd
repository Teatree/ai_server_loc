extends Node

signal upgrade_added(upgrade_id: StringName, stack_count: int)
signal upgrade_removed(upgrade_id: StringName, stack_count: int)
signal modifier_changed(modifier: Resource, active: bool)
signal upgrade_unlocked(upgrade_id: StringName)

var _registry: Dictionary = {}
var _active_upgrades: Dictionary = {}
var _active_modifiers: Array = []
var _applied_upgrades: Array[StringName] = []
var _unlocked_upgrades: Array[StringName] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_upgrade(data: Resource) -> void:
	if data and data.upgrade_id != &"":
		_registry[data.upgrade_id] = data

func can_apply(upgrade_id: StringName) -> bool:
	if not _registry.has(upgrade_id):
		return false
	var data: Resource = _registry[upgrade_id]
	if _active_upgrades.has(upgrade_id):
		return _active_upgrades[upgrade_id] < data.max_stacks
	var exclusions: Array = data.mutual_exclusions
	for exclusion in exclusions:
		if _active_upgrades.has(exclusion):
			return false
	return true

func apply_upgrade(upgrade_id: StringName) -> bool:
	if not can_apply(upgrade_id):
		return false
	var data: Resource = _registry[upgrade_id]
	if not _active_upgrades.has(upgrade_id):
		_active_upgrades[upgrade_id] = 0
	_active_upgrades[upgrade_id] += 1
	for modifier in data.modifiers:
		_apply_modifier(modifier)
		_active_modifiers.append(modifier)
	if not upgrade_id in _applied_upgrades:
		_applied_upgrades.append(upgrade_id)
	upgrade_added.emit(upgrade_id, _active_upgrades[upgrade_id])
	return true

func remove_upgrade(upgrade_id: StringName) -> void:
	if not _active_upgrades.has(upgrade_id):
		return
	var data: Resource = _registry[upgrade_id]
	_active_upgrades[upgrade_id] -= 1
	if _active_upgrades[upgrade_id] <= 0:
		_active_upgrades.erase(upgrade_id)
	for modifier in data.modifiers:
		_remove_modifier(modifier)
	upgrade_removed.emit(upgrade_id, _active_upgrades.get(upgrade_id, 0))

func is_active(upgrade_id: StringName) -> bool:
	return _active_upgrades.has(upgrade_id)

func get_stack_count(upgrade_id: StringName) -> int:
	return _active_upgrades.get(upgrade_id, 0)

func unlock_upgrade(upgrade_id: StringName) -> void:
	if not upgrade_id in _unlocked_upgrades:
		_unlocked_upgrades.append(upgrade_id)
		upgrade_unlocked.emit(upgrade_id)

func is_unlocked(upgrade_id: StringName) -> bool:
	return upgrade_id in _unlocked_upgrades

func on_respawn() -> void:
	_applied_upgrades.clear()
	for upgrade_id in _unlocked_upgrades:
		apply_upgrade(upgrade_id)

func _apply_modifier(modifier: Resource) -> void:
	modifier_changed.emit(modifier, true)

func _remove_modifier(modifier: Resource) -> void:
	modifier_changed.emit(modifier, false)
