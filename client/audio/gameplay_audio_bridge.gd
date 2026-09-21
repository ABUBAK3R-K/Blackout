class_name GameplayAudioBridge
extends Node

## GameplayAudioBridge for BLACKOUT (Member 8: Audio & QA Lead)
## Serves as the non-invasive observer between existing gameplay systems
## (ClientNetworkManager, MiniGameBase, InteractableStation, FacilityLightingController)
## and Member 8's AudioManager.
##
## STRICT TEAM BOUNDARY:
## This class only listens to public signals and events. It never alters gameplay logic.

const AudioRegistry = preload("res://assets/audio/audio_registry.gd")
const NetworkConfig = preload("res://shared/network_config.gd")

@export var audio_manager: Node = null

# Weak references / tracked connections to prevent duplicate signal bindings
var _connected_stations: Array[int] = []
var _connected_mini_games: Array[int] = []
var _network_manager_id: int = 0
var _lighting_controller_id: int = 0

func _ready() -> void:
	if audio_manager == null:
		audio_manager = get_parent()

# ==============================================================================
# 1. NETWORK MANAGER SIGNALS (ClientNetworkManager - Member 1)
# ==============================================================================

## Connects to an existing ClientNetworkManager instance to listen for authoritative match events.
func connect_network_manager(net_mgr: Node) -> void:
	if net_mgr == null or not is_instance_valid(net_mgr):
		return

	var obj_id := net_mgr.get_instance_id()
	if _network_manager_id == obj_id:
		return
	_network_manager_id = obj_id

	_safe_connect(net_mgr, "game_state_changed", _on_game_state_changed)
	_safe_connect(net_mgr, "role_assigned", _on_role_assigned)
	_safe_connect(net_mgr, "task_completed_locally", _on_task_completed_locally)
	_safe_connect(net_mgr, "blackout_unlocked_for_impostor", _on_blackout_unlocked)
	_safe_connect(net_mgr, "blackout_countdown_started", _on_blackout_countdown_started)
	_safe_connect(net_mgr, "blackout_started", _on_blackout_started)
	_safe_connect(net_mgr, "blackout_ended", _on_blackout_ended)
	_safe_connect(net_mgr, "recovery_system_updated", _on_recovery_system_updated)
	_safe_connect(net_mgr, "impostor_objective_updated", _on_impostor_objective_updated)
	_safe_connect(net_mgr, "meeting_started", _on_meeting_started)
	_safe_connect(net_mgr, "voting_started", _on_voting_started)
	_safe_connect(net_mgr, "player_voted", _on_player_voted)
	_safe_connect(net_mgr, "vote_result_received", _on_vote_result_received)
	_safe_connect(net_mgr, "meltdown_started", _on_meltdown_started)
	_safe_connect(net_mgr, "emergency_system_completed", _on_emergency_system_completed)
	_safe_connect(net_mgr, "game_over_received", _on_game_over_received)

func _on_game_state_changed(new_state: int) -> void:
	if audio_manager == null:
		return

	match new_state:
		NetworkConfig.GameState.INITIAL_TASK_PHASE, NetworkConfig.GameState.BLACKOUT_AVAILABLE, NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION:
			audio_manager.play_ambient(AudioRegistry.AMBIENCE_FACILITY_HUM, 1.5)
			audio_manager.play_music(AudioRegistry.MUSIC_NORMAL, 2.0)
		NetworkConfig.GameState.MEETING:
			audio_manager.stop_music(0.5)
		NetworkConfig.GameState.GAME_OVER:
			audio_manager.stop_match_audio()

func _on_role_assigned(_role: int) -> void:
	if audio_manager != null:
		audio_manager.play_sfx(AudioRegistry.SFX_TASK_SUCCESS, 0.0, 1.0)

func _on_task_completed_locally(_task_id: String) -> void:
	if audio_manager != null:
		audio_manager.play_sfx(AudioRegistry.SFX_TASK_SUCCESS)

func _on_blackout_unlocked() -> void:
	if audio_manager != null:
		audio_manager.play_ui(AudioRegistry.UI_CLICK, 2.0)

func _on_blackout_countdown_started(_duration: float) -> void:
	if audio_manager != null:
		audio_manager.play_sfx(AudioRegistry.SFX_BLACKOUT_COUNTDOWN)

func _on_blackout_started(_duration: float) -> void:
	if audio_manager != null:
		audio_manager.start_blackout_audio()

func _on_blackout_ended() -> void:
	if audio_manager != null:
		audio_manager.stop_blackout_audio()

func _on_recovery_system_updated(_system_id: String, is_completed: bool, _completed_count: int, _required_count: int) -> void:
	if audio_manager != null and is_completed:
		audio_manager.play_sfx(AudioRegistry.SFX_POWER_RESTORE, -3.0)

func _on_impostor_objective_updated(_objective_id: String, is_completed: bool) -> void:
	if audio_manager != null and is_completed:
		audio_manager.play_sfx(AudioRegistry.SFX_SABOTAGE_EXECUTE)

func _on_meeting_started(_caller_peer_id: int, _discussion_duration: float) -> void:
	if audio_manager != null:
		audio_manager.play_stinger(AudioRegistry.STINGER_MEETING)

func _on_voting_started(_voting_duration: float) -> void:
	if audio_manager != null:
		audio_manager.play_sfx(AudioRegistry.UI_VOTING_TICK)

func _on_player_voted(_voter_peer_id: int) -> void:
	if audio_manager != null:
		audio_manager.play_ui(AudioRegistry.UI_VOTE_CAST)

func _on_vote_result_received(result: Dictionary) -> void:
	if audio_manager == null:
		return

	var elim_id := int(result.get("eliminated_peer_id", 0))
	if elim_id > 0:
		audio_manager.play_stinger(AudioRegistry.UI_EJECTION_REVEAL)
	else:
		audio_manager.play_ui(AudioRegistry.UI_CLICK)

