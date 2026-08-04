extends Node
class_name UpgradeChooser

signal choices_generated(choices: Array[Dictionary])

enum Operation {
	ADD,
	MULTIPLY,
	SET,
	ADD_PERCENT
}

var _registry: Dictionary = {}
var _active_upgrades: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func configure(seed: int, registry: Dictionary, active_upgrades: Dictionary) -> void:
	_rng.seed = seed
	_registry = registry.duplicate()
	_active_upgrades = active_upgrades.duplicate()


func generate_choices(count: int = 3) -> Array[Dictionary]:
	var valid: Array[Dictionary] = []
	for upgrade_id in _registry:
		if _is_valid(upgrade_id):
			valid.append(_create_choice(upgrade_id))

	var result: Array[Dictionary] = []
	for i in range(min(count, valid.size())):
		var idx: int = _rng.randi_range(0, valid.size() - 1)
		result.append(valid[idx])
		valid.remove_at(idx)

	choices_generated.emit(result)
	return result


func get_valid_upgrades() -> Array[Dictionary]:
	var valid: Array[Dictionary] = []
	for upgrade_id in _registry:
		if _is_valid(upgrade_id):
			valid.append(_create_choice(upgrade_id))
	return valid


func _is_valid(upgrade_id: StringName) -> bool:
	var data: Resource = _registry[upgrade_id]
	if _active_upgrades.has(upgrade_id):
		if _active_upgrades[upgrade_id] >= data.max_stacks:
			return false
	for exclusion in data.mutual_exclusions:
		if _active_upgrades.has(exclusion):
			return false
	return true


func _create_choice(upgrade_id: StringName) -> Dictionary:
	var data: Resource = _registry[upgrade_id]
	return {
		"upgrade_id": upgrade_id,
		"display_name": data.display_name,
		"description": _build_effect_description(data),
		"max_stacks": data.max_stacks,
		"current_stacks": _active_upgrades.get(upgrade_id, 0),
		"modifiers": data.modifiers
	}


func _build_effect_description(data: Resource) -> String:
	var parts: Array[String] = []
	for modifier in data.modifiers:
		var stat: String = modifier.stat
		var value: float = modifier.value
		var op: int = modifier.operation
		match op:
			Operation.ADD:
				parts.append("%s +%.2f" % [stat, value])
			Operation.MULTIPLY:
				parts.append("%s x%.2f" % [stat, value])
			Operation.SET:
				parts.append("%s = %.2f" % [stat, value])
			Operation.ADD_PERCENT:
				parts.append("%s +%.0f%%" % [stat, value])
	if parts.is_empty():
		return data.description
	return "%s (%s)" % [data.description, ", ".join(parts)]
