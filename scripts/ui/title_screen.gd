extends Control

signal new_game_requested

@onready var _start_button: Button = $VBox/StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	new_game_requested.emit()
