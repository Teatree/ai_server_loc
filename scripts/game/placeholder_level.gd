extends Node2D

signal exit_reached

@onready var _return_button: Button = $Player/CanvasLayer/ReturnToTitle
@onready var _restart_button: Button = $RestartEncounter
@onready var _victory_label: Label = $VictoryLabel
@onready var _checkpoint: Checkpoint = $Checkpoint
@onready var _player: CharacterBody2D = $Player
@onready var _exit_zone: Area2D = $ExitZone
@onready var _nav_graph: PlatformGraph = $PlatformGraph
@onready var _director: Director = $Director

const _PLATFORM_NODE_SCRIPT = preload("res://scripts/navigation/platform_node.gd")
const _PLATFORM_LINK_SCRIPT = preload("res://scripts/navigation/platform_link.gd")

var _spawned_enemies: Array[Node] = []


func _ready() -> void:
	_return_button.pressed.connect(_on_return)
	_restart_button.pressed.connect(_on_restart)
	if _checkpoint and _player:
		_checkpoint.activated.connect(_on_checkpoint_activated)
	if _exit_zone:
		_exit_zone.body_entered.connect(_on_exit_entered)
	_configure_director()
	_build_navigation_graph()


func _build_navigation_graph() -> void:
	if not _nav_graph:
		return
	_nav_graph.clear()
	var PlatformNode = load("res://scripts/navigation/platform_node.gd")
	var PlatformLink = load("res://scripts/navigation/platform_link.gd")
	var ground1 = PlatformNode.new(&"Ground1", $Ground1.global_position)
	var ground2 = PlatformNode.new(&"Ground2", $Ground2.global_position)
	var elev1 = PlatformNode.new(&"ElevatedPlatform1", $ElevatedPlatform1.global_position)
	var elev2 = PlatformNode.new(&"ElevatedPlatform2", $ElevatedPlatform2.global_position)
	var elev3 = PlatformNode.new(&"ElevatedPlatform3", $ElevatedPlatform3.global_position)
	for node in [ground1, ground2, elev1, elev2, elev3]:
		_nav_graph.add_node(node)
	_nav_graph.add_link(ground1, elev1, PlatformLink.LinkType.JUMP)
	_nav_graph.add_link(elev1, elev2, PlatformLink.LinkType.JUMP)
	_nav_graph.add_link(elev2, elev3, PlatformLink.LinkType.JUMP)
	_nav_graph.add_link(elev3, ground2, PlatformLink.LinkType.DROP)
	_nav_graph.add_link(ground1, ground2, PlatformLink.LinkType.REACHABLE)


func _on_return() -> void:
	GameFlow.request_return_to_title()


func _on_restart() -> void:
	_restart_encounter()


func _on_checkpoint_activated(position: Vector2) -> void:
	if _player and _player.has_method("set_checkpoint"):
		_player.set_checkpoint(position)


func _on_exit_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		exit_reached.emit()


func _on_victory() -> void:
	_victory_label.visible = true


func _configure_director() -> void:
	if not _director:
		return
	var markers: Array = _collect_spawn_markers()
	_director.configure(0, markers, _player.global_position if _player else Vector2.ZERO)
	_director.spawned.connect(_on_spawn)
	_director.victory.connect(_on_victory)


func _collect_spawn_markers() -> Array:
	var result: Array = []
	for child in get_children():
		if child is Marker2D and child.has_method("is_active"):
			result.append(child)
	return result


func _on_spawn(enemy_type: StringName, position: Vector2) -> void:
	var packed: PackedScene = load("res://scenes/enemies/%s.tscn" % enemy_type)
	if not packed:
		return
	var instance: Node = packed.instantiate()
	instance.global_position = position
	add_child(instance)
	_spawned_enemies.append(instance)


func _clear_encounter() -> void:
	for enemy: Node in _spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_spawned_enemies.clear()
	if _director:
		_director.reset()
	_victory_label.visible = false


func _restart_encounter() -> void:
	_clear_encounter()
	_configure_director()
