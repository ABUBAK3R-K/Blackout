extends Node

## Centralized Audio Manager for BLACKOUT (Member 8: Audio & QA Lead)
## Handles dynamic soundscapes, environmental ambience crossfading,
## gameplay event SFX, UI audio cues, and procedural waveform fallback generation.

const AudioRegistry = preload("res://assets/audio/audio_registry.gd")

signal audio_event_played(event_id: StringName, bus: StringName)
signal ambience_changed(new_ambience_id: StringName)

# Active audio players
var _ambience_player: AudioStreamPlayer = null
var _secondary_ambience_player: AudioStreamPlayer = null
var _active_ambience_id: StringName = &""

var _music_player: AudioStreamPlayer = null
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_player: AudioStreamPlayer = null

# In-memory cache for loaded audio streams and procedurally synthesized streams
var _stream_cache: Dictionary = {}

# SFX Player pool size
const SFX_POOL_SIZE: int = 12

# Ambience crossfade parameters
var _is_crossfading: bool = false
var _crossfade_duration: float = 1.0
var _crossfade_elapsed: float = 0.0
var _crossfade_from_volume: float = -80.0
var _crossfade_to_volume: float = 0.0

func _ready() -> void:
	_setup_audio_nodes()
	print("[AudioManager] Initialized successfully. SFX pool size: %d" % SFX_POOL_SIZE)

func _process(delta: float) -> void:
	if _is_crossfading:
		_process_crossfade(delta)

## Sets up dedicated AudioStreamPlayers for Ambience, Music, UI, and the SFX pool.
func _setup_audio_nodes() -> void:
	# Primary Ambience Player
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayerPrimary"
	_ambience_player.bus = AudioRegistry.BUS_AMBIENCE
	add_child(_ambience_player)
	
	# Secondary Ambience Player (for cross-fading)
	_secondary_ambience_player = AudioStreamPlayer.new()
	_secondary_ambience_player.name = "AmbiencePlayerSecondary"
	_secondary_ambience_player.bus = AudioRegistry.BUS_AMBIENCE
	_secondary_ambience_player.volume_db = -80.0
	add_child(_secondary_ambience_player)
	
	# Music Player (Meltdown alarm & Stingers)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = AudioRegistry.BUS_MUSIC
	add_child(_music_player)
	
	# UI Player
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UIPlayer"
	_ui_player.bus = AudioRegistry.BUS_UI
	add_child(_ui_player)
	
	# SFX Pool for polyphonic sound playback
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = AudioRegistry.BUS_SFX
		add_child(player)
		_sfx_pool.append(player)

## Plays a sound effect by event identifier from AudioRegistry.
func play_sfx(event_id: StringName, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not AudioRegistry.has_event(event_id):
		push_warning("[AudioManager] Unknown SFX event_id: %s" % event_id)
		return
	
	var def := AudioRegistry.get_definition(event_id)
	var stream := _get_or_create_stream(event_id, def)
	if stream == null:
		return
	
	var player := _get_available_sfx_player()
	player.stream = stream
	player.volume_db = def.get("default_volume_db", 0.0) + volume_offset_db
	player.pitch_scale = pitch_scale
	player.play()
	
	audio_event_played.emit(event_id, AudioRegistry.BUS_SFX)

## Plays a UI sound stinger (non-positional, UI bus).
func play_ui(event_id: StringName, volume_offset_db: float = 0.0) -> void:
	if not AudioRegistry.has_event(event_id):
		push_warning("[AudioManager] Unknown UI event_id: %s" % event_id)
		return
	
	var def := AudioRegistry.get_definition(event_id)
	var stream := _get_or_create_stream(event_id, def)
	if stream == null:
		return
	
	_ui_player.stream = stream
	_ui_player.volume_db = def.get("default_volume_db", 0.0) + volume_offset_db
	_ui_player.pitch_scale = 1.0
	_ui_player.play()
	
	audio_event_played.emit(event_id, AudioRegistry.BUS_UI)

## Cross-fades facility ambience smoothly to a new soundscape (e.g., normal facility hum vs. blackout drone).
func play_ambience(event_id: StringName, fade_time: float = 1.0) -> void:
	if _active_ambience_id == event_id:
		return
	
	if not AudioRegistry.has_event(event_id):
		push_warning("[AudioManager] Unknown ambience event_id: %s" % event_id)
		return
	
	var def := AudioRegistry.get_definition(event_id)
	var stream := _get_or_create_stream(event_id, def)
	if stream == null:
		return
	
	var target_vol: float = def.get("default_volume_db", -10.0)
	
	# Swap primary and secondary for crossfade
	var temp := _ambience_player
	_ambience_player = _secondary_ambience_player
	_secondary_ambience_player = temp
	
	_ambience_player.stream = stream
	_ambience_player.volume_db = -80.0
	_ambience_player.play()
	
	_is_crossfading = true
	_crossfade_duration = max(0.1, fade_time)
	_crossfade_elapsed = 0.0
	_crossfade_from_volume = _secondary_ambience_player.volume_db
	_crossfade_to_volume = target_vol
	_active_ambience_id = event_id
	
	ambience_changed.emit(event_id)

func _process_crossfade(delta: float) -> void:
	_crossfade_elapsed += delta
	var t: float = clampf(_crossfade_elapsed / _crossfade_duration, 0.0, 1.0)
	
	# Fade in new ambience
	_ambience_player.volume_db = lerpf(-80.0, _crossfade_to_volume, t)
	# Fade out old ambience
	_secondary_ambience_player.volume_db = lerpf(_crossfade_from_volume, -80.0, t)
	
	if t >= 1.0:
		_is_crossfading = false
		_secondary_ambience_player.stop()

## Starts the Meltdown emergency tension alarm.
func start_meltdown_audio() -> void:
	var def := AudioRegistry.get_definition(AudioRegistry.AMBIENCE_MELTDOWN_ALARM)
	var stream := _get_or_create_stream(AudioRegistry.AMBIENCE_MELTDOWN_ALARM, def)
	if stream != null:
		_music_player.stream = stream
		_music_player.volume_db = def.get("default_volume_db", -6.0)
		_music_player.pitch_scale = 1.0
		_music_player.play()

## Dynamically scales the Meltdown alarm pitch and intensity as the 5-minute timer counts down.
func update_meltdown_intensity(time_remaining_sec: float, total_duration_sec: float = 300.0) -> void:
	if not _music_player.playing:
		return
	
	var progress: float = 1.0 - clampf(time_remaining_sec / total_duration_sec, 0.0, 1.0)
	# Progress scales pitch from 1.0 to 1.35 and volume boost up to +3.0 dB
	_music_player.pitch_scale = lerpf(1.0, 1.35, progress)
	var def := AudioRegistry.get_definition(AudioRegistry.AMBIENCE_MELTDOWN_ALARM)
	var base_vol: float = def.get("default_volume_db", -6.0)
	_music_player.volume_db = base_vol + (progress * 3.0)

## Stops all music and ambience upon Game Over.
func stop_match_audio() -> void:
	_music_player.stop()
	_ambience_player.stop()
	_secondary_ambience_player.stop()
	_is_crossfading = false
	_active_ambience_id = &""

## Returns the active ambience identifier.
func get_active_ambience() -> StringName:
	return _active_ambience_id

## Adjusts bus volume in decibels.
func set_bus_volume(bus_name: StringName, volume_db: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, volume_db)

## Toggles mute on a specified audio bus.
func set_bus_mute(bus_name: StringName, is_muted: bool) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, is_muted)

