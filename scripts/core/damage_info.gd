extends Resource
class_name DamageInfo

enum DamageType {
	BALLISTIC,
	MELEE,
	EXPLOSIVE,
	ENVIRONMENTAL
}

var amount: float = 0.0
var damage_type: DamageType = DamageType.BALLISTIC
var source: Node = null
var hit_position: Vector2 = Vector2.ZERO
var hit_direction: Vector2 = Vector2.RIGHT
var knockback: float = 0.0
var is_critical: bool = false
func _init(
	p_amount: float = 0.0,
	p_type: DamageType = DamageType.BALLISTIC,
	p_source: Node = null,
	p_position: Vector2 = Vector2.ZERO,
	p_direction: Vector2 = Vector2.RIGHT,
	p_knockback: float = 0.0,
	p_critical: bool = false
) -> void:
	amount = p_amount
	damage_type = p_type
	source = p_source
	hit_position = p_position
	hit_direction = p_direction
	knockback = p_knockback
	is_critical = p_critical
