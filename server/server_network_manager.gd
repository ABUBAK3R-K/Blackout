class_name ServerNetworkManager
extends Node

## Server-side network manager responsible for authoritative connection lifecycle,
## peer slot assignments, player limits, ready state validation, authoritative role assignment,
## task lifecycle management, Blackout management, and game state transitions.

const NetworkConfig = preload("res://shared/network_config.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")
const TaskManager = preload("res://server/task_manager.gd")
const BlackoutManager = preload("res://server/blackout_manager.gd")
const BlackoutRecoveryManager = preload("res://server/blackout_recovery_manager.gd")
const ImpostorObjectiveManager = preload("res://server/impostor_objective_manager.gd")
const EvidenceManager = preload("res://server/evidence_manager.gd")
const MeetingManager = preload("res://server/meeting_manager.gd")
const VotingManager = preload("res://server/voting_manager.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const MeltdownManager = preload("res://server/meltdown_manager.gd")

signal server_started(port: int)
signal server_stopped()
signal player_connected(peer_id: int, player_data: PlayerConnectionData)
signal player_disconnected(peer_id: int, slot: int)
signal connection_rejected(peer_id: int, reason: String)
signal player_count_changed(count: int)
signal player_ready_changed(peer_id: int, is_ready: bool, ready_count: int)
signal lobby_status_updated(player_count: int, ready_count: int)
signal game_state_changed(new_state: NetworkConfig.GameState)
signal roles_assigned(crew_count: int, impostor_count: int)
signal task_completed_on_server(peer_id: int, task_id: String, is_impostor: bool)
signal blackout_unlocked_on_server()
signal recovery_system_restored(peer_id: int, system_id: String, completed_count: int, required_count: int)
signal recovery_threshold_achieved(completed_count: int, required_count: int)
signal impostor_objective_completed_on_server(peer_id: int, objective_id: String)
signal evidence_generated(evidence: RefCounted)
signal investigation_started_on_server(public_evidence: Array)
signal meeting_initiated(caller_peer_id: int, discussion_duration: float)
signal voting_phase_initiated(voting_duration: float)
signal vote_registered(voter_peer_id: int)
signal meeting_resolved(result: Dictionary)
signal player_eliminated_on_server(peer_id: int, was_impostor: bool)
signal meltdown_phase_started(duration: float, impostor_alive: bool)
signal emergency_system_completed_on_server(peer_id: int, system_id: String, completed_systems: Array)
signal match_concluded(winner_role: NetworkConfig.PlayerRole, reason: MeltdownConfig.GameOverReason, result_data: Dictionary)

var peer: ENetMultiplayerPeer = null
var is_running: bool = false
var active_port: int = 0
var current_game_state: NetworkConfig.GameState = NetworkConfig.GameState.LOBBY

var task_manager: TaskManager = null
var blackout_manager: BlackoutManager = null
var recovery_manager: BlackoutRecoveryManager = null
var impostor_objective_manager: ImpostorObjectiveManager = null
var evidence_manager: EvidenceManager = null
var meeting_manager: MeetingManager = null
var voting_manager: VotingManager = null
var meltdown_manager: MeltdownManager = null

var is_impostor_eliminated: bool = false

## Server-authoritative collection of connected players: { peer_id (int) -> PlayerConnectionData }
var connected_players: Dictionary = {}

func _init() -> void:
	task_manager = TaskManager.new()
	blackout_manager = BlackoutManager.new()
	recovery_manager = BlackoutRecoveryManager.new()
	impostor_objective_manager = ImpostorObjectiveManager.new()
	evidence_manager = EvidenceManager.new()
	meeting_manager = MeetingManager.new()
	voting_manager = VotingManager.new()
	meltdown_manager = MeltdownManager.new()

	blackout_manager.countdown_started.connect(_on_blackout_countdown_started)
	blackout_manager.countdown_cancelled.connect(_on_blackout_countdown_cancelled)
	blackout_manager.blackout_started.connect(_on_blackout_started)
	blackout_manager.blackout_ended.connect(_on_blackout_ended)

	recovery_manager.recovery_systems_initialized.connect(_on_recovery_systems_initialized)
	recovery_manager.recovery_system_completed.connect(_on_recovery_system_completed)
	recovery_manager.recovery_threshold_reached.connect(_on_recovery_threshold_reached)

	impostor_objective_manager.objective_completed.connect(_on_impostor_objective_completed)

	evidence_manager.evidence_created.connect(_on_evidence_created)
	evidence_manager.investigation_finalized.connect(_on_investigation_finalized)

	meeting_manager.meeting_started.connect(_on_meeting_started)
	meeting_manager.voting_phase_started.connect(_on_voting_phase_started)
	meeting_manager.meeting_completed.connect(_on_meeting_completed)

	voting_manager.vote_recorded.connect(_on_vote_recorded)

	meltdown_manager.meltdown_started.connect(_on_meltdown_started)
	meltdown_manager.emergency_system_completed.connect(_on_emergency_system_completed)
	meltdown_manager.game_over_triggered.connect(_on_game_over_triggered)

func _process(delta: float) -> void:
	if is_running:
		if blackout_manager != null:
			blackout_manager.tick(delta)
		if meeting_manager != null:
			meeting_manager.tick(delta, connected_players, blackout_manager.impostor_peer_id, voting_manager)
		if meltdown_manager != null:
			meltdown_manager.tick(delta)

func _get_mp() -> MultiplayerAPI:
	if is_inside_tree():
		return multiplayer
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).get_multiplayer()
	return null

