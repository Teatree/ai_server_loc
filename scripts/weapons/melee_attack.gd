extends Node2D
class_name MeleeAttack

signal melee_hit(target: Node, damage: float, knockback: float)
signal melee_swing_started()
signal melee_swing_completed()

@export var hit_shape: RectangleShape2D:
	set(value):
		hit_shape = value
		_refresh_shape()

@export var collision_mask: int = 1

var _cooldown_remaining: float = 0.0
var _swing_active: bool = false
var _has_hit_this_swing: bool = false
var _hit_bodies: Array[Node] = []
var _scanned_bodies: Array[Node] = []

var _area: Area2D = null
var _shape: CollisionShape2D = null


func _ready() -> void:
	_area = Area2D.new()
	_area.name = "MeleeHitArea"
	_area.collision_layer = 0
	_area.collision_mask = collision_mask
	_area.monitoring = false
	add_child(_area)
	_shape = CollisionShape2D.new()
	_shape.shape = hit_shape if hit_shape else RectangleShape2D.new()
	_shape.disabled = true
	_area.add_child(_shape)
	_area.body_entered.connect(Callable(self, "_on_body_entered"))


func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = max(0.0, _cooldown_remaining - delta)
		if _cooldown_remaining <= 0.0:
			_swing_active = false


func can_melee() -> bool:
	return _cooldown_remaining <= 0.0 and not _swing_active


func attack(origin: Vector2, facing: int, weapon_data: WeaponData) -> void:
	if not can_melee():
		return
	if not weapon_data:
		return
	_cooldown_remaining = weapon_data.melee_cooldown
	_swing_active = true
	_has_hit_this_swing = false
	_hit_bodies.clear()
	_scanned_bodies.clear()
	global_position = origin
	if _shape and _shape.shape is RectangleShape2D:
		_shape.shape.size = Vector2.ONE * weapon_data.melee_range
	_shape.disabled = false
	_area.monitoring = true
	_scan_body_targets(weapon_data)
	if _scanned_bodies.is_empty() and _hit_bodies.is_empty():
		# Physics-space query is the authoritative source for body detection.
		# It works independently of Area2D monitoring state and group membership.
		_physics_scan(weapon_data)
	melee_swing_started.emit()


func _on_body_entered(body: Node) -> void:
	if not _swing_active:
		return
	if _has_hit_this_swing:
		return
	if body in _hit_bodies:
		return
	if not _is_valid_target(body):
		return
	if body in _scanned_bodies:
		if body not in _hit_bodies:
			_hit_bodies.append(body)
		return
	_scanned_bodies.append(body)
	_hit_bodies.append(body)
	_has_hit_this_swing = true
	_resolve_hit(body, _get_current_weapon_data())


func _resolve_hit(target: Node, weapon_data: WeaponData) -> void:
	var dmg: float = weapon_data.melee_damage if weapon_data else 20.0
	var kb: float = weapon_data.melee_knockback if weapon_data else 250.0
	melee_hit.emit(target, dmg, kb)
	if target.has_method("interrupt"):
		target.interrupt()


func _is_valid_target(body: Node) -> bool:
	if not body is Node2D:
		return false
	if body.is_in_group("enemy"):
		return true
	if body.is_in_group("player"):
		return true
	return false


func _get_current_weapon_data() -> WeaponData:
	var pivot: Node = get_parent()
	if pivot and pivot.has_method("get_data"):
		return pivot.get_data()
	if pivot and pivot.has_method("data"):
		return pivot.data
	return null


func end_swing() -> void:
	_swing_active = false
	_has_hit_this_swing = false
	_hit_bodies.clear()
	_scanned_bodies.clear()
	_shape.disabled = true
	_area.set_deferred("monitoring", false)
	melee_swing_completed.emit()


func interrupt() -> void:
	_swing_active = false
	_has_hit_this_swing = false
	_hit_bodies.clear()
	_scanned_bodies.clear()
	_shape.disabled = true
	_area.set_deferred("monitoring", false)


func reset() -> void:
	_cooldown_remaining = 0.0
	_swing_active = false
	_has_hit_this_swing = false
	_hit_bodies.clear()
	_scanned_bodies.clear()
	_shape.disabled = true
	_area.set_deferred("monitoring", false)


func _scan_body_targets(weapon_data: WeaponData) -> void:
	var origin: Vector2 = global_position
	var range_f: float = weapon_data.melee_range if weapon_data else 60.0
	var all_enemies: Array = get_tree().get_nodes_in_group("enemy")
	for body: Node in all_enemies:
		if not body is Node2D:
			continue
		if body in _hit_bodies or body in _scanned_bodies:
			continue
		if not _is_valid_target(body):
			continue
		var dist: float = body.global_position.distance_to(origin)
		if dist <= range_f:
			_register_scanned_hit(body, weapon_data)
			return


func _physics_scan(weapon_data: WeaponData) -> void:
	if not _shape or not _shape.shape:
		return
	if get_world_2d():
		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		if space_state:
			var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
			query.shape = _shape.shape
			query.transform = global_transform
			query.collision_mask = collision_mask
			for result in space_state.intersect_shape(query):
				var collider: Object = result.collider
				if collider is Node2D and _is_valid_target(collider) and collider not in _hit_bodies and collider not in _scanned_bodies:
					_register_scanned_hit(collider, weapon_data)
					return
	# Fallback: scan parent subtree for valid targets in range
	_scan_parent_subtree(global_position, weapon_data.melee_range, weapon_data)


func _scan_parent_subtree(origin: Vector2, range_f: float, weapon_data: WeaponData) -> void:
	var scope: Node = get_parent() if get_parent() else self
	for child: Node in scope.get_children():
		_scan_tree_recursive(child, origin, range_f, weapon_data)


func _scan_tree_recursive(node: Node, origin: Vector2, range_f: float, weapon_data: WeaponData) -> void:
	if node == self:
		return
	if node is CollisionShape2D:
		return
	if node is Node2D and _is_valid_target(node) and node not in _hit_bodies and node not in _scanned_bodies:
		var dist: float = node.global_position.distance_to(origin)
		if dist <= range_f:
			_register_scanned_hit(node, weapon_data)
			return
	for child: Node in node.get_children():
		_scan_tree_recursive(child, origin, range_f, weapon_data)
	# Physics shape query fallback for environments where group scanning is unreliable
	if _shape and _shape.shape and get_world_2d():
		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		if space_state:
			var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
			query.shape = _shape.shape
			query.transform = global_transform
			query.collision_mask = collision_mask
			var results: Array = space_state.intersect_shape(query)
			for result in results:
				var collider: Object = result.collider
				if collider is Node2D and _is_valid_target(collider) and collider not in _hit_bodies and collider not in _scanned_bodies:
					_register_scanned_hit(collider, weapon_data)
					return


func _register_scanned_hit(target: Node, weapon_data: WeaponData) -> void:
	_scanned_bodies.append(target)
	_hit_bodies.append(target)
	_has_hit_this_swing = true
	_resolve_hit(target, weapon_data)


func _refresh_shape() -> void:
	if _shape:
		_shape.shape = hit_shape if hit_shape else RectangleShape2D.new()
