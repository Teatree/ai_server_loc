extends Control

signal options_requested

@onready var _resume_button: Button = $VBox/ResumeButton
@onready var _options_button: Button = $VBox/OptionsButton
@onready var _title_button: Button = $VBox/TitleButton


func _ready() -> void:
    _resume_button.pressed.connect(_on_resume)
    _options_button.pressed.connect(_on_options)
    _title_button.pressed.connect(_on_title)


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        GameFlow.resume()


func _on_resume() -> void:
    GameFlow.resume()


func _on_title() -> void:
    GameFlow.request_return_to_title()


func _on_options() -> void:
    options_requested.emit()
