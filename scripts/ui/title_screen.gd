extends Control

@onready var _vbox: VBoxContainer = $VBox
@onready var _new_game_button: Button = _vbox.get_node("NewGameButton")
@onready var _continue_button: Button = _vbox.get_node("ContinueButton")
@onready var _clear_save_button: Button = _vbox.get_node("ClearSaveButton")
@onready var _exit_button: Button = _vbox.get_node("ExitButton")


func _ready() -> void:
	_update_save_buttons()
	_new_game_button.pressed.connect(_on_new_game)
	_continue_button.pressed.connect(_on_continue)
	_clear_save_button.pressed.connect(_on_clear_save)
	_exit_button.pressed.connect(get_tree().quit)


func _update_save_buttons() -> void:
	var has_save: bool = false
	if GameFlow.has_method("has_save"):
		has_save = GameFlow.has_save()
	_continue_button.disabled = not has_save
	_clear_save_button.disabled = not has_save


func _on_new_game() -> void:
	GameFlow.new_game()


func _on_continue() -> void:
	GameFlow.continue_game()


func _on_clear_save() -> void:
	GameFlow.clear_save()
	_update_save_buttons()
