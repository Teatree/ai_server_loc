extends Area2D
class_name Pickup

signal picked_up(pickup_type: StringName, amount: float)

@export var pickup_type: StringName = &"health"
@export var amount: float = 25.0
@export var applies_once: bool = true

var _collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _collected and applies_once:
		return
	if body.is_in_group("player"):
		_collected = true
		_apply_pickup(body)
		picked_up.emit(pickup_type, amount)
		queue_free()

func _apply_pickup(player: Node2D) -> void:
	match pickup_type:
		&"health":
			if player.has_method("heal"):
				player.heal(amount)
			elif player.has_node("HealthComponent"):
				var health: HealthComponent = player.get_node("HealthComponent")
				if health:
					health.heal(amount)
		&"ammo":
			if player.has_method("add_ammo"):
				player.add_ammo(int(amount))
			elif player.has_node("WeaponPivot"):
				var pivot: Node2D = player.get_node("WeaponPivot")
				if pivot:
					for child in pivot.get_children():
						if child.has_method("add_ammo"):
							child.add_ammo(int(amount))
							break
