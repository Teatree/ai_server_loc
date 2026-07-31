extends Resource
class_name MovementConfig

@export_group("Ground Movement")
@export var ground_acceleration: float = 1200.0
@export var ground_deceleration: float = 1400.0
@export var max_ground_speed: float = 220.0
@export var ground_friction: float = 800.0

@export_group("Air Movement")
@export var air_acceleration: float = 900.0
@export var air_deceleration: float = 600.0
@export var max_air_speed: float = 180.0
@export var air_control: float = 0.6

@export_group("Jumping")
@export var jump_velocity: float = -320.0
@export var jump_cut_multiplier: float = 0.4
@export var variable_jump_gravity: float = 600.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_group("Gravity")
@export var gravity: float = 980.0
@export var max_fall_speed: float = 500.0
@export var fast_fall_multiplier: float = 1.3

@export_group("Dodge")
@export var dodge_speed: float = 400.0
@export var dodge_duration: float = 0.18
@export var dodge_cooldown: float = 0.8
@export var dodge_gravity_scale: float = 0.3

@export_group("Platforms")
@export var drop_through_speed: float = 50.0
@export var moving_platform_lerp: float = 15.0

@export_group("Hit Stun")
@export var hit_stun_duration: float = 0.25
@export var knockback_gravity_scale: float = 0.5
