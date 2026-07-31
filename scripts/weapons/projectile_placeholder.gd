extends Node2D

@export var velocity := Vector2.RIGHT * 800.0

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	if global_position.x < -200 or global_position.x > 2000 or global_position.y < -200 or global_position.y > 1200:
		queue_free()