func start_server(port: int = NetworkConfig.DEFAULT_PORT, max_players: int = NetworkConfig.MAX_PLAYERS) -> Error:
	if is_running:
		push_warning("[SERVER] Server is already running on port %d." % active_port)
		return OK

	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, NetworkConfig.MAX_SOCKET_CONNECTIONS)
	if error != OK:
		push_error("[SERVER] Failed to start ENet server on port %d. Error code: %d" % [port, error])
		peer = null
		return error

	var mp = _get_mp()
	if mp != null:
		mp.multiplayer_peer = peer
		if not mp.peer_connected.is_connected(_on_peer_connected):
			mp.peer_connected.connect(_on_peer_connected)
		if not mp.peer_disconnected.is_connected(_on_peer_disconnected):
			mp.peer_disconnected.connect(_on_peer_disconnected)

	is_running = true
	active_port = port
	current_game_state = NetworkConfig.GameState.LOBBY
	connected_players.clear()
	task_manager.clear()
	blackout_manager.clear()
	recovery_manager.clear()
	impostor_objective_manager.clear()
	evidence_manager.clear()
	meeting_manager.clear()
	voting_manager.clear()
	meltdown_manager.clear()
	is_impostor_eliminated = false

	print("[SERVER] Authoritative ENet server started on port %d (Max Players: %d | State: LOBBY)." % [port, max_players])
	server_started.emit(port)
	return OK

func stop_server() -> void:
	if not is_running:
		return

	print("[SERVER] Stopping authoritative ENet server on port %d." % active_port)

	var mp = _get_mp()
	if mp != null:
		if mp.peer_connected.is_connected(_on_peer_connected):
			mp.peer_connected.disconnect(_on_peer_connected)
		if mp.peer_disconnected.is_connected(_on_peer_disconnected):
			mp.peer_disconnected.disconnect(_on_peer_disconnected)
		if mp.multiplayer_peer == peer:
			mp.multiplayer_peer = null

	for peer_id in connected_players.keys():
		if peer != null:
			peer.disconnect_peer(peer_id)

	connected_players.clear()
	task_manager.clear()
	blackout_manager.clear()
	recovery_manager.clear()
	impostor_objective_manager.clear()
	evidence_manager.clear()
	meeting_manager.clear()
	voting_manager.clear()
	is_impostor_eliminated = false

	if peer != null:
		peer.close()
		peer = null

	is_running = false
	active_port = 0
	current_game_state = NetworkConfig.GameState.LOBBY
	server_stopped.emit()
	print("[SERVER] Server stopped.")

func is_server_active() -> bool:
	var mp = _get_mp()
	return is_running and mp != null and mp.is_server()

