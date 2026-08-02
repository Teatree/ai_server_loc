extends Area2D
class_name Projectile

var damage: float = 15.0
var knockback: float = 150.0
var velocity: Vector2 = Vector2.RIGHT * 900.0
var source: Node = null
var _shape: CollisionShape2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_shape = CollisionShape2D.new()
	_shape.shape = CircleShape2D.new()
	_shape.shape.radius = 2.0
	add_child(_shape)
	_check_initial_overlaps()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	if global_position.x < -200 or global_position.x > 2000 or global_position.y < -200 or global_position.y > 1200:
		queue_free()

func configure(p_damage: float, p_knockback: float, p_velocity: Vector2, p_source: Node) -> void:
	damage = p_damage
	knockback = p_knockback
	velocity = p_velocity
	source = p_source

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("player"):
		_resolve_hit(body)
	queue_free()

func _on_area_entered(area: Node) -> void:
	if area.is_in_group("enemy") or area.is_in_group("player"):
		_resolve_hit(area)
	queue_free()

func _check_initial_overlaps() -> void:
	if not _shape or not get_world_2d():
		return
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _shape.shape
	query.transform = _shape.global_transform
	query.collision_mask = collision_mask
	var results: Array = space_state.intersect_shape(query)
	for result in results:
		var collider: Object = result.collider
		if collider is Node2D and (collider.is_in_group("enemy") or collider.is_in_group("player")):
			_resolve_hit(collider)
			queue_free()
			return

func _resolve_hit(target: Node) -> void:
	if target.has_method("take_damage"):
		var info: DamageInfo = DamageInfo.new(damage, DamageInfo.DamageType.BALLISTIC, source, global_position, velocity.normalized(), knockback)
		target.take_damage(info)
