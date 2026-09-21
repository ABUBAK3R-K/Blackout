class_name ClientNetworkManager
extends Node

## Client-side network manager responsible for initiating connection to the server,
## handling connection lifecycle events, requesting ready state changes,
## storing the client's own private role and assigned tasks, and receiving authoritative game state and Blackout updates.

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const SabotageManager = preload("res://shared/sabotage_manager.gd")
const RoundManager = preload("res://shared/round_manager.gd")

signal connection_succeeded()


signal connection_failed(reason: String)
signal disconnected_from_server(reason: String)
signal player_assigned(peer_id: int, slot: int, total_players: int)
signal player_count_updated(count: int, player_ids: Array)
signal other_player_connected(peer_id: int, slot: int)
signal other_player_disconnected(peer_id: int)
signal ready_state_updated(is_ready: bool)
signal lobby_synced(state: NetworkConfig.GameState, player_count: int, ready_count: int, players: Array)
signal game_state_changed(new_state: NetworkConfig.GameState)
signal role_assigned(role: NetworkConfig.PlayerRole)
signal task_list_received(tasks: Array)
signal task_completed_locally(task_id: String)
signal blackout_unlocked_for_impostor()
signal blackout_countdown_started(duration: float)
signal blackout_countdown_cancelled(reason: String)
signal blackout_started(duration: float)
signal blackout_ended()
signal recovery_systems_initialized(required_count: int, systems: Array)
signal recovery_system_updated(system_id: String, is_completed: bool, completed_count: int, required_count: int)
signal impostor_objective_list_received(objectives: Array)
signal impostor_objective_updated(objective_id: String, is_completed: bool)
signal investigation_started()
signal investigation_evidence_received(evidence_list: Array)
signal meeting_started(caller_peer_id: int, discussion_duration: float)
signal voting_started(voting_duration: float)
signal player_voted(voter_peer_id: int)
signal vote_result_received(result: Dictionary)
signal meltdown_started(duration: float, impostor_alive: bool)
signal emergency_system_completed(system_id: String, completed_systems: Array)
signal game_over_received(winner_role: NetworkConfig.PlayerRole, reason: int, result_data: Dictionary)
signal remote_player_position_updated(peer_id: int, pos: Vector2, vel: Vector2, facing: Vector2)
signal sabotage_state_synced(sabotage_type: int, state: int, duration: float)
signal sabotage_requested()
signal round_state_synced(round_state: int)
signal return_to_lobby_requested()

var peer: ENetMultiplayerPeer = null


var connection_status: NetworkConfig.ConnectionStatus = NetworkConfig.ConnectionStatus.DISCONNECTED

var assigned_slot: int = 0
var assigned_peer_id: int = 0
var assigned_role: NetworkConfig.PlayerRole = NetworkConfig.PlayerRole.NONE
var assigned_tasks: Array = []

var is_blackout_unlocked: bool = false
var is_blackout_active: bool = false
var blackout_countdown_remaining: float = 0.0
var blackout_remaining_duration: float = 0.0

var current_sabotage_type: int = 0
var current_sabotage_state: int = 0
var is_sabotage_active: bool = false
var current_round_state: int = 0

var active_recovery_systems: Array = []


var required_recovery_count: int = 0
var completed_recovery_count: int = 0
var assigned_blackout_objectives: Array = []

var investigation_evidence: Array = []
var is_investigation_active: bool = false

var is_meeting_active: bool = false
var meeting_caller_id: int = 0
var current_meeting_phase: MeetingConfig.MeetingPhase = MeetingConfig.MeetingPhase.NONE
var discussion_remaining_duration: float = 0.0
var voting_remaining_duration: float = 0.0
var has_voted_this_round: bool = false
var last_vote_result: Dictionary = {}
var is_eliminated: bool = false

var is_meltdown_active: bool = false
var meltdown_remaining_duration: float = 0.0
var is_impostor_alive_at_meltdown: bool = true
var completed_emergency_systems: Array = []

var is_game_over: bool = false
var game_winner: NetworkConfig.PlayerRole = NetworkConfig.PlayerRole.NONE
var game_over_reason: int = 0
var game_over_result: Dictionary = {}

