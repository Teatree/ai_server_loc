extends Node2D

signal navigation_state_changed(state: StringName)
signal traversal_completed(node: PlatformNode)
signal traversal_failed(reason: String)
signal stuck_recovery_attempted(attempt: int)

@export var graph: PlatformGraph = null
@export var jump_velocity: float = 180.0
@export var drop_velocity: float = 250.0
@export var horizontal_speed: float = 80.0
@export var arrival_threshold: float = 8.0
@export var stuck_velocity_threshold: float = 5.0
@export var stuck_time_threshold: float = 2.0

var _state: StringName = &"idle"
var _current_node: PlatformNode = null
var _target_node: PlatformNode = null
var _active_link: PlatformLink = null
var _traversal_active: bool = false
var _stuck_timer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var _body: CharacterBody2D = null
var _enabled: bool = false

func _ready() -> void:
	_enabled = true

func set_body(body: CharacterBody2D) -> void:
	_body = body

func set_graph(new_graph: PlatformGraph) -> void:
	graph = new_graph
	if graph and not graph.target_classified.is_connected(_on_graph_classified):
		graph.target_classified.connect(_on_graph_classified)
	if graph and not graph.traversal_started.is_connected(_on_graph_traversal_started):
		graph.traversal_started.connect(_on_graph_traversal_started)
	if graph and not graph.stuck_recovery_triggered.is_connected(_on_graph_stuck_recovery):
		graph.stuck_recovery_triggered.connect(_on_graph_stuck_recovery)

func get_state() -> StringName:
	return _state

func is_navigating() -> bool:
	return _state == &"traversing"

func is_stuck() -> bool:
	return _state == &"stuck"

func is_traversing() -> bool:
	return _state == &"traversing"

func get_current_node() -> PlatformNode:
	return _current_node

func get_target_node() -> PlatformNode:
	return _target_node

func request_jump_to(target_node: PlatformNode) -> bool:
	if not graph or not target_node or not _enabled:
		return false
	var start: PlatformNode = _current_node if _current_node else graph.find_closest_node(_body.global_position if _body else global_position)
	if not start:
		return false
	var result: Dictionary = graph.traverse_by_type(start, PlatformLink.LinkType.JUMP)
	if not result.success:
		_set_state(&"stuck")
		traversal_failed.emit(result.message)
		if result.get("needs_recovery", false):
			graph.trigger_stuck_recovery()
		return false
	_target_node = result.node
	_active_link = result.link
	_current_node = result.node
	_stuck_timer = 0.0
	_last_position = _body.global_position if _body else global_position
	_set_state(&"traversing")
	return true

func request_drop_to(target_node: PlatformNode) -> bool:
	if not graph or not target_node or not _enabled:
		return false
	var start: PlatformNode = _current_node if _current_node else graph.find_closest_node(_body.global_position if _body else global_position)
	if not start:
		return false
	var result: Dictionary = graph.traverse_by_type(start, PlatformLink.LinkType.DROP)
	if not result.success:
		_set_state(&"stuck")
		traversal_failed.emit(result.message)
		if result.get("needs_recovery", false):
			graph.trigger_stuck_recovery()
		return false
	_target_node = result.node
	_active_link = result.link
	_current_node = result.node
	_stuck_timer = 0.0
	_last_position = _body.global_position if _body else global_position
	_set_state(&"traversing")
	return true

func navigate_to(target_node: PlatformNode) -> bool:
	if not graph or not target_node or not _enabled:
		return false
	var start: PlatformNode = _current_node if _current_node else graph.find_closest_node(_body.global_position if _body else global_position)
	if not start:
		return false
	var link_type: PlatformLink.LinkType = graph.classify_target(start, target_node)
	if link_type == PlatformLink.LinkType.UNREACHABLE or link_type == PlatformLink.LinkType.BLOCKED:
		_set_state(&"stuck")
		traversal_failed.emit("target is %s" % PlatformLink.LinkType.keys()[link_type].to_lower())
		return false
	var result: Dictionary = graph.traverse(start, target_node)
	if not result.success:
		_set_state(&"stuck")
		traversal_failed.emit(result.message)
		if result.get("needs_recovery", false):
			graph.trigger_stuck_recovery()
		return false
	_target_node = result.node
	_active_link = result.link
	_current_node = result.node
	_stuck_timer = 0.0
	_last_position = _body.global_position if _body else global_position
	_set_state(&"traversing")
	return true

func _physics_process(delta: float) -> void:
	if not _enabled or _state != &"traversing" or not _body:
		return
	if not _target_node or not _active_link:
		_set_state(&"idle")
		return
	var current_pos: Vector2 = _body.global_position
	var to_target: Vector2 = _target_node.position - current_pos
	var dist: float = to_target.length()
	if dist < arrival_threshold:
		_set_state(&"idle")
		traversal_completed.emit(_target_node)
		return
	var dir_x: float = sign(to_target.x) if abs(to_target.x) > 1.0 else 0.0
	match _active_link.link_type:
		PlatformLink.LinkType.JUMP:
			if _body.is_on_floor():
				_body.velocity = Vector2(dir_x * horizontal_speed, -jump_velocity)
			else:
				_body.velocity.x = dir_x * horizontal_speed
		PlatformLink.LinkType.DROP:
			if _body.is_on_floor() and to_target.y > arrival_threshold:
				_body.velocity = Vector2(dir_x * horizontal_speed, drop_velocity)
			else:
				_body.velocity.x = dir_x * horizontal_speed
		_:
			_body.velocity = Vector2(dir_x * horizontal_speed, _body.velocity.y)
	_check_stuck(delta)

func _check_stuck(delta: float) -> void:
	if not _body:
		return
	var moved: float = _body.global_position.distance_to(_last_position)
	if moved < stuck_velocity_threshold:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
	_last_position = _body.global_position
	if _stuck_timer >= stuck_time_threshold:
		_stuck_timer = 0.0
		if graph:
			graph._stuck_count += 1
			if graph.is_stuck():
				graph.trigger_stuck_recovery()
				_set_state(&"idle")

func request_recovery() -> void:
	if graph:
		graph.trigger_stuck_recovery()
	_stuck_timer = 0.0
	_last_position = _body.global_position if _body else global_position
	_set_state(&"idle")

func reset() -> void:
	_stuck_timer = 0.0
	_current_node = null
	_target_node = null
	_active_link = null
	_traversal_active = false
	_set_state(&"idle")

func set_enabled(value: bool) -> void:
	_enabled = value
	if not _enabled:
		reset()

func update_current_node(position: Vector2) -> void:
	if graph:
		var closest: PlatformNode = graph.find_closest_node(position)
		if closest:
			_current_node = closest

func _set_state(new_state: StringName) -> void:
	if _state == new_state:
		return
	_state = new_state
	navigation_state_changed.emit(_state)

func _on_graph_classified(from_node: PlatformNode, to_node: PlatformNode, link_type: PlatformLink.LinkType) -> void:
	pass

func _on_graph_traversal_started(from_node: PlatformNode, to_node: PlatformNode, link: PlatformLink) -> void:
	pass

func _on_graph_stuck_recovery(node: PlatformNode, attempt: int) -> void:
	_set_state(&"idle")
	stuck_recovery_attempted.emit(attempt)