func _on_meltdown_started(_duration: float, _impostor_alive: bool) -> void:
	if audio_manager != null:
		audio_manager.start_meltdown_audio()

func _on_emergency_system_completed(_system_id: String, _completed_systems: Array) -> void:
	if audio_manager != null:
		audio_manager.play_sfx(AudioRegistry.SFX_TASK_SUCCESS, 2.0)

func _on_game_over_received(winner_role: int, _reason: int, _result_data: Dictionary) -> void:
	if audio_manager == null:
		return

	# Stop background loops
	audio_manager.stop_match_audio()

	# Determine victory vs defeat sting based on client's assigned role if available
	var assigned_role := NetworkConfig.PlayerRole.NONE
	var net_mgr := instance_from_id(_network_manager_id)
	if net_mgr != null and "assigned_role" in net_mgr:
		assigned_role = net_mgr.assigned_role

	if assigned_role != NetworkConfig.PlayerRole.NONE:
		if winner_role == assigned_role:
			audio_manager.play_stinger(AudioRegistry.STINGER_VICTORY)
		else:
			audio_manager.play_stinger(AudioRegistry.STINGER_DEFEAT)
	else:
		# Fallback to crew victory cue if winner is Crew
		if winner_role == NetworkConfig.PlayerRole.CREW:
			audio_manager.play_stinger(AudioRegistry.STINGER_VICTORY)
		else:
			audio_manager.play_stinger(AudioRegistry.STINGER_DEFEAT)

# ==============================================================================
# 2. INTERACTABLE STATION SIGNALS (InteractableStation - Member 4)
# ==============================================================================

## Connects to an existing InteractableStation trigger.
func connect_station(station: Node) -> void:
	if station == null or not is_instance_valid(station):
		return

	var obj_id := station.get_instance_id()
	if _connected_stations.has(obj_id):
		return
	_connected_stations.append(obj_id)

	_safe_connect(station, "player_entered_station", _on_station_entered)
	_safe_connect(station, "interaction_triggered", _on_station_interaction_triggered)

func _on_station_entered(_station: Node) -> void:
	if audio_manager != null:
		audio_manager.play_ui(AudioRegistry.UI_HOVER)

func _on_station_interaction_triggered(_station: Node) -> void:
	if audio_manager != null:
		audio_manager.play_sfx(AudioRegistry.SFX_TASK_CLICK)

# ==============================================================================
# 3. MINI-GAME BASE SIGNALS (MiniGameBase - Member 4)
# ==============================================================================

## Connects to an existing MiniGameBase instance.
func connect_mini_game(mini_game: Node) -> void:
	if mini_game == null or not is_instance_valid(mini_game):
		return

	var obj_id := mini_game.get_instance_id()
	if _connected_mini_games.has(obj_id):
		return
	_connected_mini_games.append(obj_id)

	_safe_connect(mini_game, "interaction_started", _on_mini_game_started)
	_safe_connect(mini_game, "progress_changed", _on_mini_game_progress_changed)
	_safe_connect(mini_game, "interaction_completed", _on_mini_game_completed)
	_safe_connect(mini_game, "interaction_failed", _on_mini_game_failed)
	_safe_connect(mini_game, "interaction_cancelled", _on_mini_game_cancelled)

func _on_mini_game_started() -> void:
	if audio_manager != null:
		audio_manager.play_sfx(AudioRegistry.SFX_TASK_CLICK)

func _on_mini_game_progress_changed(_new_progress: float) -> void:
	if audio_manager != null:
		audio_manager.play_sfx(AudioRegistry.SFX_TASK_PROGRESS, -6.0)

func _on_mini_game_completed() -> void:
	if audio_manager != null:
		audio_manager.play_sfx(AudioRegistry.SFX_TASK_SUCCESS)

func _on_mini_game_failed() -> void:
	if audio_manager != null:
		audio_manager.play_sfx(AudioRegistry.SFX_TASK_ERROR)

func _on_mini_game_cancelled() -> void:
	if audio_manager != null:
		audio_manager.play_ui(AudioRegistry.UI_CLICK)

# ==============================================================================
# 4. LIGHTING CONTROLLER SIGNALS (FacilityLightingController - Member 7)
# ==============================================================================

## Connects to an existing FacilityLightingController instance to synchronize ambience.
func connect_lighting_controller(lighting: Node) -> void:
	if lighting == null or not is_instance_valid(lighting):
		return

	var obj_id := lighting.get_instance_id()
	if _lighting_controller_id == obj_id:
		return
	_lighting_controller_id = obj_id

	_safe_connect(lighting, "lighting_state_changed", _on_lighting_state_changed)

func _on_lighting_state_changed(new_state: int) -> void:
	if audio_manager == null:
		return

	# State 0: NORMAL, State 1: BLACKOUT_WARNING, State 2: BLACKOUT_ACTIVE, State 3: MELTDOWN
	match new_state:
		0: # NORMAL
			audio_manager.play_ambient(AudioRegistry.AMBIENCE_FACILITY_HUM, 1.5)
		1: # BLACKOUT_WARNING
			audio_manager.play_sfx(AudioRegistry.SFX_BLACKOUT_COUNTDOWN)
		2: # BLACKOUT_ACTIVE
			audio_manager.start_blackout_audio()
		3: # MELTDOWN
			audio_manager.start_meltdown_audio()

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func _safe_connect(emitter: Object, signal_name: StringName, handler: Callable) -> void:
	if emitter.has_signal(signal_name):
		if not emitter.is_connected(signal_name, handler):
			emitter.connect(signal_name, handler)
