class_name AudioManager
extends Node

## Centralized Audio Manager for BLACKOUT (Member 8: Audio & QA Lead)
## Handles dynamic soundscapes, environmental ambience crossfading, music transitions,
## gameplay event SFX, UI audio cues, stingers, and procedural waveform fallback generation.

const AudioRegistry = preload("res://assets/audio/audio_registry.gd")

signal audio_event_played(event_id: StringName, bus: StringName)
signal ambience_changed(new_ambience_id: StringName)
signal music_changed(new_music_id: StringName)

# --- ACTIVE PLAYERS ---
var _ambience_player: AudioStreamPlayer = null
var _secondary_ambience_player: AudioStreamPlayer = null
var _active_ambience_id: StringName = &""

var _music_player: AudioStreamPlayer = null
var _current_music_id: StringName = &""

var _stinger_player: AudioStreamPlayer = null
var _ui_player: AudioStreamPlayer = null
var _sfx_pool: Array[AudioStreamPlayer] = []

# In-memory cache for loaded audio streams and procedurally synthesized streams
var _stream_cache: Dictionary = {}

# SFX Player pool size (polyphonic channel limit)
const SFX_POOL_SIZE: int = 12

# Ambience crossfade state
var _is_crossfading: bool = false
var _crossfade_duration: float = 1.0
var _crossfade_elapsed: float = 0.0
var _crossfade_from_volume: float = -80.0
var _crossfade_to_volume: float = 0.0

# Music fade state
var _is_music_fading: bool = false
var _music_fade_duration: float = 1.0
var _music_fade_elapsed: float = 0.0
var _music_fade_from_vol: float = -80.0
var _music_fade_to_vol: float = 0.0
var _pending_music_id: StringName = &""

func _ready() -> void:
	_ensure_buses_exist()
	_setup_audio_nodes()

func _process(delta: float) -> void:
	if _is_crossfading:
		_process_crossfade(delta)
	if _is_music_fading:
		_process_music_fade(delta)

## Ensures all required audio buses exist in AudioServer and route to Master.
func _ensure_buses_exist() -> void:
	var required_buses: Array[StringName] = [
		AudioRegistry.BUS_AMBIENCE,
		AudioRegistry.BUS_MUSIC,
		AudioRegistry.BUS_SFX,
		AudioRegistry.BUS_UI
	]
	for bus in required_buses:
		if AudioServer.get_bus_index(bus) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, AudioRegistry.BUS_MASTER)

## Sets up dedicated AudioStreamPlayers for Ambience, Music, UI, Stingers, and the SFX pool.
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

	# Music Player
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = AudioRegistry.BUS_MUSIC
	add_child(_music_player)

	# Dedicated Stinger Player
	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.name = "StingerPlayer"
	_stinger_player.bus = AudioRegistry.BUS_SFX
	add_child(_stinger_player)

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

# ==============================================================================
# MUSIC API
# ==============================================================================

## Plays a music track by event identifier. Prevents restart if already playing the same track.
func play_music(event_id: StringName = AudioRegistry.MUSIC_NORMAL, fade_duration: float = 1.0) -> void:
	if _current_music_id == event_id and _music_player.playing:
		return

	if not AudioRegistry.has_event(event_id):
		push_warning("[AudioManager] Unknown music event_id: %s" % event_id)
		return

	var def := AudioRegistry.get_definition(event_id)
	var stream := _get_or_create_stream(event_id, def)
	if stream == null:
		return

	var target_vol: float = def.get("default_volume_db", -10.0)

	if _music_player.playing and fade_duration > 0.05:
		_pending_music_id = event_id
		_is_music_fading = true
		_music_fade_duration = max(0.1, fade_duration)
		_music_fade_elapsed = 0.0
		_music_fade_from_vol = _music_player.volume_db
		_music_fade_to_vol = target_vol
	else:
		_music_player.stream = stream
		_music_player.volume_db = target_vol
		_music_player.pitch_scale = 1.0
		_music_player.play()
		_current_music_id = event_id
		music_changed.emit(event_id)
		audio_event_played.emit(event_id, AudioRegistry.BUS_MUSIC)

## Stops the active music player with an optional fade out.
func stop_music(fade_duration: float = 0.5) -> void:
	if not _music_player.playing:
		_current_music_id = &""
		return

	if fade_duration > 0.05:
		_pending_music_id = &""
		_is_music_fading = true
		_music_fade_duration = max(0.1, fade_duration)
		_music_fade_elapsed = 0.0
		_music_fade_from_vol = _music_player.volume_db
		_music_fade_to_vol = -80.0
	else:
		_music_player.stop()
		_current_music_id = &""

