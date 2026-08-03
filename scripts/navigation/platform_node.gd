extends RefCounted
class_name PlatformNode

var name: StringName = &""
var position: Vector2 = Vector2.ZERO
var node_ref: Node2D = null
var tags: Array[StringName] = []

func _init(p_name: StringName = &"", p_pos: Vector2 = Vector2.ZERO) -> void:
	name = p_name
	position = p_pos

func distance_to(other: PlatformNode) -> float:
	return position.distance_to(other.position)

func has_tag(tag: StringName) -> bool:
	return tag in tags