var is_ready: bool = false
var server_player_count: int = 0
var ready_player_count: int = 0
var current_game_state: NetworkConfig.GameState = NetworkConfig.GameState.LOBBY
var connected_peer_ids: Array = []
var lobby_players_data: Array = []
var last_disconnect_reason: String = ""

func _get_mp() -> MultiplayerAPI:
	if is_inside_tree():
		return multiplayer
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).get_multiplayer()
	return null

func connect_to_server(host: String = NetworkConfig.DEFAULT_HOST, port: int = NetworkConfig.DEFAULT_PORT) -> Error:
	if connection_status == NetworkConfig.ConnectionStatus.CONNECTING or connection_status == NetworkConfig.ConnectionStatus.CONNECTED:
		push_warning("[CLIENT] Client is already connecting or connected.")
		return OK

	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(host, port)
	if error != OK:
		push_error("[CLIENT] Failed to create ENet client to %s:%d. Error code: %d" % [host, port, error])
		connection_status = NetworkConfig.ConnectionStatus.FAILED
		connection_failed.emit("Failed to create client socket (Error %d)" % error)
		peer = null
		return error

	var mp = _get_mp()
	if mp != null:
		mp.multiplayer_peer = peer
		if not mp.connected_to_server.is_connected(_on_connected_to_server):
			mp.connected_to_server.connect(_on_connected_to_server)
		if not mp.connection_failed.is_connected(_on_connection_failed):
			mp.connection_failed.connect(_on_connection_failed)
		if not mp.server_disconnected.is_connected(_on_server_disconnected):
			mp.server_disconnected.connect(_on_server_disconnected)

	connection_status = NetworkConfig.ConnectionStatus.CONNECTING
	current_game_state = NetworkConfig.GameState.LOBBY
	assigned_role = NetworkConfig.PlayerRole.NONE
	assigned_tasks.clear()
	is_blackout_unlocked = false
	is_blackout_active = false
	blackout_countdown_remaining = 0.0
	blackout_remaining_duration = 0.0
	current_sabotage_type = 0
	current_sabotage_state = 0
	is_sabotage_active = false
	current_round_state = 0
	active_recovery_systems.clear()


	required_recovery_count = 0
	completed_recovery_count = 0
	assigned_blackout_objectives.clear()
	investigation_evidence.clear()
	is_investigation_active = false
	is_meeting_active = false
	meeting_caller_id = 0
	current_meeting_phase = MeetingConfig.MeetingPhase.NONE
	discussion_remaining_duration = 0.0
	voting_remaining_duration = 0.0
	has_voted_this_round = false
	last_vote_result.clear()
	is_eliminated = false
	is_meltdown_active = false
	meltdown_remaining_duration = 0.0
	is_impostor_alive_at_meltdown = true
	completed_emergency_systems.clear()
	is_game_over = false
	game_winner = NetworkConfig.PlayerRole.NONE
	game_over_reason = 0
	game_over_result.clear()
	is_ready = false
	ready_player_count = 0
	last_disconnect_reason = ""

	print("[CLIENT] Connecting to server at %s:%d..." % [host, port])
	return OK

func disconnect_from_server() -> void:
	if connection_status == NetworkConfig.ConnectionStatus.DISCONNECTED:
		return

	print("[CLIENT] Disconnecting from server...")
	_cleanup_connection()
	connection_status = NetworkConfig.ConnectionStatus.DISCONNECTED
	disconnected_from_server.emit("User disconnected")

func is_connected_to_server() -> bool:
	return connection_status == NetworkConfig.ConnectionStatus.CONNECTED

func set_ready(ready_status: bool) -> void:
	if not is_connected_to_server():
		push_warning("[CLIENT] Cannot change ready state: not connected to server.")
		return

	if current_game_state != NetworkConfig.GameState.LOBBY:
		push_warning("[CLIENT] Cannot change ready state: match is not in LOBBY.")
		return

	print("[CLIENT] Requesting server to set ready status to: %s." % ["READY" if ready_status else "NOT READY"])
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("request_set_ready"):
		net_mgr.request_set_ready(ready_status)

