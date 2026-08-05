extends ColorRect

@export var fade_duration: float = 0.15

func _ready() -> void:
    var tween: Tween = create_tween()
    tween.tween_property(self, "color:a", 0.0, fade_duration)
    tween.tween_callback(queue_free)