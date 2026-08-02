extends Node2D

signal exit_reached

@onready var _return_button: Button = $Player/CanvasLayer/ReturnToTitle
@onready var _checkpoint: Checkpoint = $Checkpoint
@onready var _player: CharacterBody2D = $Player
@onready var _exit_zone: Area2D = $ExitZone


func _ready() -> void:
	_return_button.pressed.connect(_on_return)
	if _checkpoint and _player:
		_checkpoint.activated.connect(_on_checkpoint_activated)
	if _exit_zone:
		_exit_zone.body_entered.connect(_on_exit_entered)


func _on_return() -> void:
	GameFlow.request_return_to_title()


func _on_checkpoint_activated(position: Vector2) -> void:
	if _player and _player.has_method("set_checkpoint"):
		_player.set_checkpoint(position)


func _on_exit_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		exit_reached.emit()
