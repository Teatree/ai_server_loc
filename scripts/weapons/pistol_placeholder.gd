extends Node2D

@onready var _muzzle: Marker2D = $Muzzle

var _cooldown := false

func _ready() -> void:
	look_at(get_global_mouse_position())


func fire() -> void:
	if _cooldown:
		return
	_cooldown = true
	await get_tree().create_timer(0.25).timeout
	_cooldown = false

	var origin := _muzzle.global_position if _muzzle else global_position
	var dir := global_transform.x
	_spawn_projectile(origin, dir)


func _spawn_projectile(origin: Vector2, dir: Vector2) -> void:
	var proj := Node2D.new()
	proj.global_position = origin
	proj.set_script(preload("res://scripts/weapons/projectile_placeholder.gd"))
	proj.velocity = dir * 900.0
	get_tree().root.add_child.call_deferred(proj)
