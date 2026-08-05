extends Node
class_name CameraShake

@export var max_intensity: float = 30.0
@export var max_duration: float = 0.5

var camera: Camera2D = null
var _requests: Array[Dictionary] = []

func _process(delta: float) -> void:
    if not camera:
        return
    _tick(delta)
    _apply()

func _tick(delta: float) -> void:
    var remaining: Array[Dictionary] = []
    for req in _requests:
        req.duration -= delta
        if req.duration > 0.0:
            remaining.append(req)
    _requests = remaining

func _apply() -> void:
    if _requests.is_empty():
        camera.offset = Vector2.ZERO
        return
    var sum: float = 0.0
    var longest: float = 0.0
    for req in _requests:
        sum += req.intensity
        longest = max(longest, req.duration)
    var intensity: float = min(sum, max_intensity)
    var strength: float = intensity * (longest / max_duration)
    camera.offset = Vector2(
        randf() * strength * 2.0 - strength,
        randf() * strength * 2.0 - strength
    )

func add_shake(intensity: float, duration: float) -> void:
    _requests.append({"intensity": intensity, "duration": duration})

func reset() -> void:
    _requests.clear()
    if camera:
        camera.offset = Vector2.ZERO