extends Node
class_name PlatformGraph

signal target_classified(from_node: PlatformNode, to_node: PlatformNode, link_type: int)
signal traversal_started(from_node: PlatformNode, to_node: PlatformNode, link: PlatformLink)
signal traversal_failed(from_node: PlatformNode, to_node: PlatformNode, reason: String)
signal stuck_recovery_triggered(node: PlatformNode, attempt: int)

@export var max_stuck_retries: int = 3
@export var default_jump_speed: float = 150.0
@export var default_drop_speed: float = 200.0
@export var horizontal_tolerance: float = 5.0
@export var vertical_tolerance: float = 2.0

var nodes: Array = []
var links: Array = []
var _node_index: Dictionary = {}
var _link_index: Dictionary = {}

var _stuck_count: int = 0
var _current_node: PlatformNode = null
var _target_node: PlatformNode = null
var _active_link: PlatformLink = null
var _traversal_active: bool = false

func add_node(node: PlatformNode) -> void:
	if not node or _node_index.has(node.name):
		return
	nodes.append(node)
	_node_index[node.name] = node

func remove_node(node: PlatformNode) -> void:
	if not node or not _node_index.has(node.name):
		return
	nodes.erase(node)
	_node_index.erase(node.name)
	for link in links:
		if link.from_node == node or link.to_node == node:
			var key: String = _link_key(link.from_node, link.to_node)
			_link_index.erase(key)
	links.clear()

func add_link(from_node: PlatformNode, to_node: PlatformNode, link_type: int) -> PlatformLink:
	if not from_node or not to_node:
		return null
	var key: String = _link_key(from_node, to_node)
	if _link_index.has(key):
		return _link_index[key]
	var link: PlatformLink = PlatformLink.new(from_node, to_node, link_type)
	links.append(link)
	_link_index[key] = link
	return link

func remove_link(from_node: PlatformNode, to_node: PlatformNode) -> void:
	var key: String = _link_key(from_node, to_node)
	if not _link_index.has(key):
		return
	var link: PlatformLink = _link_index[key]
	links.erase(link)
	_link_index.erase(key)

func get_link(from_node: PlatformNode, to_node: PlatformNode) -> PlatformLink:
	var key: String = _link_key(from_node, to_node)
	return _link_index.get(key, null)

func get_links_from(node: PlatformNode) -> Array:
	var result: Array = []
	for link in links:
		if link.from_node == node:
			result.append(link)
	return result

func get_links_to(node: PlatformNode) -> Array:
	var result: Array = []
	for link in links:
		if link.to_node == node:
			result.append(link)
	return result

func classify_target(from: PlatformNode, to: PlatformNode) -> int:
	var link: PlatformLink = get_link(from, to)
	if link:
		return link.link_type
	var from_idx: int = nodes.find(from)
	var to_idx: int = nodes.find(to)
	if from_idx < 0 or to_idx < 0:
		return PlatformLink.LinkType.UNREACHABLE
	var diff_y: float = to.position.y - from.position.y
	var diff_x: float = abs(to.position.x - from.position.x)
	if diff_y > 80.0 and diff_y <= 200.0 and diff_x < 200.0:
		return PlatformLink.LinkType.DROP
	elif diff_y < -40.0 and diff_x < 150.0:
		return PlatformLink.LinkType.JUMP
	elif diff_y >= -10.0 and diff_y <= 30.0 and diff_x < 120.0:
		return PlatformLink.LinkType.REACHABLE
	return PlatformLink.LinkType.UNREACHABLE

func traverse(from_node: PlatformNode, to_node: PlatformNode) -> Dictionary:
	if not from_node or not to_node:
		return {"success": false, "node": null, "link": null, "message": "invalid nodes", "needs_recovery": false}
	if from_node == to_node:
		return {"success": true, "node": from_node, "link": null, "message": "", "needs_recovery": false}
	var link: PlatformLink = get_link(from_node, to_node)
	if not link or not link.is_traversable():
		_stuck_count += 1
		_try_trigger_stuck_recovery(from_node)
		return {"success": false, "node": null, "link": null, "message": "no traversable link", "needs_recovery": _stuck_count >= max_stuck_retries}
	_stuck_count = 0
	_current_node = to_node
	_target_node = to_node
	_active_link = link
	_traversal_active = true
	traversal_started.emit(from_node, to_node, link)
	return {"success": true, "node": to_node, "link": link, "message": "", "needs_recovery": false}

func traverse_by_type(from_node: PlatformNode, link_type: int) -> Dictionary:
	var candidates: Array = []
	for link in get_links_from(from_node):
		if link.link_type == link_type and link.is_traversable():
			candidates.append(link)
	if candidates.is_empty():
		_stuck_count += 1
		_try_trigger_stuck_recovery(from_node)
		return {"success": false, "node": null, "link": null, "message": "no link of type %s" % PlatformLink.LinkType.keys()[link_type], "needs_recovery": _stuck_count >= max_stuck_retries}
	_stuck_count = 0
	var chosen: PlatformLink = candidates[0]
	_current_node = chosen.to_node
	_target_node = chosen.to_node
	_active_link = chosen
	_traversal_active = true
	traversal_started.emit(from_node, chosen.to_node, chosen)
	return {"success": true, "node": chosen.to_node, "link": chosen, "message": "", "needs_recovery": false}

func is_stuck() -> bool:
	return _stuck_count >= max_stuck_retries

func trigger_stuck_recovery() -> void:
	var recovery_node: PlatformNode = _current_node if _current_node else (nodes[0] if nodes.size() > 0 else null)
	_stuck_count = 0
	_traversal_active = false
	_active_link = null
	if recovery_node:
		_target_node = recovery_node
	_current_node = recovery_node
	stuck_recovery_triggered.emit(recovery_node, 0)

func reset_stuck() -> void:
	_stuck_count = 0
	_traversal_active = false
	_active_link = null

func get_current_node() -> PlatformNode:
	return _current_node

func get_target_node() -> PlatformNode:
	return _target_node

func is_traversing() -> bool:
	return _traversal_active

func find_closest_node(position: Vector2, max_distance: float = 1000.0) -> PlatformNode:
	var closest: PlatformNode = null
	var closest_dist: float = INF
	for node in nodes:
		var d: float = position.distance_to(node.position)
		if d < max_distance and d < closest_dist:
			closest_dist = d
			closest = node
	return closest

func clear() -> void:
	nodes.clear()
	links.clear()
	_node_index.clear()
	_link_index.clear()
	_stuck_count = 0
	_current_node = null
	_target_node = null
	_active_link = null
	_traversal_active = false

func _try_trigger_stuck_recovery(node: PlatformNode) -> void:
	if _stuck_count >= max_stuck_retries:
		trigger_stuck_recovery()

func _link_key(from: PlatformNode, to: PlatformNode) -> String:
	return "%s->%s" % [from.name, to.name]
