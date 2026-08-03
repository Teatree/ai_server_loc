extends Node2D

signal exit_reached

@onready var _return_button: Button = $Player/CanvasLayer/ReturnToTitle
@onready var _checkpoint: Checkpoint = $Checkpoint
@onready var _player: CharacterBody2D = $Player
@onready var _exit_zone: Area2D = $ExitZone
@onready var _nav_graph: PlatformGraph = $PlatformGraph

const _PLATFORM_NODE_SCRIPT = preload("res://scripts/navigation/platform_node.gd")
const _PLATFORM_LINK_SCRIPT = preload("res://scripts/navigation/platform_link.gd")


func _ready() -> void:
	_return_button.pressed.connect(_on_return)
	if _checkpoint and _player:
		_checkpoint.activated.connect(_on_checkpoint_activated)
	if _exit_zone:
		_exit_zone.body_entered.connect(_on_exit_entered)
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


func _on_checkpoint_activated(position: Vector2) -> void:
	if _player and _player.has_method("set_checkpoint"):
		_player.set_checkpoint(position)


func _on_exit_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		exit_reached.emit()
