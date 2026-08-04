extends CanvasLayer

@onready var _health_label: Label = $HealthLabel
@onready var _ammo_label: Label = $AmmoLabel
@onready var _weapon_label: Label = $WeaponLabel
@onready var _reload_label: Label = $ReloadLabel
@onready var _phase_label: Label = $PhaseLabel

var _player: Node = null
var _weapon: Node = null
var _director: Node = null


func _ready() -> void:
    _find_player()
    _find_weapon()
    _find_director()
    _connect_signals()
    _update_all_labels()


func _find_player() -> void:
    var player = get_tree().get_first_node_in_group("player")
    if player:
        _player = player.get_node_or_null("HealthComponent")


func _find_weapon() -> void:
    var player = get_tree().get_first_node_in_group("player")
    if player:
        _weapon = player.get_node_or_null("WeaponPivot")


func _find_director() -> void:
    _director = get_tree().root.get_node_or_null("PlaceholderLevel/Director")


func _connect_signals() -> void:
    if _player and _player.has_signal("health_changed"):
        _player.health_changed.connect(_on_health_changed)
    if _weapon and _weapon.has_signal("ammo_changed"):
        _weapon.ammo_changed.connect(_on_ammo_changed)
    if _weapon and _weapon.has_signal("state_changed"):
        _weapon.state_changed.connect(_on_weapon_state_changed)
    if _weapon and _weapon.has_signal("equipped"):
        _weapon.equipped.connect(_on_weapon_equipped)
    if _director and _director.has_signal("phase_changed"):
        _director.phase_changed.connect(_on_phase_changed)


func _on_health_changed(current: float, maximum: float) -> void:
    if _health_label:
        _health_label.text = "Health: %d/%d" % [int(current), int(maximum)]


func _on_ammo_changed(current: int, maximum: int) -> void:
    if _ammo_label:
        _ammo_label.text = "Ammo: %d/%d" % [current, maximum]


func _on_weapon_state_changed(state: StringName) -> void:
    if _reload_label:
        if state == &"reloading":
            _reload_label.visible = true
        else:
            _reload_label.visible = false


func _on_weapon_equipped(weapon: Node) -> void:
    if _weapon_label and weapon and weapon.data:
        _weapon_label.text = weapon.data.display_name


func _on_phase_changed(phase: int) -> void:
    if _phase_label:
        var phase_name = "Recovery"
        match phase:
            1: phase_name = "Pressure"
            2: phase_name = "Escalation"
            3: phase_name = "Peak"
        _phase_label.text = "Phase: %s" % phase_name


func _update_all_labels() -> void:
    if _player:
        _on_health_changed(_player.current_health, _player.max_health)
    if _weapon and _weapon.has_method("get_current_ammo"):
        _on_ammo_changed(_weapon.get_current_ammo(), _weapon.get_max_ammo())
    if _weapon and _weapon.has_method("get_data") and _weapon.data:
        _on_weapon_equipped(_weapon)
