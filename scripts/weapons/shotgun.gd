extends WeaponBase
class_name Shotgun

signal pellet_spawned(origin: Vector2, direction: Vector2)

func fire(origin: Vector2, direction: Vector2) -> void:
	if not can_fire():
		if data.max_ammo >= 0 and _current_ammo <= 0:
			dry_fire.emit(self)
		return

	super.fire(origin, direction)

	if data:
		_spawn_pellets(origin, direction)

func _spawn_pellets(origin: Vector2, direction: Vector2) -> void:
	if not data:
		return
	var pellet_count: int = data.pellet_count if data.pellet_count > 0 else 1
	var half_spread: float = deg_to_rad(data.spread_angle_degrees / 2.0)
	for i in range(pellet_count):
		var angle_offset: float = randf_range(-half_spread, half_spread)
		var pellet_dir: Vector2 = direction.rotated(angle_offset)
		_spawn_projectile(origin, pellet_dir)

func _spawn_projectile(origin: Vector2, direction: Vector2) -> void:
	if not data:
		return

	var proj: Area2D = Area2D.new()
	proj.set_script(preload("res://scripts/weapons/projectile.gd"))
	proj.global_position = origin
	if proj.has_method("configure"):
		proj.configure(data.damage, data.knockback, direction * data.projectile_speed, get_parent())
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 2.0
	proj.add_child(shape)
	pellet_spawned.emit(origin, direction)
	get_tree().root.add_child.call_deferred(proj)
