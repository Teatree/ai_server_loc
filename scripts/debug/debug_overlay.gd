extends CanvasLayer

@onready var _fps_label: Label = $FPSLabel
@onready var _enemies_label: Label = $EnemiesLabel
@onready var _projectiles_label: Label = $ProjectilesLabel
@onready var _director_label: Label = $DirectorLabel
@onready var _player_label: Label = $PlayerLabel
@onready var _weapon_label: Label = $WeaponLabel
@onready var _checkpoint_label: Label = $CheckpointLabel
@onready var _seed_label: Label = $SeedLabel
@onready var _update_timer: Timer = $UpdateTimer

var _player: Node = null
var _weapon: Node = null
var _director: Node = null
var _checkpoint: Node = null
var _projectile_count: int = 0
var _current_phase: int = 0
var _remaining_threat: float = 0.0
var _remaining_slots: int = 0


func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS
    _find_player()
    _find_weapon()
    _find_director()
    _find_checkpoint()
    _connect_signals()
    _count_initial_projectiles()
    _update_all_labels()
    visible = false


func _find_player() -> void:
    _player = get_tree().get_first_node_in_group("player")


func _find_weapon() -> void:
    if _player:
        _weapon = _player.get_node_or_null("WeaponPivot")


func _find_director() -> void:
    _director = get_tree().root.get_node_or_null("PlaceholderLevel/Director")
    if _director:
        if _director.has_method("get_remaining_slots"):
            _remaining_slots = _director.get_remaining_slots()
        if _director.has_method("get_remaining_threat"):
            _remaining_threat = _director.get_remaining_threat()


func _find_checkpoint() -> void:
    _checkpoint = get_tree().root.get_node_or_null("PlaceholderLevel/Checkpoint")


func _connect_signals() -> void:
    if _player and _player.has_node("HealthComponent"):
        var health = _player.get_node("HealthComponent") as Node
        if health and health.has_signal("health_changed"):
            health.health_changed.connect(_on_player_health_changed)
    if _weapon:
        if _weapon.has_signal("ammo_changed"):
            _weapon.ammo_changed.connect(_on_weapon_ammo_changed)
        if _weapon.has_signal("equipped"):
            _weapon.equipped.connect(_on_weapon_equipped)
    if _director:
        if _director.has_signal("phase_changed"):
            _director.phase_changed.connect(_on_director_phase_changed)
        if _director.has_signal("slot_changed"):
            _director.slot_changed.connect(_on_director_slot_changed)
        if _director.has_signal("budget_changed"):
            _director.budget_changed.connect(_on_director_budget_changed)
    if _update_timer:
        _update_timer.timeout.connect(_on_update_timer_timeout)
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)


func _on_player_health_changed(current: float, maximum: float) -> void:
    _update_player_label()


func _on_weapon_ammo_changed(current: int, maximum: int) -> void:
    _update_weapon_label()


func _on_weapon_equipped(weapon: Node) -> void:
    _weapon = weapon
    _update_weapon_label()


func _on_director_phase_changed(phase: int) -> void:
    _current_phase = phase
    _update_director_label()


func _on_director_slot_changed(remaining: int) -> void:
    _remaining_slots = remaining
    _update_director_label()


func _on_director_budget_changed(remaining: float) -> void:
    _remaining_threat = remaining
    _update_director_label()


func _on_update_timer_timeout() -> void:
    _update_fps_label()
    _update_player_label()


func _on_node_added(node: Node) -> void:
    if node is Projectile:
        _projectile_count += 1
        _update_projectiles_label()


func _on_node_removed(node: Node) -> void:
    if node is Projectile:
        _projectile_count = max(0, _projectile_count - 1)
        _update_projectiles_label()


func _count_initial_projectiles() -> void:
    _projectile_count = 0
    for node in get_tree().root.get_children():
        _projectile_count += _count_projectiles_recursive(node)


func _count_projectiles_recursive(node: Node) -> int:
    var count: int = 0
    if node is Projectile:
        count += 1
    for child in node.get_children():
        count += _count_projectiles_recursive(child)
    return count


func _update_all_labels() -> void:
    _update_fps_label()
    _update_enemies_label()
    _update_projectiles_label()
    _update_director_label()
    _update_player_label()
    _update_weapon_label()
    _update_checkpoint_label()
    _update_seed_label()


func _update_fps_label() -> void:
    if _fps_label:
        _fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _update_enemies_label() -> void:
    if _enemies_label and _director:
        var max_enemies = _director.max_living_enemies
        var living = max_enemies - _remaining_slots
        _enemies_label.text = "Enemies: %d/%d" % [living, max_enemies]
    elif _enemies_label:
        _enemies_label.text = "Enemies: 0"


func _update_projectiles_label() -> void:
    if _projectiles_label:
        _projectiles_label.text = "Projectiles: %d" % _projectile_count


func _update_director_label() -> void:
    if _director_label and _director:
        var phase_name = "Recovery"
        match _current_phase:
            1: phase_name = "Pressure"
            2: phase_name = "Escalation"
            3: phase_name = "Peak"
        var max_threat = _director.max_threat_budget
        _director_label.text = "Director: %s | Threat: %.0f/%.0f | Slots: %d/%d" % [
            phase_name, max_threat - _remaining_threat, max_threat,
            _director.max_living_enemies - _remaining_slots, _director.max_living_enemies
        ]


func _update_player_label() -> void:
    if _player_label and _player:
        var health = _player.get_node_or_null("HealthComponent") as Node
        var current = 0.0
        var max_hp = 100.0
        if health:
            current = health.current_health if health.has_method("get") else 0.0
            max_hp = health.max_health if health.has_method("get") else 100.0
        var pos = _player.global_position
        _player_label.text = "Player: HP %.0f/%.0f Pos (%.0f, %.0f)" % [
            current, max_hp, pos.x, pos.y
        ]


func _update_weapon_label() -> void:
    if _weapon_label and _weapon:
        var name = _weapon.data.display_name if _weapon.has_method("get") and _weapon.data else "None"
        var ammo = _weapon.get_current_ammo() if _weapon.has_method("get_current_ammo") else 0
        var max_ammo = _weapon.get_max_ammo() if _weapon.has_method("get_max_ammo") else 0
        _weapon_label.text = "Weapon: %s | Ammo: %d/%d" % [name, ammo, max_ammo]


func _update_checkpoint_label() -> void:
    if _checkpoint_label and _checkpoint:
        var pos = _checkpoint.global_position
        _checkpoint_label.text = "Checkpoint: (%.0f, %.0f)" % [pos.x, pos.y]


func _update_seed_label() -> void:
    if _seed_label and _director and _director.has_method("get_seed"):
        _seed_label.text = "Seed: %d" % _director.get_seed()


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_debug"):
        visible = not visible
