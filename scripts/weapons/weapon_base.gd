extends Node2D
class_name WeaponBase

signal fired(weapon: WeaponBase, origin: Vector2, direction: Vector2)
signal dry_fire(weapon: WeaponBase)
signal ammo_changed(current: int, maximum: int)
signal state_changed(state: StringName)
signal noise_emitted(position: Vector2, strength: float)
signal reload_completed()
signal equipped(weapon: WeaponBase)

@export var data: WeaponData :
	set(value):
		data = value
		_apply_data()

var _current_ammo: int = 0
var _reserve_ammo: int = 0
var _cooldown_remaining: float = 0.0
var _state: StringName = &"idle"
var _can_fire: bool = true
var _reloading: bool = false
var _current_recoil: float = 0.0

func _ready() -> void:
	_apply_data()
	_state = &"idle"

func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = max(0.0, _cooldown_remaining - delta)
		if _cooldown_remaining <= 0.0:
			_can_fire = true
			_set_state(&"idle")
	if data and data.recoil_recovery > 0.0:
		_current_recoil = max(0.0, _current_recoil - data.recoil_recovery * delta)

func can_fire() -> bool:
	if not _can_fire or _reloading:
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
	if data:
		noise_emitted.emit(origin, data.noise_strength)

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

func get_reserve_ammo() -> int:
	return _reserve_ammo

func get_max_ammo() -> int:
	return data.max_ammo if data else -1

func get_recoil() -> float:
	return _current_recoil

func can_reload() -> bool:
	if not data or data.max_ammo < 0:
		return false
	if _reloading:
		return false
	if _current_ammo >= data.max_ammo:
		return false
	if _reserve_ammo <= 0:
		return false
	return true

func reload() -> void:
	if not can_reload():
		return
	_reloading = true
	_set_state(&"reloading")
	var needed: int = data.max_ammo - _current_ammo
	var transfer: int = min(needed, _reserve_ammo)
	_reserve_ammo -= transfer
	_current_ammo += transfer
	ammo_changed.emit(_current_ammo, data.max_ammo)
	_reloading = false
	_set_state(&"idle")
	reload_completed.emit()

func reset() -> void:
	_can_fire = true
	_cooldown_remaining = 0.0
	_reloading = false
	_current_recoil = 0.0
	if data and data.max_ammo >= 0:
		_current_ammo = data.max_ammo
		_reserve_ammo = data.reserve_ammo
		ammo_changed.emit(_current_ammo, data.max_ammo)
	_set_state(&"idle")

func _apply_data() -> void:
	if not data:
		return
	if data.max_ammo >= 0:
		_current_ammo = data.max_ammo
		_reserve_ammo = data.reserve_ammo
		ammo_changed.emit(_current_ammo, data.max_ammo)
	equipped.emit(self)

func _apply_recoil(direction: Vector2) -> void:
	if not data:
		return
	var limit: float = data.recoil_kick * 10.0
	_current_recoil = min(_current_recoil + data.recoil_kick, limit)

func _set_state(new_state: StringName) -> void:
	_state = new_state
	state_changed.emit(_state)
