class_name InteractionAudio
extends Node2D

## Reusable 2D Positional Audio Component for Doors, Terminals, and Interactables in BLACKOUT.
## Manages spatial 2D audio attenuation, pitch variation, and procedural in-memory fallback streams.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

signal sound_played(sound_name: String, position: Vector2, pitch: float, volume_db: float)

@export_group("Spatial Audio Configuration")
## Maximum hearing distance in pixels (500–700px).
@export var max_hearing_distance: float = 650.0
## Distance attenuation curve exponent for spatial audio falloff.
@export var attenuation_factor: float = 1.2
## Base playback volume in decibels.
@export var base_volume_db: float = -3.0

@export_group("Sound Assets (Optional - Procedural Fallback Used if Null)")
@export var open_start_sound: AudioStream = null
@export var open_finish_sound: AudioStream = null
@export var close_start_sound: AudioStream = null
@export var close_finish_sound: AudioStream = null
@export var jammed_sound: AudioStream = null
@export var activate_sound: AudioStream = null
@export var standby_sound: AudioStream = null
@export var objective_complete_sound: AudioStream = null

@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

var _procedural_cache: Dictionary = {}

func _ready() -> void:
	_ensure_audio_player()

## Plays a specific sound cue by name with spatial attenuation and randomized pitch.
func play_sound(sound_type: String, custom_pitch: float = 1.0, volume_offset_db: float = 0.0) -> void:
	_ensure_audio_player()
	var stream: AudioStream = _get_stream_for_type(sound_type)
	if stream != null and audio_player != null:
		audio_player.stream = stream
		audio_player.pitch_scale = custom_pitch * randf_range(0.97, 1.03)
		audio_player.volume_db = base_volume_db + volume_offset_db
		if audio_player.is_inside_tree():
			audio_player.play()
		sound_played.emit(sound_type, global_position, audio_player.pitch_scale, audio_player.volume_db)

## Specific helper triggers for doors and interactables.
func play_open_start() -> void:
	play_sound("open_start")

func play_open_finish() -> void:
	play_sound("open_finish")

func play_close_start() -> void:
	play_sound("close_start")

func play_close_finish() -> void:
	play_sound("close_finish")

func play_jammed() -> void:
	play_sound("jammed", 1.0, 2.0)

func play_activate() -> void:
	play_sound("activate")

func play_standby() -> void:
	play_sound("standby")

func play_objective_complete() -> void:
	play_sound("objective_complete")

## Selects assigned audio asset or retrieves/generates in-memory procedural fallback.
func _get_stream_for_type(sound_type: String) -> AudioStream:
	match sound_type:
		"open_start":
			return open_start_sound if open_start_sound != null else _get_procedural_sound("door_slide")
		"open_finish":
			return open_finish_sound if open_finish_sound != null else _get_procedural_sound("door_latch")
		"close_start":
			return close_start_sound if close_start_sound != null else _get_procedural_sound("door_slide")
		"close_finish":
			return close_finish_sound if close_finish_sound != null else _get_procedural_sound("door_seal")
		"jammed":
			return jammed_sound if jammed_sound != null else _get_procedural_sound("door_jammed")
		"activate":
			return activate_sound if activate_sound != null else _get_procedural_sound("terminal_activate")
		"standby":
			return standby_sound if standby_sound != null else _get_procedural_sound("terminal_standby")
		"objective_complete":
			return objective_complete_sound if objective_complete_sound != null else _get_procedural_sound("objective_complete")
		_:
			return _get_procedural_sound("generic_click")

## Retrieves cached procedural sound or synthesizes it in memory.
func _get_procedural_sound(type_key: String) -> AudioStreamWAV:
	if _procedural_cache.has(type_key):
		return _procedural_cache[type_key]

	var wav: AudioStreamWAV = _synthesize_procedural_sound(type_key)
	_procedural_cache[type_key] = wav
	return wav