# --- INTERNAL STREAM HANDLING & PROCEDURAL SYNTHESIS ---

func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	# If all players are busy, steal the oldest (first in pool)
	var stolen: AudioStreamPlayer = _sfx_pool[0]
	stolen.stop()
	return stolen

func _get_or_create_stream(event_id: StringName, def: Dictionary) -> AudioStream:
	if _stream_cache.has(event_id):
		return _stream_cache[event_id]
	
	var path: String = def.get("path", "")
	if ResourceLoader.exists(path):
		var loaded_stream: AudioStream = load(path)
		if loaded_stream != null:
			_stream_cache[event_id] = loaded_stream
			return loaded_stream
	
	# Procedural fallback synthesis
	var synth_stream := _synthesize_procedural_stream(def)
	if synth_stream != null:
		_stream_cache[event_id] = synth_stream
		return synth_stream
	
	return null

## Procedurally synthesizes an AudioStreamWAV for immediate playback without external audio files.
func _synthesize_procedural_stream(def: Dictionary) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var duration: float = def.get("duration", 0.5)
	var is_loop: bool = def.get("loop", false)
	var freq: float = def.get("synth_frequency", 440.0)
	var synth_type: String = def.get("synth_type", "sine")
	
	var total_samples := int(stream.mix_rate * duration)
	var buffer := PackedByteArray()
	buffer.resize(total_samples * 2) # 16-bit = 2 bytes per sample
	
	var phase: float = 0.0
	var phase_inc: float = (freq * TAU) / float(stream.mix_rate)
	
	for i in range(total_samples):
		var sample_val: float = 0.0
		match synth_type:
			"sine":
				sample_val = sin(phase)
			"square":
				sample_val = 1.0 if sin(phase) >= 0.0 else -1.0
			"sawtooth":
				sample_val = (fmod(phase, TAU) / PI) - 1.0
			"triangle":
				sample_val = 2.0 * abs((fmod(phase, TAU) / PI) - 1.0) - 1.0
			"noise":
				sample_val = randf_range(-1.0, 1.0)
			"pulse":
				sample_val = 1.0 if fmod(phase, TAU) < (TAU * 0.25) else -0.3
			_:
				sample_val = sin(phase)
		
		# Envelope: slight attack & exponential decay to prevent clicks
		var envelope: float = 1.0
		if not is_loop:
			var progress := float(i) / float(total_samples)
			var attack := minf(float(i) / 200.0, 1.0)
			var decay := pow(1.0 - progress, 1.5)
			envelope = attack * decay
		
		var sample_int := int(clampf(sample_val * envelope, -1.0, 1.0) * 32767.0)
		buffer.encode_s16(i * 2, sample_int)
		
		phase += phase_inc
		if phase >= TAU:
			phase -= TAU
	
	stream.data = buffer
	if is_loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = total_samples
	
	return stream
