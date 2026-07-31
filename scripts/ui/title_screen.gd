extends Control

@onready var _vbox: VBoxContainer = $VBox
@onready var _start_button: Button = _vbox.get_node("StartButton")
@onready var _exit_button: Button = _vbox.get_node("ExitButton")


func _ready() -> void:
	_start_button.pressed.connect(GameFlow.go_to_level)
	_exit_button.pressed.connect(get_tree().quit)