func _process_music_fade(delta: float) -> void:
	_music_fade_elapsed += delta
	var t: float = clampf(_music_fade_elapsed / _music_fade_duration, 0.0, 1.0)
	_music_player.volume_db = lerpf(_music_fade_from_vol, _music_fade_to_vol, t)

	if t >= 1.0:
		_is_music_fading = false
		if _pending_music_id == &"":
			_music_player.stop()
			_current_music_id = &""
		else:
			var def := AudioRegistry.get_definition(_pending_music_id)
			var stream := _get_or_create_stream(_pending_music_id, def)
			if stream != null:
				_music_player.stream = stream
				_music_player.volume_db = def.get("default_volume_db", -10.0)
				_music_player.pitch_scale = 1.0
				_music_player.play()
				_current_music_id = _pending_music_id
				music_changed.emit(_current_music_id)
				audio_event_played.emit(_current_music_id, AudioRegistry.BUS_MUSIC)
			_pending_music_id = &""

# ==============================================================================
# AMBIENCE API
# ==============================================================================

## Cross-fades facility ambience smoothly to a new soundscape.
func play_ambient(event_id: StringName = AudioRegistry.AMBIENCE_FACILITY_HUM, fade_time: float = 1.0) -> void:
	if _active_ambience_id == event_id and (_ambience_player.playing or _secondary_ambience_player.playing):
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
	audio_event_played.emit(event_id, AudioRegistry.BUS_AMBIENCE)

## Alias for play_ambient() for backwards compatibility.
func play_ambience(event_id: StringName, fade_time: float = 1.0) -> void:
	play_ambient(event_id, fade_time)

## Stops facility ambience.
func stop_ambient(fade_time: float = 0.5) -> void:
	if not _ambience_player.playing and not _secondary_ambience_player.playing:
		_active_ambience_id = &""
		return

	if fade_time <= 0.05:
		_ambience_player.stop()
		_secondary_ambience_player.stop()
		_is_crossfading = false
		_active_ambience_id = &""
	else:
		_is_crossfading = true
		_crossfade_duration = max(0.1, fade_time)
		_crossfade_elapsed = 0.0
		_crossfade_from_volume = _ambience_player.volume_db
		_crossfade_to_volume = -80.0
		_active_ambience_id = &""

## Alias for stop_ambient() for backwards compatibility.
func stop_ambience(fade_time: float = 0.5) -> void:
	stop_ambient(fade_time)

func _process_crossfade(delta: float) -> void:
	_crossfade_elapsed += delta
	var t: float = clampf(_crossfade_elapsed / _crossfade_duration, 0.0, 1.0)

	_ambience_player.volume_db = lerpf(_crossfade_from_volume, _crossfade_to_volume, t)
	_secondary_ambience_player.volume_db = lerpf(_crossfade_from_volume, -80.0, t)

	if t >= 1.0:
		_is_crossfading = false
		_secondary_ambience_player.stop()
		if _active_ambience_id == &"":
			_ambience_player.stop()

# ==============================================================================
# SFX & STINGER API
# ==============================================================================

## Plays a sound effect by event identifier from AudioRegistry via the SFX pool.
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

## Plays a single-instance stinger cue (e.g. meeting called, victory, defeat, blackout shock).
func play_stinger(event_id: StringName, volume_offset_db: float = 0.0) -> void:
	if not AudioRegistry.has_event(event_id):
		push_warning("[AudioManager] Unknown Stinger event_id: %s" % event_id)
		return

	var def := AudioRegistry.get_definition(event_id)
	var stream := _get_or_create_stream(event_id, def)
	if stream == null:
		return

	_stinger_player.stream = stream
	_stinger_player.volume_db = def.get("default_volume_db", 0.0) + volume_offset_db
	_stinger_player.pitch_scale = 1.0
	_stinger_player.play()

	audio_event_played.emit(event_id, AudioRegistry.BUS_SFX)

## Plays a UI sound (non-positional, UI bus).
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

# ==============================================================================
# CONTEXTUAL GAMEPLAY AUDIO SHORTCUTS
# ==============================================================================

## Transitions audio into the Blackout state: plays power cut SFX, starts blackout drone and tension music.
func start_blackout_audio() -> void:
	play_sfx(AudioRegistry.SFX_POWER_CUT)
	play_stinger(AudioRegistry.STINGER_BLACKOUT_START)
	play_ambient(AudioRegistry.AMBIENCE_BLACKOUT_DRONE, 1.0)
	play_music(AudioRegistry.MUSIC_BLACKOUT, 1.5)

