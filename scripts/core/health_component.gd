extends Node
class_name HealthComponent

signal health_changed(current: float, maximum: float)
signal damaged(damage_info: DamageInfo)
signal died(damage_info: DamageInfo)
signal healed(amount: float)

@export var max_health: float = 100.0
@export var invulnerability_duration: float = 0.5
@export var can_be_damaged: bool = true

var current_health: float = 0.0
var is_dead: bool = false
var is_invulnerable: bool = false
var _invulnerability_timer: float = 0.0
var _death_emitted: bool = false

func _ready() -> void:
	current_health = max_health

func _process(delta: float) -> void:
	if is_invulnerable:
		_invulnerability_timer -= delta
		if _invulnerability_timer <= 0.0:
			is_invulnerable = false

func take_damage(damage_info: DamageInfo) -> void:
	if not can_be_damaged or is_invulnerable or is_dead:
		return
	
	current_health -= damage_info.amount
	health_changed.emit(current_health, max_health)
	damaged.emit(damage_info)
	
	if current_health <= 0.0:
		current_health = 0.0
		is_dead = true
		if not _death_emitted:
			_death_emitted = true
			died.emit(damage_info)
	
	start_invulnerability()

func start_invulnerability() -> void:
	is_invulnerable = true
	_invulnerability_timer = invulnerability_duration

func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	healed.emit(amount)

func reset() -> void:
	current_health = max_health
	is_dead = false
	is_invulnerable = false
	_invulnerability_timer = 0.0
	_death_emitted = false
	health_changed.emit(current_health, max_health)
