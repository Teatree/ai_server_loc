extends Resource
class_name DamageInfo

enum DamageType {
	BALLISTIC,
	MELEE,
	EXPLOSIVE,
	ENVIRONMENTAL
}

@export var amount: float = 0.0
@export var damage_type: DamageType = DamageType.BALLISTIC
@export var source: Node = null
@export var hit_position: Vector2 = Vector2.ZERO
@export var hit_direction: Vector2 = Vector2.RIGHT
@export var knockback: float = 0.0
@export var is_critical: bool = false
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
