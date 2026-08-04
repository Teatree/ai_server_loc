extends Control

signal back_requested

@onready var _back_button: Button = $Panel/VBox/BackButton


func _ready() -> void:
    _back_button.pressed.connect(_on_back)


func _on_back() -> void:
    back_requested.emit()