func get_connected_player_count() -> int:
	return connected_players.size()

func get_ready_player_count() -> int:
	var count: int = 0
	for p: PlayerConnectionData in connected_players.values():
		if p.is_ready:
			count += 1
	return count

func get_connected_players() -> Dictionary:
	return connected_players.duplicate()

func get_player_data(peer_id: int) -> PlayerConnectionData:
	return connected_players.get(peer_id, null)

func set_player_ready(peer_id: int, ready_status: bool) -> bool:
	if not is_running:
		push_warning("[SERVER] Cannot set ready state: server is not active.")
		return false

	if current_game_state != NetworkConfig.GameState.LOBBY:
		push_warning("[SERVER] Ignored ready request from peer %d: match is not in LOBBY (Current State: %s)." % [
			peer_id, NetworkConfig.get_game_state_name(current_game_state)
		])
		return false

	if not connected_players.has(peer_id):
		push_warning("[SERVER] Ignored ready request from unknown or disconnected peer %d." % peer_id)
		return false

	var player_data: PlayerConnectionData = connected_players[peer_id]
	if player_data.is_ready == ready_status:
		return true

	player_data.is_ready = ready_status
	var ready_str: String = "READY" if ready_status else "NOT READY"
	print("[SERVER] Player %d (Slot %d) is now %s." % [peer_id, player_data.player_slot, ready_str])
	print("[SERVER] Lobby Status — Players: %d/%d | Ready: %d/%d" % [
		connected_players.size(), NetworkConfig.MAX_PLAYERS, get_ready_player_count(), connected_players.size()
	])

	player_ready_changed.emit(peer_id, ready_status, get_ready_player_count())
	lobby_status_updated.emit(connected_players.size(), get_ready_player_count())

	_broadcast_lobby_sync()
	_check_lobby_start_condition()
	return true

func _check_lobby_start_condition() -> void:
	if current_game_state != NetworkConfig.GameState.LOBBY:
		return

	var total_players: int = connected_players.size()
	var ready_players: int = get_ready_player_count()

	if total_players == NetworkConfig.MAX_PLAYERS and ready_players == NetworkConfig.MAX_PLAYERS:
		print("[SERVER] Match start condition satisfied! Exactly %d/%d players connected and all are READY." % [
			total_players, NetworkConfig.MAX_PLAYERS
		])
		_transition_game_state(NetworkConfig.GameState.ROLE_ASSIGNMENT)
		assign_roles()

func assign_roles() -> bool:
	if not is_running:
		push_warning("[SERVER] Cannot assign roles: server is not active.")
		return false

	if current_game_state != NetworkConfig.GameState.ROLE_ASSIGNMENT:
		push_warning("[SERVER] Cannot assign roles: current state is %s (Expected: ROLE_ASSIGNMENT)." % [
			NetworkConfig.get_game_state_name(current_game_state)
		])
		return false

	var total_players: int = connected_players.size()
	if total_players != NetworkConfig.MAX_PLAYERS:
		push_warning("[SERVER] Cannot assign roles: requires exactly %d players (Current: %d)." % [
			NetworkConfig.MAX_PLAYERS, total_players
		])
		return false

	print("[SERVER] Authoritative role assignment started for %d players..." % total_players)

	var peer_ids: Array = connected_players.keys()
	var impostor_index: int = randi() % peer_ids.size()
	var impostor_peer_id: int = peer_ids[impostor_index]

	var crew_count: int = 0
	var impostor_count: int = 0

	for pid in peer_ids:
		var player_data: PlayerConnectionData = connected_players[pid]
		if pid == impostor_peer_id:
			player_data.role = NetworkConfig.PlayerRole.IMPOSTOR
			impostor_count += 1
		else:
			player_data.role = NetworkConfig.PlayerRole.CREW
			crew_count += 1

	print("[SERVER] Authoritative role assignment completed: %d Crew, %d Impostor." % [crew_count, impostor_count])

	# Setup BlackoutManager with the assigned Impostor
	blackout_manager.setup(impostor_peer_id)

	# Privately deliver each role to its specific peer connection only
	var net_mgr = get_parent()
	for pid in peer_ids:
		var p_role = connected_players[pid].role
		if net_mgr != null and net_mgr.has_method("send_private_role"):
			net_mgr.send_private_role(pid, p_role)

	roles_assigned.emit(crew_count, impostor_count)

	# Transition deterministically to INITIAL_TASK_PHASE
	_transition_game_state(NetworkConfig.GameState.INITIAL_TASK_PHASE)

	# Assign tasks for the match
	_assign_initial_tasks()
	return true

