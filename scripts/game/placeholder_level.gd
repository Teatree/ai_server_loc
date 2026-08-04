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
var _hud: CanvasLayer = null
var _death_screen = null
var _victory_screen = null


func _ready() -> void:
	_return_button.pressed.connect(_on_return)
	_restart_button.pressed.connect(_on_restart)
	if _checkpoint and _player:
		_checkpoint.activated.connect(_on_checkpoint_activated)
	if _exit_zone:
		_exit_zone.body_entered.connect(_on_exit_entered)
	_configure_director()
	if _director and not _director.spawned.is_connected(Callable(self, "_on_spawn")):
		_director.spawned.connect(_on_spawn)
	_build_navigation_graph()
	_setup_hud()
	_setup_death_screen()
	_setup_victory_screen()
	var save_manager := get_node_or_null("/root/GameFlow/SaveManager") as SaveManager
	if save_manager and save_manager.has_pending_load():
		save_manager.apply_pending_load()
		if _director and _player:
			_director.set_player_position(_player.global_position)
	if _player and _player.health_component:
		_player.health_component.died.disconnect(Callable(_player, "_on_died"))
		_player.health_component.died.connect(_on_player_died)


func _setup_hud() -> void:
	var hud_scene = preload("res://scenes/ui/hud.tscn")
	_hud = hud_scene.instantiate()
	_hud.name = "HUD"
	add_child(_hud)


func _setup_death_screen() -> void:
	var death_scene = preload("res://scenes/ui/death_screen.tscn")
	_death_screen = death_scene.instantiate()
	_death_screen.name = "DeathScreen"
	_death_screen.visible = false
	_death_screen.process_mode = Control.PROCESS_MODE_ALWAYS
	_death_screen.connect("respawn_requested", _on_respawn_requested)
	_death_screen.connect("return_to_title_requested", _on_return_to_title)
	add_child(_death_screen)


func _setup_victory_screen() -> void:
	var victory_scene = preload("res://scenes/ui/victory_screen.tscn")
	_victory_screen = victory_scene.instantiate()
	_victory_screen.name = "VictoryScreen"
	_victory_screen.visible = false
	_victory_screen.process_mode = Control.PROCESS_MODE_ALWAYS
	_victory_screen.connect("return_to_title_requested", _on_return_to_title)
	add_child(_victory_screen)
	if _director:
		_director.victory.connect(_on_victory_screen)


func _on_player_died(damage_info: DamageInfo) -> void:
	if _death_screen:
		_death_screen.visible = true


func _on_respawn_requested() -> void:
	if _death_screen:
		_death_screen.visible = false
	if _player:
		_player.respawn()


func _on_victory_screen() -> void:
	if _victory_label:
		_victory_label.visible = false
	if _victory_screen:
		_victory_screen.visible = true


func _on_return_to_title() -> void:
	GameFlow.request_return_to_title()


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
	var save_manager := get_node_or_null("/root/GameFlow/SaveManager") as SaveManager
	if save_manager and save_manager.has_save():
		save_manager.load_from_disk()
		if save_manager.has_pending_load():
			save_manager.apply_pending_load()
			if _director and _player:
				_director.set_player_position(_player.global_position)
	_restart_encounter()


func _on_checkpoint_activated(position: Vector2) -> void:
	if _player and _player.has_method("set_checkpoint"):
		_player.set_checkpoint(position)
	var save_manager := get_node_or_null("/root/GameFlow/SaveManager") as SaveManager
	if save_manager:
		save_manager.save_to_disk()


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
