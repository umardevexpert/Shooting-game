extends Node

var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var combat := false
var cursor := 0
var combat_mix := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for category in ["Music", "SFX", "UI", "Weapon", "Environment"]:
		var index := AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(index, category)
		AudioServer.set_bus_send(index, "Master")
	for id in ["shot", "reload", "hit", "explosion", "ui", "win", "fail", "step", "ambience", "music", "alert", "pickup"]:
		streams[id] = load("res://assets/audio/%s.wav" % id)
	for i in range(16):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	music = AudioStreamPlayer.new()
	add_child(music)
	music.bus = "Music"
	music.stream = streams.music
	(streams.music as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	(streams.music as AudioStreamWAV).loop_end = 176400
	if DisplayServer.get_name() != "headless": music.play()
	ambience = AudioStreamPlayer.new()
	add_child(ambience)
	ambience.bus = "Environment"
	ambience.stream = streams.ambience
	(streams.ambience as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	(streams.ambience as AudioStreamWAV).loop_end = 88200
	if DisplayServer.get_name() != "headless": ambience.play()
	apply_settings()

func apply_settings() -> void:
	for category in ["Master", "Music", "SFX", "UI", "Weapon", "Environment"]:
		var index := AudioServer.get_bus_index(category)
		var volume: float = Profile.data.settings[category.to_lower()]
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))

func play(id: String, category: String = "SFX", pitch: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless": return
	if not streams.has(id): return
	var voice := voices[cursor]
	cursor = (cursor + 1) % voices.size()
	voice.bus = category
	voice.stream = streams[id]
	voice.pitch_scale = pitch
	voice.volume_db = -4.0
	voice.play()

func _process(delta: float) -> void:
	combat_mix = move_toward(combat_mix, 1.0 if combat and not get_tree().paused else 0.0, delta)
	music.pitch_scale = lerpf(0.9, 1.06, combat_mix)
	music.volume_db = lerpf(-7.0, -2.0, combat_mix)

func _exit_tree() -> void:
	music.stop()
	ambience.stop()
	for voice in voices:
		voice.stop()
		voice.stream = null
	music.stream = null
	ambience.stream = null
	streams.clear()