func request_complete_task(task_id: String) -> void:
	if not is_connected_to_server():
		push_warning("[CLIENT] Cannot complete task: not connected to server.")
		return

	if current_game_state != NetworkConfig.GameState.INITIAL_TASK_PHASE:
		push_warning("[CLIENT] Cannot complete task: match is not in INITIAL_TASK_PHASE.")
		return

	if is_eliminated:
		push_warning("[CLIENT] Cannot complete task: player is eliminated.")
		return

	print("[CLIENT] Requesting task completion for: %s" % task_id)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("request_complete_task"):
		net_mgr.request_complete_task(task_id)

func request_activate_blackout() -> void:
	if not is_connected_to_server():
		push_warning("[CLIENT] Cannot activate Blackout: not connected to server.")
		return

	if assigned_role != NetworkConfig.PlayerRole.IMPOSTOR:
		push_warning("[CLIENT] Cannot activate Blackout: player is not the Impostor.")
		return

	print("[CLIENT] Impostor requesting Blackout activation...")
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("request_activate_blackout"):
		net_mgr.request_activate_blackout()

func request_sabotage(sabotage_type: int = 1) -> void:
	if not is_connected_to_server():
		push_warning("[CLIENT] Cannot request sabotage: not connected to server.")
		return

	if assigned_role != NetworkConfig.PlayerRole.IMPOSTOR:
		push_warning("[CLIENT] Cannot request sabotage: player is not the Impostor.")
		return

	print("[CLIENT] Local Impostor requesting sabotage (Type %d)..." % sabotage_type)
	sabotage_requested.emit()
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("send_sabotage_request"):
		net_mgr.send_sabotage_request(sabotage_type)

func request_recover_system(system_id: String) -> void:
	if not is_connected_to_server():
		push_warning("[CLIENT] Cannot recover system: not connected to server.")
		return

	if current_game_state != NetworkConfig.GameState.BLACKOUT_ACTIVE:
		push_warning("[CLIENT] Cannot recover system: match is not in BLACKOUT_ACTIVE.")
		return

	if assigned_role != NetworkConfig.PlayerRole.CREW:
		push_warning("[CLIENT] Cannot recover system: player is not Crew.")
		return

	print("[CLIENT] Crew requesting system recovery for: %s" % system_id)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("request_recover_system"):
		net_mgr.request_recover_system(system_id)

func request_complete_impostor_objective(objective_id: String) -> void:
	if not is_connected_to_server():
		push_warning("[CLIENT] Cannot complete objective: not connected to server.")
		return

	if current_game_state != NetworkConfig.GameState.BLACKOUT_ACTIVE:
		push_warning("[CLIENT] Cannot complete objective: match is not in BLACKOUT_ACTIVE.")
		return

	if assigned_role != NetworkConfig.PlayerRole.IMPOSTOR:
		push_warning("[CLIENT] Cannot complete objective: player is not the Impostor.")
		return

	print("[CLIENT] Impostor requesting objective completion for: %s" % objective_id)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("request_complete_impostor_objective"):
		net_mgr.request_complete_impostor_objective(objective_id)

func request_call_meeting() -> void:
	if not is_connected_to_server():
		push_warning("[CLIENT] Cannot call meeting: not connected to server.")
		return

	if current_game_state != NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION:
		push_warning("[CLIENT] Cannot call meeting: match is not in POST_BLACKOUT_INVESTIGATION.")
		return

	if is_eliminated:
		push_warning("[CLIENT] Cannot call meeting: player is eliminated.")
		return

	print("[CLIENT] Requesting server to call a meeting...")
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("request_call_meeting"):
		net_mgr.request_call_meeting()

func request_cast_vote(target_peer_id: int) -> void:
	if not is_connected_to_server():
		push_warning("[CLIENT] Cannot cast vote: not connected to server.")
		return

	if current_game_state != NetworkConfig.GameState.VOTING:
		push_warning("[CLIENT] Cannot cast vote: match is not in VOTING phase.")
		return

	if is_eliminated:
		push_warning("[CLIENT] Cannot cast vote: player is eliminated.")
		return

	if has_voted_this_round:
		push_warning("[CLIENT] Cannot cast vote: already voted this round.")
		return

	var target_name = "SKIP" if target_peer_id == MeetingConfig.VOTE_SKIP else "Player %d" % target_peer_id
	print("[CLIENT] Submitting vote for %s..." % target_name)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("request_cast_vote"):
		net_mgr.request_cast_vote(target_peer_id)

