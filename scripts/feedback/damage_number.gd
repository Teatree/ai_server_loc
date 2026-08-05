extends Label

@export var rise_speed: float = 60.0
@export var fade_duration: float = 0.5

func set_value(value: float) -> void:
    text = str(int(value))

func _ready() -> void:
    var tween: Tween = create_tween()
    tween.parallel().tween_property(self, "position:y", position.y - 40.0, fade_duration)
    tween.parallel().tween_property(self, "modulate:a", 0.0, fade_duration)
    tween.tween_callback(queue_free)