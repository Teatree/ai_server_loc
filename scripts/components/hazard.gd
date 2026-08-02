extends Area2D
class_name Hazard

signal player_damaged(damage_info: DamageInfo)

@export var damage_amount: float = 10.0
@export var damage_type: DamageInfo.DamageType = DamageInfo.DamageType.ENVIRONMENTAL
@export var damage_cooldown: float = 0.5

var _can_damage: bool = true
var _cooldown_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if not _can_damage:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_can_damage = true

func _on_body_entered(body: Node2D) -> void:
	if not _can_damage:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		var info: DamageInfo = DamageInfo.new(
			damage_amount,
			damage_type,
			self,
			global_position,
			Vector2.ZERO,
			0.0,
			false
		)
		body.take_damage(info)
		player_damaged.emit(info)
		_can_damage = false
		_cooldown_timer = damage_cooldown
