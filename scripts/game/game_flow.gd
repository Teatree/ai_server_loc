extends Node

signal game_started
signal game_ended

var _pending_transition: Callable = _nop
var _save_manager: SaveManager = null
var _options_menu: Control = null
var _feedback_manager: Node = null
const FeedbackManagerScript = preload("res://scripts/feedback/feedback_manager.gd")


func _nop() -> void:
	pass


func _ready() -> void:
	_save_manager = SaveManager.new()
	_save_manager.name = "SaveManager"
	add_child(_save_manager)
	_feedback_manager = FeedbackManagerScript.new()
	_feedback_manager.name = "FeedbackManager"
	add_child(_feedback_manager)


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
	if pause_menu.has_signal("options_requested"):
		pause_menu.connect("options_requested", _on_options_requested)


func _on_options_requested() -> void:
	if not _options_menu:
		_options_menu = preload("res://scenes/ui/options_menu.tscn").instantiate()
		_options_menu.name = "OptionsMenu"
		_options_menu.connect("back_requested", _on_options_back)
		get_tree().root.add_child(_options_menu)


func _on_options_back() -> void:
	if _options_menu:
		_options_menu.queue_free()
		_options_menu = null


func resume() -> void:
	if not get_tree().paused:
		return
	var pause_menu := get_tree().root.get_node_or_null("PauseMenu")
	if pause_menu:
		pause_menu.queue_free()
	if _options_menu:
		_options_menu.queue_free()
		_options_menu = null
	get_tree().paused = false


func request_return_to_title() -> void:
	resume()
	game_ended.emit()
	go_to_title()


func has_save() -> bool:
	if not _save_manager:
		return false
	return _save_manager.has_save()


func new_game() -> void:
	if _save_manager:
		_save_manager.clear_save()
	go_to_level()


func continue_game() -> void:
	if not _save_manager:
		go_to_level()
		return
	_save_manager.load_from_disk()
	go_to_level()


func clear_save() -> void:
	if _save_manager:
		_save_manager.clear_save()


func _make_or_get_pause_menu() -> Control:
	var existing := get_tree().root.get_node_or_null("PauseMenu")
	if existing:
		return existing
	var menu := preload("res://scenes/ui/pause_menu.tscn").instantiate()
	menu.name = "PauseMenu"
	return menu
