extends RefCounted
class_name PlatformLink

enum LinkType {
	REACHABLE,
	JUMP,
	DROP,
	BLOCKED,
	UNREACHABLE
}

var from_node: PlatformNode = null
var to_node: PlatformNode = null
var link_type: LinkType = LinkType.UNREACHABLE
var jump_height: float = 0.0
var drop_height: float = 0.0
var horizontal_distance: float = 0.0
var traversable: bool = false

func _init(p_from: PlatformNode = null, p_to: PlatformNode = null, p_type: LinkType = LinkType.UNREACHABLE) -> void:
	from_node = p_from
	to_node = p_to
	link_type = p_type
	traversable = p_type != LinkType.BLOCKED and p_type != LinkType.UNREACHABLE
	if from_node and to_node:
		var diff: Vector2 = to_node.position - from_node.position
		horizontal_distance = abs(diff.x)
		if diff.y < 0:
			jump_height = abs(diff.y)
		else:
			drop_height = diff.y

func is_traversable() -> bool:
	return traversable

func get_description() -> String:
	match link_type:
		LinkType.REACHABLE:
			return "reachable"
		LinkType.JUMP:
			return "jump (height: %.1f, dist: %.1f)" % [jump_height, horizontal_distance]
		LinkType.DROP:
			return "drop (height: %.1f, dist: %.1f)" % [drop_height, horizontal_distance]
		LinkType.BLOCKED:
			return "blocked"
		LinkType.UNREACHABLE:
			return "unreachable"
	return "unknown"