func request_complete_emergency_system(system_id: String) -> void:
	if not is_connected_to_server():
		push_warning("[CLIENT] Cannot complete emergency system: not connected to server.")
		return

	if current_game_state != NetworkConfig.GameState.MELTDOWN:
		push_warning("[CLIENT] Cannot complete emergency system: match is not in MELTDOWN.")
		return

	if is_eliminated:
		push_warning("[CLIENT] Cannot complete emergency system: player is eliminated.")
		return

	if assigned_role != NetworkConfig.PlayerRole.CREW:
		push_warning("[CLIENT] Cannot complete emergency system: only Crew members can restore systems.")
		return

	if is_game_over:
		push_warning("[CLIENT] Cannot complete emergency system: match is GAME_OVER.")
		return

	print("[CLIENT] Crew requesting completion for emergency system: %s" % system_id)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("request_complete_emergency_system"):
		net_mgr.request_complete_emergency_system(system_id)

func request_return_to_lobby() -> void:
	if not is_connected_to_server():
		push_warning("[CLIENT] Cannot return to lobby: not connected to server.")
		return

	print("[CLIENT] Requesting server to return match to LOBBY / Rematch...")
	return_to_lobby_requested.emit()
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("send_return_to_lobby_request"):
		net_mgr.send_return_to_lobby_request()
	elif net_mgr != null and net_mgr.has_method("request_return_to_lobby"):
		net_mgr.request_return_to_lobby()

func reset_match_state() -> void:
	assigned_role = NetworkConfig.PlayerRole.NONE
	assigned_tasks.clear()
	is_blackout_unlocked = false
	is_blackout_active = false
	blackout_countdown_remaining = 0.0
	blackout_remaining_duration = 0.0
	current_sabotage_type = 0
	current_sabotage_state = 0
	is_sabotage_active = false
	current_round_state = RoundManager.RoundState.LOBBY
	active_recovery_systems.clear()
	required_recovery_count = 0
	completed_recovery_count = 0
	assigned_blackout_objectives.clear()
	investigation_evidence.clear()
	is_investigation_active = false
	is_meeting_active = false
	meeting_caller_id = 0
	current_meeting_phase = MeetingConfig.MeetingPhase.NONE
	discussion_remaining_duration = 0.0
	voting_remaining_duration = 0.0
	has_voted_this_round = false
	last_vote_result.clear()
	is_eliminated = false
	is_meltdown_active = false
	meltdown_remaining_duration = 0.0
	is_impostor_alive_at_meltdown = true
	completed_emergency_systems.clear()
	is_game_over = false
	game_winner = NetworkConfig.PlayerRole.NONE
	game_over_reason = 0
	game_over_result.clear()
	is_ready = false

func _cleanup_connection() -> void:
	var mp = _get_mp()
	if mp != null:
		if mp.connected_to_server.is_connected(_on_connected_to_server):
			mp.connected_to_server.disconnect(_on_connected_to_server)
		if mp.connection_failed.is_connected(_on_connection_failed):
			mp.connection_failed.disconnect(_on_connection_failed)
		if mp.server_disconnected.is_connected(_on_server_disconnected):
			mp.server_disconnected.disconnect(_on_server_disconnected)
		if mp.multiplayer_peer == peer:
			mp.multiplayer_peer = null

	if peer != null:
		peer.close()
		peer = null

	assigned_slot = 0
	assigned_peer_id = 0
	assigned_role = NetworkConfig.PlayerRole.NONE
	assigned_tasks.clear()
	is_blackout_unlocked = false
	is_blackout_active = false
	blackout_countdown_remaining = 0.0
	blackout_remaining_duration = 0.0
	current_sabotage_type = 0
	current_sabotage_state = 0
	is_sabotage_active = false
	current_round_state = 0
	active_recovery_systems.clear()

	required_recovery_count = 0
	completed_recovery_count = 0
	assigned_blackout_objectives.clear()
	investigation_evidence.clear()
	is_investigation_active = false
	is_meeting_active = false
	meeting_caller_id = 0
	current_meeting_phase = MeetingConfig.MeetingPhase.NONE
	discussion_remaining_duration = 0.0
	voting_remaining_duration = 0.0
	has_voted_this_round = false
	last_vote_result.clear()
	is_eliminated = false
	is_meltdown_active = false
	meltdown_remaining_duration = 0.0
	is_impostor_alive_at_meltdown = true
	completed_emergency_systems.clear()
	is_game_over = false
	game_winner = NetworkConfig.PlayerRole.NONE
	game_over_reason = 0
	game_over_result.clear()
	is_ready = false
	server_player_count = 0
	ready_player_count = 0
	current_game_state = NetworkConfig.GameState.LOBBY
	connected_peer_ids.clear()
	lobby_players_data.clear()

