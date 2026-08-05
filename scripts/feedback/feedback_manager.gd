extends Node
class_name FeedbackManager

signal shake_requested(intensity: float, duration: float)
signal hit_stop_requested(duration: float)
signal effect_requested(effect_type: StringName, position: Vector2)

@export var max_shake_intensity: float = 30.0
@export var max_shake_duration: float = 0.5
@export var max_concurrent_hit_stops: int = 4

const CameraShakeScript = preload("res://scripts/feedback/camera_shake.gd")
const HitStopScript = preload("res://scripts/feedback/hit_stop.gd")

var _camera: Camera2D = null
var _shake: Node = null
var _hit_stop: Node = null
var _active_effects: Array[Node] = []

func _ready() -> void:
    _shake = CameraShakeScript.new()
    _shake.name = "CameraShake"
    _shake.max_intensity = max_shake_intensity
    _shake.max_duration = max_shake_duration
    add_child(_shake)
    _hit_stop = HitStopScript.new()
    _hit_stop.name = "HitStop"
    add_child(_hit_stop)
    _find_camera()

func _find_camera() -> void:
    var players: Array[Node] = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        var player: Node = players[0]
        _camera = player.get_node_or_null("Camera2D") as Camera2D
        if not _camera:
            _camera = Camera2D.new()
            _camera.name = "FeedbackCamera"
            player.add_child(_camera)
        _shake.camera = _camera

func request_shake(intensity: float, duration: float) -> void:
    shake_requested.emit(intensity, duration)
    _shake.add_shake(intensity, duration)

func request_hit_stop(duration: float) -> void:
    hit_stop_requested.emit(duration)
    _hit_stop.request_stop(duration)

func spawn_effect(effect_type: StringName, position: Vector2) -> void:
    effect_requested.emit(effect_type, position)
    var effect: Node = _create_effect(effect_type, position)
    if effect:
        _active_effects.append(effect)
        effect.tree_exited.connect(_on_effect_exited.bind(effect))

func _on_effect_exited(effect: Node) -> void:
    _active_effects.erase(effect)

func _create_effect(type: StringName, position: Vector2) -> Node:
    match type:
        &"hit_flash":
            return _spawn_hit_flash(position)
        &"damage_number":
            return _spawn_damage_number(position)
    return null

func _spawn_hit_flash(position: Vector2) -> Node:
    var flash: Node2D = preload("res://scenes/effects/hit_flash.tscn").instantiate()
    flash.global_position = position
    get_tree().current_scene.add_child(flash)
    return flash

func _spawn_damage_number(position: Vector2) -> Node:
    var number: Node2D = preload("res://scenes/effects/damage_number.tscn").instantiate()
    number.global_position = position
    get_tree().current_scene.add_child(number)
    return number