func _assign_initial_tasks() -> void:
	if task_manager == null:
		return

	var ok = task_manager.assign_tasks(connected_players)
	if not ok:
		push_error("[SERVER] Task assignment failed!")
		return

	var net_mgr = get_parent()
	for pid in connected_players.keys():
		var p_tasks = task_manager.get_player_tasks(pid)
		var serialized_tasks: Array = []
		for t in p_tasks:
			serialized_tasks.append(t.to_dict())
		if net_mgr != null and net_mgr.has_method("send_private_task_list"):
			net_mgr.send_private_task_list(pid, serialized_tasks)

func process_task_completion_request(peer_id: int, task_id: String) -> Dictionary:
	if not is_running:
		return {"success": false, "error": "Server not running"}

	if task_manager == null:
		return {"success": false, "error": "TaskManager not initialized"}

	var result = task_manager.complete_task(peer_id, task_id, current_game_state)
	if result.get("success", false):
		var is_impostor: bool = bool(result.get("is_impostor", false))
		var all_prereqs: bool = bool(result.get("all_prereqs_completed", false))

		task_completed_on_server.emit(peer_id, task_id, is_impostor)

		var net_mgr = get_parent()
		if net_mgr != null and net_mgr.has_method("send_task_update"):
			net_mgr.send_task_update(peer_id, task_id, true)

		# If Impostor finished all prerequisites, unlock Blackout
		if is_impostor and all_prereqs:
			print("[SERVER] Impostor completed all prerequisite tasks! BLACKOUT is now UNLOCKED.")
			_transition_game_state(NetworkConfig.GameState.BLACKOUT_AVAILABLE)
			blackout_unlocked_on_server.emit()

			# Privately notify only the Impostor
			if net_mgr != null and net_mgr.has_method("notify_blackout_unlocked"):
				net_mgr.notify_blackout_unlocked(peer_id)

	return result

func process_blackout_activation_request(peer_id: int) -> Dictionary:
	if not is_running:
		return {"success": false, "error": "Server not running"}

	if blackout_manager == null:
		return {"success": false, "error": "BlackoutManager not initialized"}

	return blackout_manager.request_activation(peer_id, current_game_state)

func _on_blackout_countdown_started(duration: float) -> void:
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_blackout_countdown"):
		net_mgr.broadcast_blackout_countdown(duration, connected_players.keys())

func _on_blackout_countdown_cancelled(reason: String) -> void:
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_blackout_countdown_cancelled"):
		net_mgr.broadcast_blackout_countdown_cancelled(reason, connected_players.keys())

func _on_blackout_started(duration: float) -> void:
	_transition_game_state(NetworkConfig.GameState.BLACKOUT_ACTIVE)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_blackout_started"):
		net_mgr.broadcast_blackout_started(duration, connected_players.keys())

	# Initialize distributed recovery subsystems for Crew
	recovery_manager.initialize_systems()

	# Assign secret objectives privately to Impostor
	var secret_objs: Array = impostor_objective_manager.assign_objectives(blackout_manager.impostor_peer_id)
	if net_mgr != null and net_mgr.has_method("send_private_objective_list"):
		net_mgr.send_private_objective_list(blackout_manager.impostor_peer_id, secret_objs)

func _on_recovery_systems_initialized(systems_data: Array, required_count: int) -> void:
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_recovery_initialization"):
		net_mgr.broadcast_recovery_initialization(required_count, systems_data, connected_players.keys())

