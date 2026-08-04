extends Control

signal respawn_requested
signal return_to_title_requested

@onready var _resume_button: Button = $Panel/VBox/ResumeButton
@onready var _title_button: Button = $Panel/VBox/TitleButton


func _ready() -> void:
    _resume_button.pressed.connect(_on_respawn)
    _title_button.pressed.connect(_on_title)


func _on_respawn() -> void:
    hide()
    respawn_requested.emit()


func _on_title() -> void:
    return_to_title_requested.emit()