func _on_connected_to_server() -> void:
	print("[CLIENT] Connected to server socket. Awaiting authoritative session assignment...")
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	print("[CLIENT] Connection handshake failed.")
	_cleanup_connection()
	connection_status = NetworkConfig.ConnectionStatus.FAILED
	connection_failed.emit("Connection handshake failed.")

func _on_server_disconnected() -> void:
	var reason: String = last_disconnect_reason if not last_disconnect_reason.is_empty() else "Server disconnected."
	print("[CLIENT] Disconnected from server: %s" % reason)
	_cleanup_connection()
	connection_status = NetworkConfig.ConnectionStatus.DISCONNECTED
	disconnected_from_server.emit(reason)

# --- Internal event processors called by NetworkManager RPC receivers ---

func handle_assignment(p_assigned_id: int, p_slot: int, p_total_players: int) -> void:
	assigned_peer_id = p_assigned_id
	assigned_slot = p_slot
	server_player_count = p_total_players
	connection_status = NetworkConfig.ConnectionStatus.CONNECTED

	print("[CLIENT] Authoritative assignment received: Slot %d | Peer ID: %d | Total Server Players: %d/%d" % [
		p_slot, p_assigned_id, p_total_players, NetworkConfig.MAX_PLAYERS
	])
	player_assigned.emit(p_assigned_id, p_slot, p_total_players)

func handle_rejection(reason: String) -> void:
	print("[CLIENT] Server rejected connection: %s" % reason)
	last_disconnect_reason = reason
	connection_status = NetworkConfig.ConnectionStatus.REJECTED
	connection_failed.emit(reason)

func handle_private_role_assignment(p_role: int) -> void:
	assigned_role = p_role as NetworkConfig.PlayerRole
	print("[CLIENT] Private role received from server: %s" % NetworkConfig.get_role_name(assigned_role))
	role_assigned.emit(assigned_role)

func handle_private_task_list(tasks_data: Array) -> void:
	assigned_tasks = tasks_data
	print("[CLIENT] Private task list received: %d tasks assigned." % tasks_data.size())
	task_list_received.emit(tasks_data)

func handle_task_update(task_id: String, is_completed: bool) -> void:
	for t in assigned_tasks:
		if str(t.get("task_id", "")) == task_id:
			t["is_completed"] = is_completed
	print("[CLIENT] Task %s status updated: %s." % [task_id, "COMPLETED" if is_completed else "INCOMPLETE"])
	task_completed_locally.emit(task_id)

func handle_blackout_unlocked() -> void:
	is_blackout_unlocked = true
	print("[CLIENT] Impostor notification: BLACKOUT ability is now UNLOCKED!")
	blackout_unlocked_for_impostor.emit()

func handle_blackout_countdown_started(duration: float) -> void:
	blackout_countdown_remaining = duration
	print("[CLIENT] Blackout activation countdown started: %.1f seconds." % duration)
	blackout_countdown_started.emit(duration)

func handle_blackout_countdown_cancelled(reason: String) -> void:
	blackout_countdown_remaining = 0.0
	print("[CLIENT] Blackout activation countdown cancelled: %s" % reason)
	blackout_countdown_cancelled.emit(reason)

func handle_blackout_started(duration: float) -> void:
	is_blackout_active = true
	blackout_countdown_remaining = 0.0
	blackout_remaining_duration = duration
	print("[CLIENT] BLACKOUT STARTED! Duration: %.1f seconds." % duration)
	blackout_started.emit(duration)