## Generates lightweight 8-bit PCM audio waveforms in memory for development placeholders.
func _synthesize_procedural_sound(type_key: String) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.1
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false

	var num_samples: int = 0
	var pcm_data = PackedByteArray()

	match type_key:
		"door_slide":
			# 0.22s pneumatic sliding whoosh with smooth envelope
			duration = 0.22
			num_samples = int(sample_rate * duration)
			pcm_data.resize(num_samples)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = sin(t / duration * PI) # bell curve
				var wave = (randf() * 2.0 - 1.0) * 0.4 + sin(t * 110.0 * TAU) * 0.5
				pcm_data[i] = int(clampf(wave * env * 127.0 + 128.0, 0.0, 255.0))

		"door_latch":
			# 0.06s metallic lock engage click
			duration = 0.06
			num_samples = int(sample_rate * duration)
			pcm_data.resize(num_samples)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = exp(-t * 90.0)
				var wave = sin(t * 320.0 * TAU) * 0.6 + sin(t * 640.0 * TAU) * 0.4
				pcm_data[i] = int(clampf(wave * env * 127.0 + 128.0, 0.0, 255.0))

		"door_seal":
			# 0.10s hydraulic bulkhead seal thud
			duration = 0.10
			num_samples = int(sample_rate * duration)
			pcm_data.resize(num_samples)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = exp(-t * 45.0)
				var wave = sin(t * 85.0 * TAU) * 0.8 + (randf() * 2.0 - 1.0) * 0.2
				pcm_data[i] = int(clampf(wave * env * 127.0 + 128.0, 0.0, 255.0))

		"door_jammed":
			# 0.18s warning malfunction double-buzz
			duration = 0.18
			num_samples = int(sample_rate * duration)
			pcm_data.resize(num_samples)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var pulse = 1.0 if (int(t * 25.0) % 2 == 0) else 0.3
				var wave = sin(t * 480.0 * TAU) * pulse
				pcm_data[i] = int(clampf(wave * 127.0 + 128.0, 0.0, 255.0))

		"terminal_activate":
			# 0.09s crisp electronic confirm chirp (580Hz -> 880Hz)
			duration = 0.09
			num_samples = int(sample_rate * duration)
			pcm_data.resize(num_samples)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var freq = lerpf(580.0, 880.0, t / duration)
				var env = 1.0 - (t / duration)
				var wave = sin(t * freq * TAU) * 0.8
				pcm_data[i] = int(clampf(wave * env * 127.0 + 128.0, 0.0, 255.0))

		"terminal_standby":
			# 0.07s soft digital deactivation blip (700Hz -> 400Hz)
			duration = 0.07
			num_samples = int(sample_rate * duration)
			pcm_data.resize(num_samples)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var freq = lerpf(700.0, 400.0, t / duration)
				var env = 1.0 - (t / duration)
				var wave = sin(t * freq * TAU) * 0.7
				pcm_data[i] = int(clampf(wave * env * 127.0 + 128.0, 0.0, 255.0))

		"objective_complete":
			# 0.24s resonant affirmative chime (three-tone major triad: 523Hz -> 659Hz -> 784Hz)
			duration = 0.24
			num_samples = int(sample_rate * duration)
			pcm_data.resize(num_samples)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = exp(-t * 6.0) * (1.0 - exp(-t * 100.0))
				var freq = 523.25
				if t > 0.08 and t <= 0.16:
					freq = 659.25
				elif t > 0.16:
					freq = 783.99
				var wave = sin(t * freq * TAU) * 0.75 + sin(t * freq * 2.0 * TAU) * 0.25
				pcm_data[i] = int(clampf(wave * env * 127.0 + 128.0, 0.0, 255.0))

		_:
			# Generic 0.04s click
			duration = 0.04
			num_samples = int(sample_rate * duration)
			pcm_data.resize(num_samples)
			for i in range(num_samples):
				var t = float(i) / float(sample_rate)
				var env = exp(-t * 120.0)
				var wave = sin(t * 440.0 * TAU)
				pcm_data[i] = int(clampf(wave * env * 127.0 + 128.0, 0.0, 255.0))

	wav.data = pcm_data
	return wav

func _ensure_audio_player() -> void:
	if audio_player == null:
		audio_player = get_node_or_null("AudioStreamPlayer2D")

	if audio_player == null:
		audio_player = AudioStreamPlayer2D.new()
		audio_player.name = "AudioStreamPlayer2D"
		add_child(audio_player)

	audio_player.max_distance = max_hearing_distance
	audio_player.attenuation = attenuation_factor
	audio_player.panning_strength = 1.0
	audio_player.bus = "Master"