## Restores normal facility audio after a Blackout finishes or recovery completes.
func stop_blackout_audio() -> void:
	play_sfx(AudioRegistry.SFX_POWER_RESTORE)
	play_ambient(AudioRegistry.AMBIENCE_FACILITY_HUM, 1.5)
	play_music(AudioRegistry.MUSIC_NORMAL, 2.0)

## Initiates high-stakes Meltdown audio cues.
func start_meltdown_audio() -> void:
	play_ambient(AudioRegistry.AMBIENCE_MELTDOWN_ALARM, 0.5)
	play_music(AudioRegistry.MUSIC_MELTDOWN, 0.5)

## Stops Meltdown audio and returns to normal state.
func stop_meltdown_audio() -> void:
	stop_music(0.5)
	play_ambient(AudioRegistry.AMBIENCE_FACILITY_HUM, 1.0)

## Dynamically scales the Meltdown alarm pitch and intensity as the 5-minute timer counts down.
func update_meltdown_intensity(time_remaining_sec: float, total_duration_sec: float = 300.0) -> void:
	if not _music_player.playing:
		return

	var progress: float = 1.0 - clampf(time_remaining_sec / total_duration_sec, 0.0, 1.0)
	# Progress scales pitch from 1.0 to 1.35 and volume boost up to +3.0 dB
	_music_player.pitch_scale = lerpf(1.0, 1.35, progress)
	var def := AudioRegistry.get_definition(AudioRegistry.MUSIC_MELTDOWN)
	var base_vol: float = def.get("default_volume_db", -6.0)
	_music_player.volume_db = base_vol + (progress * 3.0)

## Stops all ongoing match audio (music and ambience) on match termination or game over.
func stop_match_audio() -> void:
	_music_player.stop()
	_ambience_player.stop()
	_secondary_ambience_player.stop()
	_stinger_player.stop()
	_is_crossfading = false
	_is_music_fading = false
	_active_ambience_id = &""
	_current_music_id = &""

# ==============================================================================
# GAMEPLAY EVENT BRIDGE CONNECTORS
# ==============================================================================

var _gameplay_bridge: Node = null

## Returns or instantiates the GameplayAudioBridge child node.
func get_or_create_gameplay_bridge() -> Node:
	if _gameplay_bridge == null:
		var BridgeScript = load("res://client/audio/gameplay_audio_bridge.gd")
		if BridgeScript != null:
			_gameplay_bridge = BridgeScript.new()
			_gameplay_bridge.name = "GameplayAudioBridge"
			_gameplay_bridge.audio_manager = self
			add_child(_gameplay_bridge)
	return _gameplay_bridge

## Connects an existing ClientNetworkManager to the audio bridge.
func connect_network_manager(net_mgr: Node) -> void:
	var bridge = get_or_create_gameplay_bridge()
	if bridge != null and bridge.has_method("connect_network_manager"):
		bridge.connect_network_manager(net_mgr)

## Connects an existing InteractableStation trigger to the audio bridge.
func connect_station(station: Node) -> void:
	var bridge = get_or_create_gameplay_bridge()
	if bridge != null and bridge.has_method("connect_station"):
		bridge.connect_station(station)

## Connects an existing MiniGameBase instance to the audio bridge.
func connect_mini_game(mini_game: Node) -> void:
	var bridge = get_or_create_gameplay_bridge()
	if bridge != null and bridge.has_method("connect_mini_game"):
		bridge.connect_mini_game(mini_game)

## Connects an existing FacilityLightingController to the audio bridge.
func connect_lighting_controller(lighting: Node) -> void:
	var bridge = get_or_create_gameplay_bridge()
	if bridge != null and bridge.has_method("connect_lighting_controller"):
		bridge.connect_lighting_controller(lighting)


# ==============================================================================
# VOLUME & BUS CONTROLS
# ==============================================================================

## Sets master volume as a linear percentage (0.0 to 1.0).
func set_master_volume(volume_linear: float) -> void:
	_set_linear_bus_volume(AudioRegistry.BUS_MASTER, volume_linear)

## Sets music volume as a linear percentage (0.0 to 1.0).
func set_music_volume(volume_linear: float) -> void:
	_set_linear_bus_volume(AudioRegistry.BUS_MUSIC, volume_linear)

## Sets SFX volume as a linear percentage (0.0 to 1.0).
func set_sfx_volume(volume_linear: float) -> void:
	_set_linear_bus_volume(AudioRegistry.BUS_SFX, volume_linear)

