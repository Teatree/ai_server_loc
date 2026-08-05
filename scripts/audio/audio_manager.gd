extends Node

signal music_volume_changed(volume: float)
signal sfx_volume_changed(volume: float)
signal ui_volume_changed(volume: float)

const BUS_MASTER: int = 0
const BUS_MUSIC: int = 1
const BUS_SFX: int = 2
const BUS_UI: int = 3

const AudioEmitterScript = preload("res://scripts/audio/audio_emitter.gd")

@export var max_pool_size: int = 16

var _pool: Array[AudioStreamPlayer] = []
var _active_transient: Array[AudioStreamPlayer] = []
var _music_emitter: AudioStreamPlayer = null

func _ready() -> void:
	_ensure_buses()
	get_tree().scene_changed.connect(_on_scene_changed)

func _ensure_buses() -> void:
	while AudioServer.get_bus_count() < 4:
		AudioServer.add_bus()
	AudioServer.set_bus_name(BUS_MUSIC, "Music")
	AudioServer.set_bus_send(BUS_MUSIC, "Master")
	AudioServer.set_bus_name(BUS_SFX, "SFX")
	AudioServer.set_bus_send(BUS_SFX, "Master")
	AudioServer.set_bus_name(BUS_UI, "UI")
	AudioServer.set_bus_send(BUS_UI, "Master")

func _on_scene_changed() -> void:
	for emitter in _active_transient:
		if emitter.sound_owner == &"sfx" or emitter.sound_owner == &"ui":
			emitter.stop()
	_active_transient.clear()

func play_sfx(stream: AudioStream, position: Vector2 = Vector2.ZERO) -> AudioStreamPlayer:
	var emitter: AudioStreamPlayer = _acquire_transient()
	emitter.sound_owner = &"sfx"
	emitter.bus = "SFX"
	emitter.stream = stream
	if position != Vector2.ZERO:
		emitter.global_position = position
	emitter.play()
	_active_transient.append(emitter)
	return emitter

func play_ui(stream: AudioStream) -> AudioStreamPlayer:
	var emitter: AudioStreamPlayer = _acquire_transient()
	emitter.sound_owner = &"ui"
	emitter.bus = "UI"
	emitter.stream = stream
	emitter.play()
	_active_transient.append(emitter)
	return emitter

func play_music(stream: AudioStream) -> AudioStreamPlayer:
	if not _music_emitter:
		_music_emitter = AudioEmitterScript.new()
		_music_emitter.name = "MusicEmitter"
		_music_emitter.bus = "Music"
		_music_emitter.sound_owner = &"music"
		add_child(_music_emitter)
	_music_emitter.stream = stream
	_music_emitter.play()
	return _music_emitter

func _acquire_transient() -> AudioStreamPlayer:
	for emitter in _pool:
		if not emitter.playing:
			return emitter
	if _pool.size() < max_pool_size:
		var emitter: AudioStreamPlayer = AudioEmitterScript.new()
		emitter.name = "AudioEmitter"
		emitter.finished.connect(_on_transient_finished.bind(emitter))
		add_child(emitter)
		_pool.append(emitter)
		return emitter
	var emitter: AudioStreamPlayer = AudioEmitterScript.new()
	emitter.name = "AudioEmitterTemp"
	emitter.finished.connect(_on_transient_finished.bind(emitter))
	add_child(emitter)
	return emitter

func _on_transient_finished(emitter: AudioStreamPlayer) -> void:
	_active_transient.erase(emitter)
	if _pool.has(emitter):
		emitter.sound_owner = &"unowned"
	else:
		emitter.queue_free()

func _process(delta: float) -> void:
	_release_idle_transients()

func _release_idle_transients() -> void:
	var to_release: Array[AudioStreamPlayer] = []
	for emitter in _active_transient:
		if not emitter.playing:
			to_release.append(emitter)
	for emitter in to_release:
		_active_transient.erase(emitter)
		if _pool.has(emitter):
			emitter.sound_owner = &"unowned"
		else:
			emitter.queue_free()

func set_music_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(BUS_MUSIC, linear_to_db(volume))
	music_volume_changed.emit(volume)

func get_music_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(BUS_MUSIC))

func set_sfx_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(BUS_SFX, linear_to_db(volume))
	sfx_volume_changed.emit(volume)

func get_sfx_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(BUS_SFX))

func set_ui_volume(volume: float) -> void:
	AudioServer.set_bus_volume_db(BUS_UI, linear_to_db(volume))
	ui_volume_changed.emit(volume)

func get_ui_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(BUS_UI))

func get_active_transient_count() -> int:
	return _active_transient.size()

func get_pool_size() -> int:
	return _pool.size()
