extends Control

signal return_to_title_requested

@onready var _title_button: Button = $Panel/VBox/TitleButton


func _ready() -> void:
    _title_button.pressed.connect(_on_title)


func _on_title() -> void:
    return_to_title_requested.emit()