## Sets ambience volume as a linear percentage (0.0 to 1.0).
func set_ambient_volume(volume_linear: float) -> void:
	_set_linear_bus_volume(AudioRegistry.BUS_AMBIENCE, volume_linear)

## Sets UI volume as a linear percentage (0.0 to 1.0).
func set_ui_volume(volume_linear: float) -> void:
	_set_linear_bus_volume(AudioRegistry.BUS_UI, volume_linear)

func _set_linear_bus_volume(bus_name: StringName, volume_linear: float) -> void:
	var clamped := clampf(volume_linear, 0.0, 1.0)
	var vol_db: float = -80.0
	if clamped > 0.0001:
		vol_db = linear_to_db(clamped)
	set_bus_volume(bus_name, vol_db)

## Adjusts bus volume directly in decibels.
func set_bus_volume(bus_name: StringName, volume_db: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, volume_db)

## Toggles mute on a specified audio bus.
func set_bus_mute(bus_name: StringName, is_muted: bool) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, is_muted)

# ==============================================================================
# STATUS & QUERY HELPERS
# ==============================================================================

func get_active_ambience() -> StringName:
	return _active_ambience_id

func get_active_music() -> StringName:
	return _current_music_id

func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing

func is_ambient_playing() -> bool:
	return (_ambience_player != null and _ambience_player.playing) or (_secondary_ambience_player != null and _secondary_ambience_player.playing)

# ==============================================================================
# INTERNAL STREAM HANDLING & PROCEDURAL SYNTHESIS
# ==============================================================================

func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	# If all players in pool are busy, steal the oldest voice (first in pool)
	var stolen: AudioStreamPlayer = _sfx_pool[0]
	stolen.stop()
	return stolen

func _get_or_create_stream(event_id: StringName, def: Dictionary) -> AudioStream:
	if _stream_cache.has(event_id):
		return _stream_cache[event_id]

	var path: String = def.get("path", "")
	var is_loop: bool = def.get("loop", false)

	# 1. First try Godot's standard ResourceLoader
	if ResourceLoader.exists(path):
		var loaded_stream: AudioStream = load(path)
		if loaded_stream != null:
			_stream_cache[event_id] = loaded_stream
			return loaded_stream

	# 2. If load() did not resolve (e.g. headless unimported raw WAV), load raw WAV directly
	if FileAccess.file_exists(path):
		var raw_wav := _load_wav_from_file(path, is_loop)
		if raw_wav != null:
			_stream_cache[event_id] = raw_wav
			return raw_wav

	# 3. Procedural fallback synthesis when audio files are absent on disk
	var synth_stream := _synthesize_procedural_stream(def)
	if synth_stream != null:
		_stream_cache[event_id] = synth_stream
		return synth_stream

	return null

## Loads a standard 16-bit or 8-bit PCM WAV file directly from disk into an AudioStreamWAV.
func _load_wav_from_file(path: String, is_loop: bool = false) -> AudioStreamWAV:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var file_len: int = file.get_length()
	if file_len < 44:
		file.close()
		return null

	var bytes: PackedByteArray = file.get_buffer(file_len)
	file.close()

	if bytes.size() < 44:
		return null

	# Verify RIFF / WAVE headers
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	if bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null

	var offset: int = 12
	var channels: int = 1
	var sample_rate: int = 44100
	var bits_per_sample: int = 16
	var data_bytes := PackedByteArray()

	while offset + 8 <= bytes.size():
		var chunk_id := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var chunk_size := bytes.decode_u32(offset + 4)
		offset += 8
		if chunk_id == "fmt ":
			if chunk_size >= 16 and offset + 16 <= bytes.size():
				channels = bytes.decode_u16(offset + 2)
				sample_rate = bytes.decode_u32(offset + 4)
				bits_per_sample = bytes.decode_u16(offset + 14)
		elif chunk_id == "data":
			var read_size: int = mini(chunk_size, bytes.size() - offset)
			data_bytes = bytes.slice(offset, offset + read_size)
			break
		offset += chunk_size

	if data_bytes.is_empty():
		return null

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.stereo = (channels == 2)
	stream.mix_rate = sample_rate
	stream.data = data_bytes

	if is_loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		var bytes_per_frame: int = channels * (bits_per_sample / 8)
		if bytes_per_frame > 0:
			stream.loop_end = data_bytes.size() / bytes_per_frame

	return stream

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

		# Envelope: gentle attack & exponential decay to prevent clicks on non-looping audio
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
