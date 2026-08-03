extends Marker2D
class_name SpawnMarker

@export var category: StringName = &"shambler"
@export var enemy_type: StringName = &"shambler"
@export var active: bool = true


func is_active() -> bool:
	return active


func get_enemy_type() -> StringName:
	return enemy_type
