extends Node2D
class_name WeaponBase

signal fired(weapon: WeaponBase, origin: Vector2, direction: Vector2)
signal dry_fire(weapon: WeaponBase)
signal ammo_changed(current: int, maximum: int)
signal state_changed(state: StringName)

@export var data: WeaponData :
	set(value):
		if data and data.weapon_id == value.weapon_id:
			return
		data = value
		_apply_data()

var _current_ammo: int = 0
var _cooldown_remaining: float = 0.0
var _state: StringName = &"idle"
var _can_fire: bool = true

func _ready() -> void:
	_apply_data()
	_state = &"idle"

func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = max(0.0, _cooldown_remaining - delta)
		if _cooldown_remaining <= 0.0:
			_can_fire = true
			_set_state(&"idle")

func can_fire() -> bool:
	if not _can_fire:
		return false
	if data.max_ammo >= 0 and _current_ammo <= 0:
		return false
	if _cooldown_remaining > 0.0:
		return false
	return true

func fire(origin: Vector2, direction: Vector2) -> void:
	if not can_fire():
		if data.max_ammo >= 0 and _current_ammo <= 0:
			dry_fire.emit(self)
		return

	if data.max_ammo >= 0:
		_current_ammo = max(0, _current_ammo - data.ammo_per_shot)
		ammo_changed.emit(_current_ammo, data.max_ammo)

	_cooldown_remaining = data.fire_rate
	_can_fire = false
	_set_state(&"firing")
	_apply_recoil(direction)
	fired.emit(self, origin, direction)

func add_ammo(amount: int) -> void:
	if data.max_ammo < 0:
		return
	_current_ammo = min(data.max_ammo, _current_ammo + amount)
	ammo_changed.emit(_current_ammo, data.max_ammo)

func consume_ammo(amount: int) -> void:
	if data.max_ammo < 0:
		return
	_current_ammo = max(0, _current_ammo - amount)
	ammo_changed.emit(_current_ammo, data.max_ammo)

func set_ammo_full() -> void:
	if data.max_ammo >= 0:
		_current_ammo = data.max_ammo
		ammo_changed.emit(_current_ammo, data.max_ammo)

func get_current_ammo() -> int:
	return _current_ammo

func get_max_ammo() -> int:
	return data.max_ammo if data else -1

func reset() -> void:
	_can_fire = true
	_cooldown_remaining = 0.0
	if data and data.max_ammo >= 0:
		_current_ammo = data.max_ammo
		ammo_changed.emit(_current_ammo, data.max_ammo)
	_set_state(&"idle")

func _apply_data() -> void:
	if not data:
		return
	if data.max_ammo >= 0:
		_current_ammo = data.max_ammo
		ammo_changed.emit(_current_ammo, data.max_ammo)

func _apply_recoil(direction: Vector2) -> void:
	pass

func _set_state(new_state: StringName) -> void:
	_state = new_state
	state_changed.emit(_state)
