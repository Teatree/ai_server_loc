extends Node

signal game_started
signal game_ended

var _pending_transition: Callable = _nop


func _nop() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func go_to_title() -> void:
	_pending_transition = _nop
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func go_to_level() -> void:
	_pending_transition = _nop
	get_tree().change_scene_to_file("res://scenes/levels/placeholder_level.tscn")
	game_started.emit()


func request_pause() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	var pause_menu := _make_or_get_pause_menu()
	get_tree().root.add_child(pause_menu)


func resume() -> void:
	if not get_tree().paused:
		return
	var pause_menu := get_tree().root.get_node_or_null("PauseMenu")
	if pause_menu:
		pause_menu.queue_free()
	get_tree().paused = false


func request_return_to_title() -> void:
	resume()
	game_ended.emit()
	go_to_title()


func _make_or_get_pause_menu() -> Control:
	var existing := get_tree().root.get_node_or_null("PauseMenu")
	if existing:
		return existing
	var menu := Control.new()
	menu.name = "PauseMenu"
	menu.anchors_preset = Control.PRESET_FULL_RECT
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.set_script(preload("res://scripts/ui/pause_menu.gd"))
	return menu
