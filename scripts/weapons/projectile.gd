extends Area2D
class_name Projectile

var damage: float = 15.0
var knockback: float = 150.0
var velocity: Vector2 = Vector2.RIGHT * 900.0
var source: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

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

func _resolve_hit(target: Node) -> void:
	if target.has_method("take_damage"):
		var info: DamageInfo = DamageInfo.new(damage, DamageInfo.DamageType.BALLISTIC, source, global_position, velocity.normalized(), knockback)
		target.take_damage(info)
