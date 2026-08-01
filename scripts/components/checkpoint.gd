extends Area2D

class_name Checkpoint

signal activated(position: Vector2)

@export var activation_group: String = "player"

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(activation_group):
		activated.emit(global_position)
