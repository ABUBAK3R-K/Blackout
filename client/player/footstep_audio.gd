class_name FootstepAudio
extends Node2D

## 2D Multiplayer Movement Audio & Proximity Cue Component for BLACKOUT.
## Handles speed-scaled footstep cadence, spatial 2D audio attenuation for nearby players,
## randomized pitch/volume variations, and seamless blackout audio awareness.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

signal footstep_triggered(step_index: int, pos: Vector2, pitch: float, volume_db: float)

@export_group("Audio Settings")
## Primary footstep audio stream asset (optional, procedural fallback used if null).
@export var footstep_stream: AudioStream = null
## Array of varied footstep sound streams to cycle through.
@export var footstep_sounds: Array[AudioStream] = []
## Base playback volume in decibels.
@export var base_volume_db: float = -4.0
## Maximum distance in pixels at which remote footsteps can be heard (500–700px).
@export var max_hearing_distance: float = 650.0
## Distance attenuation curve exponent for spatial audio falloff.
@export var attenuation_factor: float = 1.2

@export_group("Cadence Settings")
## Base time in seconds between footsteps at standard movement speed (250 px/s).
@export var base_step_interval: float = 0.38
## Reference movement speed in px/s matching base_step_interval.
@export var reference_speed: float = 250.0
## Minimum velocity magnitude to consider the player moving.
@export var min_speed_threshold: float = 15.0

@export_group("Variation Settings")
## Minimum pitch scale multiplier for footstep variation.
@export var min_pitch_scale: float = 0.93
## Maximum pitch scale multiplier for footstep variation.
@export var max_pitch_scale: float = 1.07

@onready var audio_player: AudioStreamPlayer2D = $FootstepPlayer

## Active timer accumulating movement time towards next footstep.
var step_timer: float = 0.0
## Total steps taken by this player instance.
var total_steps: int = 0
## Whether the player was actively moving on the previous physics tick.
var is_moving: bool = false
## Previous global position for delta speed calculation on remote puppets.
var last_global_pos: Vector2 = Vector2.ZERO

## Cached procedurally generated fallback stream.
var _procedural_stream: AudioStreamWAV = null

func _ready() -> void:
	last_global_pos = global_position
	_ensure_audio_player()
	_init_fallback_stream()

func _physics_process(delta: float) -> void:
	var current_speed: float = _calculate_current_speed(delta)

	# Check if player is moving above threshold
	var parent_can_move: bool = true
	var parent_node = get_parent()
	if parent_node != null and "can_move" in parent_node:
		parent_can_move = parent_node.can_move

	if current_speed >= min_speed_threshold and parent_can_move:
		is_moving = true

		# Calculate speed-adjusted step cadence (faster movement -> shorter interval)
		var speed_ratio: float = reference_speed / maxf(current_speed, 50.0)
		var current_interval: float = clampf(base_step_interval * speed_ratio, 0.20, 0.70)

		step_timer += delta
		if step_timer >= current_interval:
			step_timer = 0.0
			play_footstep(current_speed)
	else:
		# Reset timer when stopped to prevent immediate double-steps on resuming
		is_moving = false
		step_timer = 0.0

## Plays a footstep sound with spatial attenuation and randomized pitch.
func play_footstep(speed: float = 250.0) -> void:
	total_steps += 1
	var pitch: float = randf_range(min_pitch_scale, max_pitch_scale)
	var vol_offset: float = randf_range(-0.75, 0.75)
	var final_vol: float = base_volume_db + vol_offset

	if audio_player != null:
		var stream_to_play: AudioStream = _select_audio_stream()
		if stream_to_play != null:
			audio_player.stream = stream_to_play
			audio_player.pitch_scale = pitch
			audio_player.volume_db = final_vol
			if audio_player.is_inside_tree():
				audio_player.play()

	footstep_triggered.emit(total_steps, global_position, pitch, final_vol)

## Manual trigger helper for testing or scripted movement sequences.
func trigger_step_manually() -> void:
	play_footstep(reference_speed)

## Calculates current movement speed from parent velocity or position delta.
func _calculate_current_speed(delta: float) -> float:
	var parent_node = get_parent()
	if parent_node != null and "velocity" in parent_node:
		var vel: Vector2 = parent_node.velocity
		if vel.length_squared() > 1.0:
			last_global_pos = global_position
			return vel.length()

	# Fallback to positional delta (useful for remote puppets being lerped)
	if delta > 0.0001:
		var dist: float = global_position.distance_to(last_global_pos)
		last_global_pos = global_position
		return dist / delta

	last_global_pos = global_position
	return 0.0

## Selects an audio stream from assigned assets or procedural fallback.
func _select_audio_stream() -> AudioStream:
	if not footstep_sounds.is_empty():
		var idx = randi() % footstep_sounds.size()
		return footstep_sounds[idx]
	elif footstep_stream != null:
		return footstep_stream
	return _procedural_stream

## Ensures AudioStreamPlayer2D child node exists and is configured for 2D spatial audio.
func _ensure_audio_player() -> void:
	if audio_player == null:
		audio_player = get_node_or_null("FootstepPlayer")

	if audio_player == null:
		audio_player = AudioStreamPlayer2D.new()
		audio_player.name = "FootstepPlayer"
		add_child(audio_player)

	audio_player.max_distance = max_hearing_distance
	audio_player.attenuation = attenuation_factor
	audio_player.panning_strength = 1.0
	audio_player.bus = "Master"

## Creates a lightweight in-memory procedural footstep click/thud as an asset fallback.
func _init_fallback_stream() -> void:
	if footstep_stream != null or not footstep_sounds.is_empty():
		return

	# Generate 35ms soft sci-fi boot contact sound (8-bit PCM WAV in memory)
	var sample_rate: int = 22050
	var duration_sec: float = 0.035
	var num_samples: int = int(sample_rate * duration_sec)
	var pcm_data = PackedByteArray()
	pcm_data.resize(num_samples)

	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var envelope: float = exp(-t * 85.0) # fast decay
		# 80 Hz thud + 240 Hz tap + light noise
		var wave: float = sin(t * 80.0 * TAU) * 0.6 + sin(t * 240.0 * TAU) * 0.3 + (randf() * 2.0 - 1.0) * 0.1
		var sample_val: int = int(clampf(wave * envelope * 127.0 + 128.0, 0.0, 255.0))
		pcm_data[i] = sample_val

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = pcm_data
	_procedural_stream = wav
