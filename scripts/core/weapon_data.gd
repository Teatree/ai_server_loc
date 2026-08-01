extends Resource
class_name WeaponData

@export var weapon_id: String = "pistol"
@export var display_name: String = "Pistol"
@export var fire_rate: float = 0.35
@export var automatic: bool = false
@export var ammo_per_shot: int = 1
@export var max_ammo: int = 12
@export var reserve_ammo: int = 60
@export var projectile_speed: float = 900.0
@export var damage: float = 15.0
@export var knockback: float = 150.0
@export var recoil_kick: float = 5.0
@export var recoil_recovery: float = 8.0
@export var muzzle_node_name: String = "Muzzle"
