extends Node2D

@onready var _return_button: Button = $Player/CanvasLayer/ReturnToTitle


func _ready() -> void:
	_return_button.pressed.connect(_on_return)


func _on_return() -> void:
	GameFlow.request_return_to_title()
