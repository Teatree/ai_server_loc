extends WeaponBase
class_name Pistol

@onready var _muzzle: Marker2D = _find_muzzle()
@onready var _raycast: RayCast2D = _find_raycast()

func _ready() -> void:
	if not data:
		var d: WeaponData = WeaponData.new()
		data = d
	super._ready()

func fire(origin: Vector2, direction: Vector2) -> void:
	if not can_fire():
		if data.max_ammo >= 0 and _current_ammo <= 0:
			dry_fire.emit(self)
		return

	if not _check_muzzle_clear(origin, direction):
		return

	super.fire(origin, direction)

	if data:
		_spawn_projectile(origin, direction)

func _check_muzzle_clear(origin: Vector2, direction: Vector2) -> bool:
	if not _raycast:
		return true

	_raycast.global_position = origin
	_raycast.target_position = direction * 50.0
	_raycast.force_raycast_update()

	if _raycast.is_colliding():
		var collider: Object = _raycast.get_collider()
		if collider and not collider.is_in_group("projectile"):
			return false
	return true

func _spawn_projectile(origin: Vector2, direction: Vector2) -> void:
	if not data:
		return

	var proj: Node2D = Node2D.new()
	proj.set_script(preload("res://scripts/weapons/projectile.gd"))
	proj.global_position = origin
	if proj.has_method("configure"):
		proj.configure(data.damage, data.knockback, direction * data.projectile_speed, get_parent())
	get_tree().root.add_child.call_deferred(proj)

func _find_muzzle() -> Marker2D:
	if data and data.muzzle_node_name and data.muzzle_node_name != "":
		return get_node_or_null(data.muzzle_node_name) as Marker2D
	return get_node_or_null("Muzzle") as Marker2D

func _find_raycast() -> RayCast2D:
	return get_node_or_null("MuzzleRaycast") as RayCast2D

func _apply_recoil(direction: Vector2) -> void:
	pass
