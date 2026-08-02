extends WeaponBase
class_name AutomaticRifle

func _process(delta: float) -> void:
	super._process(delta)
	if data and data.automatic and Input.is_action_pressed("fire"):
		if can_fire():
			var origin: Vector2 = global_position
			var muzzle: Marker2D = get_node_or_null("Muzzle") as Marker2D
			if muzzle:
				origin = muzzle.global_position
			fire(origin, Vector2.RIGHT.rotated(global_rotation))