func _on_recovery_system_completed(peer_id: int, system_id: String, completed_count: int, required_count: int) -> void:
	recovery_system_restored.emit(peer_id, system_id, completed_count, required_count)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_recovery_update"):
		net_mgr.broadcast_recovery_update(system_id, true, completed_count, required_count, connected_players.keys())

	# Generate factual recovery evidence
	if evidence_manager != null:
		var rec = recovery_manager.get_system(system_id)
		var disp_name = rec.display_name if rec != null else system_id
		var loc_id = rec.location_id if rec != null else "station_subsystem"
		evidence_manager.create_evidence_from_recovery(system_id, disp_name, loc_id, peer_id)

func _on_recovery_threshold_reached(completed_count: int, required_count: int) -> void:
	recovery_threshold_achieved.emit(completed_count, required_count)
	print("[SERVER] Recovery threshold reached (%d/%d). Ending Blackout early!" % [completed_count, required_count])
	blackout_manager.end_blackout_early("Crew restored required recovery systems (%d/%d)" % [completed_count, required_count])

func _on_impostor_objective_completed(peer_id: int, objective_id: String) -> void:
	impostor_objective_completed_on_server.emit(peer_id, objective_id)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("send_private_objective_update"):
		net_mgr.send_private_objective_update(peer_id, objective_id, true)

	# Generate factual objective evidence
	if evidence_manager != null:
		evidence_manager.create_evidence_from_objective(objective_id, peer_id)

func _on_evidence_created(evidence: RefCounted) -> void:
	evidence_generated.emit(evidence)

func _on_investigation_finalized(_public_evidence_list: Array) -> void:
	pass

func process_recovery_request(peer_id: int, system_id: String) -> Dictionary:
	if not is_running:
		return {"success": false, "error": "Server not running"}

	if recovery_manager == null:
		return {"success": false, "error": "RecoveryManager not initialized"}

	var player = get_player_data(peer_id)
	var is_crew = (player != null and player.role == NetworkConfig.PlayerRole.CREW)
	return recovery_manager.request_recover_system(peer_id, system_id, current_game_state, is_crew)

func process_impostor_objective_completion_request(peer_id: int, objective_id: String) -> Dictionary:
	if not is_running:
		return {"success": false, "error": "Server not running"}

	if impostor_objective_manager == null:
		return {"success": false, "error": "ImpostorObjectiveManager not initialized"}

	var player = get_player_data(peer_id)
	var is_impostor = (player != null and player.role == NetworkConfig.PlayerRole.IMPOSTOR)
	return impostor_objective_manager.request_complete_objective(peer_id, objective_id, current_game_state, is_impostor)

func process_call_meeting_request(peer_id: int) -> Dictionary:
	if not is_running:
		return {"success": false, "error": "Server not running"}

	if meeting_manager == null:
		return {"success": false, "error": "MeetingManager not initialized"}

	return meeting_manager.request_call_meeting(peer_id, current_game_state, connected_players)

func process_cast_vote_request(peer_id: int, target_peer_id: int) -> Dictionary:
	if not is_running:
		return {"success": false, "error": "Server not running"}

	if voting_manager == null:
		return {"success": false, "error": "VotingManager not initialized"}

	var result = voting_manager.cast_vote(peer_id, target_peer_id, current_game_state, connected_players)
	if result.get("success", false) and meeting_manager != null:
		if voting_manager.have_all_active_voted(connected_players):
			meeting_manager._resolve_meeting_and_voting(connected_players, blackout_manager.impostor_peer_id, voting_manager)
	return result

func process_emergency_system_completion_request(peer_id: int, system_id: String) -> Dictionary:
	if not is_running:
		return {"success": false, "error": "Server not running"}

	if meltdown_manager == null:
		return {"success": false, "error": "MeltdownManager not initialized"}

	return meltdown_manager.complete_emergency_system(peer_id, system_id, current_game_state, connected_players)

func _on_meeting_started(caller_peer_id: int, discussion_duration: float) -> void:
	_transition_game_state(NetworkConfig.GameState.MEETING)
	meeting_initiated.emit(caller_peer_id, discussion_duration)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_meeting_started"):
		net_mgr.broadcast_meeting_started(caller_peer_id, discussion_duration, connected_players.keys())