func handle_blackout_ended() -> void:
	is_blackout_active = false
	blackout_remaining_duration = 0.0
	print("[CLIENT] BLACKOUT ENDED. Entering POST_BLACKOUT_INVESTIGATION.")
	blackout_ended.emit()

func handle_recovery_initialization(required_count: int, systems_data: Array) -> void:
	required_recovery_count = required_count
	active_recovery_systems = systems_data
	completed_recovery_count = 0
	print("[CLIENT] Recovery systems initialized: %d subsystems available (Threshold: %d)." % [
		systems_data.size(), required_count
	])
	recovery_systems_initialized.emit(required_count, systems_data)

func handle_recovery_update(system_id: String, is_completed: bool, p_completed_count: int, p_required_count: int) -> void:
	completed_recovery_count = p_completed_count
	required_recovery_count = p_required_count
	for s in active_recovery_systems:
		if str(s.get("system_id", "")) == system_id:
			s["is_completed"] = is_completed
	print("[CLIENT] Recovery system '%s' update: COMPLETED (%d/%d)." % [system_id, p_completed_count, p_required_count])
	recovery_system_updated.emit(system_id, is_completed, p_completed_count, p_required_count)

func handle_private_objective_list(objectives_data: Array) -> void:
	assigned_blackout_objectives = objectives_data
	print("[CLIENT] Impostor secret objectives received: %d objectives assigned." % objectives_data.size())
	impostor_objective_list_received.emit(objectives_data)

func handle_private_objective_update(objective_id: String, is_completed: bool) -> void:
	for obj in assigned_blackout_objectives:
		if str(obj.get("objective_id", "")) == objective_id:
			obj["is_completed"] = is_completed
	print("[CLIENT] Impostor objective '%s' marked completed." % objective_id)
	impostor_objective_updated.emit(objective_id, is_completed)

func handle_investigation_started() -> void:
	is_investigation_active = true
	print("[CLIENT] Investigation phase started. Awaiting factual evidence dataset...")
	investigation_started.emit()

func handle_investigation_evidence(evidence_list: Array) -> void:
	investigation_evidence = evidence_list
	is_investigation_active = true
	print("[CLIENT] Public investigation evidence received: %d factual records available." % evidence_list.size())
	investigation_evidence_received.emit(evidence_list)

func handle_lobby_sync(state: int, player_count: int, ready_count: int, players_info: Array) -> void:
	current_game_state = state as NetworkConfig.GameState
	if current_game_state == NetworkConfig.GameState.LOBBY and (is_game_over or assigned_role != NetworkConfig.PlayerRole.NONE):
		reset_match_state()
	server_player_count = player_count
	ready_player_count = ready_count
	lobby_players_data = players_info

	for p in players_info:
		if int(p.get("peer_id", 0)) == assigned_peer_id:
			var prev_ready = is_ready
			is_ready = bool(p.get("is_ready", false))
			if prev_ready != is_ready:
				ready_state_updated.emit(is_ready)

	print("[CLIENT] Lobby Sync — Players: %d/%d | Ready: %d/%d | State: %s" % [
		player_count, NetworkConfig.MAX_PLAYERS, ready_count, player_count,
		NetworkConfig.get_game_state_name(current_game_state)
	])
	lobby_synced.emit(current_game_state, player_count, ready_count, players_info)

func handle_game_state_changed(new_state: int) -> void:
	current_game_state = new_state as NetworkConfig.GameState
	if current_game_state == NetworkConfig.GameState.LOBBY:
		reset_match_state()
	print("[CLIENT] Authoritative game state changed: %s" % NetworkConfig.get_game_state_name(current_game_state))
	game_state_changed.emit(current_game_state)

func handle_player_joined(p_peer_id: int, p_slot: int) -> void:
	print("[CLIENT] Peer joined the game: ID %d (Slot %d)" % [p_peer_id, p_slot])
	other_player_connected.emit(p_peer_id, p_slot)

func handle_player_left(p_peer_id: int) -> void:
	print("[CLIENT] Peer left the game: ID %d" % p_peer_id)
	other_player_disconnected.emit(p_peer_id)

