extends Node
class_name HitStop

@export var default_duration: float = 0.1
@export var freeze_time_scale: float = 0.01

var _pending: int = 0
var _time_remaining: float = 0.0
var _saved_scale: float = 1.0

func _process(delta: float) -> void:
    if _pending <= 0:
        return
    _time_remaining -= delta
    if _time_remaining <= 0.0:
        _restore()

func request_stop(duration: float = default_duration) -> void:
    if _pending == 0:
        _saved_scale = Engine.time_scale
        Engine.time_scale = freeze_time_scale
    _pending += 1
    _time_remaining = max(_time_remaining, duration)

func _restore() -> void:
    _pending = 0
    _time_remaining = 0.0
    Engine.time_scale = _saved_scale

func is_active() -> bool:
    return _pending > 0