func _on_voting_phase_started(voting_duration: float) -> void:
	_transition_game_state(NetworkConfig.GameState.VOTING)
	voting_phase_initiated.emit(voting_duration)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_voting_started"):
		net_mgr.broadcast_voting_started(voting_duration, connected_players.keys())

func _on_vote_recorded(voter_peer_id: int) -> void:
	vote_registered.emit(voter_peer_id)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_player_voted"):
		net_mgr.broadcast_player_voted(voter_peer_id, connected_players.keys())

func _on_meeting_completed(result: Dictionary) -> void:
	var elim_id: int = int(result.get("eliminated_peer_id", 0))
	var was_imp: bool = bool(result.get("was_impostor", false))

	if elim_id > 0 and connected_players.has(elim_id):
		var elim_player: PlayerConnectionData = connected_players[elim_id]
		elim_player.is_alive = false
		elim_player.is_eliminated = true
		if was_imp:
			is_impostor_eliminated = true
		print("[SERVER] Player %d (Slot %d) has been ELIMINATED by vote! (Was Impostor: %s)" % [
			elim_id, elim_player.player_slot, str(was_imp)
		])
		player_eliminated_on_server.emit(elim_id, was_imp)

	meeting_resolved.emit(result)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_vote_result"):
		net_mgr.broadcast_vote_result(result, connected_players.keys())

	# CRITICAL GAME RULE (Step 9): Regardless of vote outcome, ALWAYS transition to MELTDOWN!
	_transition_game_state(NetworkConfig.GameState.MELTDOWN)

func _on_meltdown_started(duration: float, impostor_alive: bool) -> void:
	meltdown_phase_started.emit(duration, impostor_alive)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_meltdown_started"):
		net_mgr.broadcast_meltdown_started(duration, impostor_alive, connected_players.keys())

func _on_emergency_system_completed(system_id: String, completed_systems: Array) -> void:
	emergency_system_completed_on_server.emit(0, system_id, completed_systems)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_emergency_system_completed"):
		net_mgr.broadcast_emergency_system_completed(system_id, completed_systems, connected_players.keys())

func _on_game_over_triggered(winner_role: NetworkConfig.PlayerRole, reason: MeltdownConfig.GameOverReason, result_data: Dictionary) -> void:
	_transition_game_state(NetworkConfig.GameState.GAME_OVER)
	match_concluded.emit(winner_role, reason, result_data)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_game_over"):
		net_mgr.broadcast_game_over(winner_role, reason, result_data, connected_players.keys())

func _on_blackout_ended() -> void:
	_transition_game_state(NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION)
	var net_mgr = get_parent()
	if net_mgr != null:
		if net_mgr.has_method("broadcast_blackout_ended"):
			net_mgr.broadcast_blackout_ended(connected_players.keys())

		if evidence_manager != null:
			var pub_evidence = evidence_manager.finalize_investigation()
			investigation_started_on_server.emit(pub_evidence)
			if net_mgr.has_method("broadcast_investigation_started"):
				net_mgr.broadcast_investigation_started(connected_players.keys())
			if net_mgr.has_method("broadcast_investigation_evidence"):
				net_mgr.broadcast_investigation_evidence(pub_evidence, connected_players.keys())

func _transition_game_state(new_state: NetworkConfig.GameState) -> void:
	var prev_state_name: String = NetworkConfig.get_game_state_name(current_game_state)
	var new_state_name: String = NetworkConfig.get_game_state_name(new_state)
	current_game_state = new_state

	print("[SERVER] Game state transitioned: %s -> %s." % [prev_state_name, new_state_name])
	game_state_changed.emit(new_state)

	if new_state == NetworkConfig.GameState.MELTDOWN and meltdown_manager != null:
		meltdown_manager.start_meltdown(not is_impostor_eliminated)

	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_game_state"):
		net_mgr.broadcast_game_state(new_state, connected_players.keys())