func handle_meeting_started(caller_peer_id: int, discussion_duration: float) -> void:
	is_meeting_active = true
	meeting_caller_id = caller_peer_id
	current_meeting_phase = MeetingConfig.MeetingPhase.DISCUSSION
	discussion_remaining_duration = discussion_duration
	has_voted_this_round = false
	print("[CLIENT] Meeting started by Player %d (Discussion: %.1fs)." % [caller_peer_id, discussion_duration])
	meeting_started.emit(caller_peer_id, discussion_duration)

func handle_voting_started(voting_duration: float) -> void:
	current_meeting_phase = MeetingConfig.MeetingPhase.VOTING
	voting_remaining_duration = voting_duration
	print("[CLIENT] Voting phase started (Duration: %.1fs)." % voting_duration)
	voting_started.emit(voting_duration)

func handle_player_voted(voter_peer_id: int) -> void:
	if voter_peer_id == assigned_peer_id:
		has_voted_this_round = true
	print("[CLIENT] Player %d has submitted their vote." % voter_peer_id)
	player_voted.emit(voter_peer_id)

func handle_vote_result(result_data: Dictionary) -> void:
	is_meeting_active = false
	current_meeting_phase = MeetingConfig.MeetingPhase.RESULTS
	last_vote_result = result_data
	var elim_id = int(result_data.get("eliminated_peer_id", 0))
	if elim_id == assigned_peer_id and elim_id > 0:
		is_eliminated = true
		print("[CLIENT] You have been ELIMINATED by plurality vote!")
	print("[CLIENT] Meeting resolved. Results: %s" % str(result_data))
	vote_result_received.emit(result_data)

func handle_meltdown_started(duration: float, impostor_alive: bool) -> void:
	is_meltdown_active = true
	meltdown_remaining_duration = duration
	is_impostor_alive_at_meltdown = impostor_alive
	completed_emergency_systems.clear()
	is_game_over = false
	print("[CLIENT] MELTDOWN STARTED! Duration: %.1f seconds (Impostor Alive: %s)." % [duration, str(impostor_alive)])
	meltdown_started.emit(duration, impostor_alive)

func handle_emergency_system_completed(system_id: String, p_completed_systems: Array) -> void:
	completed_emergency_systems = p_completed_systems
	print("[CLIENT] Emergency system '%s' restored. Total restored: %d/3." % [
		system_id, p_completed_systems.size()
	])
	emergency_system_completed.emit(system_id, p_completed_systems)

func handle_game_over(p_winner_role: int, p_reason: int, result_data: Dictionary) -> void:
	is_meltdown_active = false
	is_game_over = true
	game_winner = p_winner_role as NetworkConfig.PlayerRole
	game_over_reason = p_reason
	game_over_result = result_data
	print("[CLIENT] *** GAME OVER *** Winner: %s | Reason: %s" % [
		NetworkConfig.get_role_name(game_winner),
		MeltdownConfig.get_game_over_reason_name(p_reason as MeltdownConfig.GameOverReason)
	])
	game_over_received.emit(game_winner, p_reason, result_data)

func handle_remote_player_position(peer_id: int, pos: Vector2, vel: Vector2, facing: Vector2) -> void:
	remote_player_position_updated.emit(peer_id, pos, vel, facing)

func handle_sabotage_state_sync(p_sabotage_type: int, p_state: int, duration: float) -> void:
	current_sabotage_type = p_sabotage_type
	current_sabotage_state = p_state
	is_sabotage_active = (p_state == SabotageManager.SabotageState.ACTIVE)
	print("[CLIENT] Authoritative sabotage state received: %s -> %s (Duration: %.1fs)." % [
		SabotageManager.get_sabotage_display_name(p_sabotage_type as SabotageManager.SabotageType),
		SabotageManager.get_state_name(p_state as SabotageManager.SabotageState),
		duration
	])
	sabotage_state_synced.emit(p_sabotage_type, p_state, duration)

func handle_round_state_sync(p_round_state: int) -> void:
	current_round_state = p_round_state
	print("[CLIENT] Authoritative round state received: %s." % RoundManager.get_state_name(p_round_state as RoundManager.RoundState))
	round_state_synced.emit(p_round_state)