func _allocate_player_slot() -> int:
	var occupied_slots: Array = []
	for p: PlayerConnectionData in connected_players.values():
		occupied_slots.append(p.player_slot)

	for slot in range(1, NetworkConfig.MAX_PLAYERS + 1):
		if not occupied_slots.has(slot):
			return slot
	return 0

func _on_peer_connected(peer_id: int) -> void:
	if connected_players.size() >= NetworkConfig.MAX_PLAYERS:
		var rejection_msg: String = "Server is full (Maximum %d players reached)." % NetworkConfig.MAX_PLAYERS
		print("[SERVER] Connection rejected from peer %d: %s" % [peer_id, rejection_msg])
		
		var net_manager = get_parent()
		if net_manager != null and net_manager.has_method("send_connection_rejection"):
			net_manager.send_connection_rejection(peer_id, rejection_msg)
		
		connection_rejected.emit(peer_id, rejection_msg)
		_schedule_peer_disconnect(peer_id)
		return

	var slot: int = _allocate_player_slot()
	var player_data: PlayerConnectionData = PlayerConnectionData.new(peer_id, slot, false, NetworkConfig.PlayerRole.NONE)
	connected_players[peer_id] = player_data

	print("[SERVER] Player joined lobby. Peer ID: %d | Assigned Slot: %d | Total Players: %d/%d (Ready: %d/%d)" % [
		peer_id, slot, connected_players.size(), NetworkConfig.MAX_PLAYERS, get_ready_player_count(), connected_players.size()
	])

	player_connected.emit(peer_id, player_data)
	player_count_changed.emit(connected_players.size())
	lobby_status_updated.emit(connected_players.size(), get_ready_player_count())

	var net_mgr = get_parent()
	if net_mgr != null:
		if net_mgr.has_method("send_player_assignment"):
			net_mgr.send_player_assignment(peer_id, slot, connected_players.size())
		if net_mgr.has_method("broadcast_player_joined"):
			net_mgr.broadcast_player_joined(peer_id, slot, connected_players.keys())

	_broadcast_lobby_sync()

func _on_peer_disconnected(peer_id: int) -> void:
	if not connected_players.has(peer_id):
		return

	var player_data: PlayerConnectionData = connected_players[peer_id]
	var slot: int = player_data.player_slot
	connected_players.erase(peer_id)

	if task_manager != null:
		task_manager.handle_player_disconnect(peer_id)

	if blackout_manager != null:
		blackout_manager.handle_impostor_disconnect(peer_id)

	if recovery_manager != null:
		recovery_manager.handle_player_disconnect(peer_id)

	if impostor_objective_manager != null:
		impostor_objective_manager.handle_player_disconnect(peer_id)

	if evidence_manager != null:
		evidence_manager.handle_player_disconnect(peer_id)

	if meeting_manager != null:
		meeting_manager.handle_player_disconnect(peer_id)

	if voting_manager != null:
		voting_manager.handle_player_disconnect(peer_id)

	if meltdown_manager != null:
		meltdown_manager.handle_player_disconnect(peer_id)

	print("[SERVER] Player disconnected. Peer ID: %d (Slot %d) | Remaining Players: %d/%d (Ready: %d/%d)" % [
		peer_id, slot, connected_players.size(), NetworkConfig.MAX_PLAYERS, get_ready_player_count(), connected_players.size()
	])

	player_disconnected.emit(peer_id, slot)
	player_count_changed.emit(connected_players.size())
	lobby_status_updated.emit(connected_players.size(), get_ready_player_count())

	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_player_left"):
		net_mgr.broadcast_player_left(peer_id, connected_players.keys())

	_broadcast_lobby_sync()

func _broadcast_lobby_sync() -> void:
	var players_info: Array = []
	for p: PlayerConnectionData in connected_players.values():
		players_info.append(p.to_dict())

	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_lobby_sync"):
		net_mgr.broadcast_lobby_sync(current_game_state, connected_players.size(), get_ready_player_count(), players_info, connected_players.keys())

func _schedule_peer_disconnect(peer_id: int) -> void:
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var timer = (main_loop as SceneTree).create_timer(0.05)
		timer.timeout.connect(func():
			if peer != null and is_running:
				peer.disconnect_peer(peer_id)
		)
