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
const RoleManager = preload("res://shared/role_manager.gd")
const SabotageManager = preload("res://shared/sabotage_manager.gd")
const RoundManager = preload("res://shared/round_manager.gd")
const WinConditionManager = preload("res://server/win_condition_manager.gd")

## Authoritative Kill and Body Report Configuration Constants
const KILL_RANGE: float = 90.0
const KILL_COOLDOWN: float = 25.0
const REPORT_RANGE: float = 90.0


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
signal player_killed_on_server(killer_peer_id: int, victim_peer_id: int, position: Vector2)
signal corpse_spawned_on_server(corpse_id: int, victim_peer_id: int, position: Vector2)
signal corpse_reported_on_server(corpse_id: int, reporter_peer_id: int)
signal meltdown_phase_started(duration: float, impostor_alive: bool)
signal emergency_system_completed_on_server(peer_id: int, system_id: String, completed_systems: Array)
signal match_concluded(winner_role: NetworkConfig.PlayerRole, reason: MeltdownConfig.GameOverReason, result_data: Dictionary)
signal sabotage_activated_on_server(sabotage_type: int, initiator_peer_id: int)
signal sabotage_resolved_on_server(sabotage_type: int, reason: String)
signal round_state_updated(previous_state: RoundManager.RoundState, new_state: RoundManager.RoundState)
signal returned_to_lobby()

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
var sabotage_manager: SabotageManager = null
var round_manager: RoundManager = null
var win_condition_manager: WinConditionManager = null


var is_impostor_eliminated: bool = false

## Server-authoritative tracking for player positions, kill cooldowns, and active corpses
var player_positions: Dictionary = {} # { peer_id (int) -> Vector2 }
var impostor_last_kill_time: Dictionary = {} # { peer_id (int) -> float }
var active_corpses: Dictionary = {} # { corpse_id (int) -> Dictionary }
var next_corpse_id: int = 1

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
	sabotage_manager = SabotageManager.new()
	round_manager = RoundManager.new()
	win_condition_manager = meltdown_manager.win_condition_manager


	blackout_manager.countdown_started.connect(_on_blackout_countdown_started)
	blackout_manager.countdown_cancelled.connect(_on_blackout_countdown_cancelled)
	blackout_manager.blackout_started.connect(_on_blackout_started)
	blackout_manager.blackout_ended.connect(_on_blackout_ended)

	sabotage_manager.sabotage_started.connect(_on_sabotage_started)
	sabotage_manager.sabotage_resolved.connect(_on_sabotage_resolved)

	round_manager.round_state_changed.connect(_on_round_state_changed)


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
		if sabotage_manager != null:
			sabotage_manager.tick(delta)
		if round_manager != null:
			round_manager.tick(delta)
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
	sabotage_manager.clear()
	round_manager.clear()
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
	sabotage_manager.clear()
	round_manager.clear()
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
		if round_manager != null:
			if round_manager.is_lobby():
				round_manager.transition_to(RoundManager.RoundState.STARTING)
			if round_manager.is_starting():
				round_manager.transition_to(RoundManager.RoundState.ROLE_ASSIGNMENT)
		else:
			_transition_game_state(NetworkConfig.GameState.ROLE_ASSIGNMENT)
			assign_roles()


func assign_roles(allow_variable_player_count: bool = false, deterministic_impostor_index: int = -1) -> bool:
	if not is_running:
		push_warning("[SERVER] Cannot assign roles: server is not active.")
		return false

	if current_game_state != NetworkConfig.GameState.ROLE_ASSIGNMENT:
		push_warning("[SERVER] Cannot assign roles: current state is %s (Expected: ROLE_ASSIGNMENT)." % [
			NetworkConfig.get_game_state_name(current_game_state)
		])
		return false

	var total_players: int = connected_players.size()
	if not allow_variable_player_count and total_players != NetworkConfig.MAX_PLAYERS:
		push_warning("[SERVER] Cannot assign roles: requires exactly %d players (Current: %d)." % [
			NetworkConfig.MAX_PLAYERS, total_players
		])
		return false

	if total_players == 0:
		push_warning("[SERVER] Cannot assign roles: no connected players.")
		return false

	print("[SERVER] Authoritative role assignment started for %d players..." % total_players)

	var peer_ids: Array = connected_players.keys()
	var role_map: Dictionary = RoleManager.calculate_role_assignments(peer_ids, NetworkConfig.IMPOSTOR_COUNT, deterministic_impostor_index)

	var crew_count: int = 0
	var impostor_count: int = 0
	var first_impostor_id: int = 0

	for pid in peer_ids:
		var p_role: NetworkConfig.PlayerRole = role_map.get(pid, NetworkConfig.PlayerRole.CREW)
		var player_data: PlayerConnectionData = connected_players[pid]
		player_data.role = p_role
		if p_role == NetworkConfig.PlayerRole.IMPOSTOR:
			impostor_count += 1
			if first_impostor_id == 0:
				first_impostor_id = pid
		else:
			crew_count += 1

	print("[SERVER] Authoritative role assignment completed: %d Crew, %d Impostor." % [crew_count, impostor_count])

	# Setup BlackoutManager with the assigned Impostor if present
	if first_impostor_id > 0 and blackout_manager != null:
		blackout_manager.setup(first_impostor_id)

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

## Authoritatively processes a sabotage activation request from a client.
## Strictly validates the player's server-stored role to ensure only IMPOSTOR can trigger sabotage,
## and restricts sabotage strictly to the PLAYING round state.
func process_sabotage_request(peer_id: int, sabotage_type: int) -> Dictionary:
	if not is_running:
		return {"success": false, "error": "Server not running"}

	# Restrict sabotage strictly to PLAYING round state
	if round_manager != null and not round_manager.is_playing():
		var msg = "Sabotage request rejected: match is not in PLAYING state (Current Round: %s)." % RoundManager.get_state_name(round_manager.current_state)
		push_warning("[SERVER] %s" % msg)
		return {"success": false, "error": msg}

	if sabotage_manager == null:
		return {"success": false, "error": "SabotageManager not initialized"}

	# Authoritative role lookup from server's internal connected_players table
	var player_data: PlayerConnectionData = get_player_data(peer_id)
	if player_data == null:
		push_warning("[SERVER] Sabotage request rejected: unknown or disconnected peer %d." % peer_id)
		return {"success": false, "error": "Unknown or disconnected player"}


	var s_type = sabotage_type as SabotageManager.SabotageType
	var check = sabotage_manager.can_trigger_sabotage(peer_id, player_data.role, s_type)
	if not check.allowed:
		push_warning("[SERVER] %s" % check.reason)
		return {"success": false, "error": check.reason}

	# Authoritatively start the sabotage
	var duration: float = blackout_manager.blackout_duration if blackout_manager != null else 25.0
	var result = sabotage_manager.start_sabotage(s_type, duration, peer_id)

	sabotage_activated_on_server.emit(sabotage_type, peer_id)

	# If this is POWER_BLACKOUT, activate the facility blackout system
	if s_type == SabotageManager.SabotageType.POWER_BLACKOUT:
		print("[SERVER] Authoritative IMPOSTOR (Peer %d) activated POWER_BLACKOUT sabotage!" % peer_id)
		if blackout_manager != null:
			if not blackout_manager.is_blackout_active:
				blackout_manager._start_blackout()
		else:
			_transition_game_state(NetworkConfig.GameState.BLACKOUT_ACTIVE)

	# Broadcast authoritative sabotage state to all connected players
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_sabotage_state"):
		net_mgr.broadcast_sabotage_state(sabotage_type, SabotageManager.SabotageState.ACTIVE, duration, connected_players.keys())

	return result

## Resolves the current sabotage authoritatively and restores power.
func resolve_sabotage(reason: String = "") -> Dictionary:
	if sabotage_manager == null:
		return {"success": false, "error": "SabotageManager not initialized"}

	var prev_type = sabotage_manager.get_active_sabotage_type()
	var result = sabotage_manager.resolve_sabotage(reason)

	if prev_type != SabotageManager.SabotageType.NONE:
		sabotage_resolved_on_server.emit(prev_type, reason)

		# End blackout early if active
		if blackout_manager != null and blackout_manager.is_blackout_active:
			blackout_manager.end_blackout_early(reason)

		# Broadcast resolved state to all connected players
		var net_mgr = get_parent()
		if net_mgr != null and net_mgr.has_method("broadcast_sabotage_state"):
			net_mgr.broadcast_sabotage_state(prev_type, SabotageManager.SabotageState.RESOLVED, 0.0, connected_players.keys())

	return result

func _on_sabotage_started(_type: SabotageManager.SabotageType, _duration: float) -> void:
	pass

func _on_sabotage_resolved(_type: SabotageManager.SabotageType, _reason: String) -> void:
	pass

func _on_round_state_changed(prev: RoundManager.RoundState, next: RoundManager.RoundState) -> void:
	round_state_updated.emit(prev, next)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_round_state"):
		net_mgr.broadcast_round_state(next, connected_players.keys())

	match next:
		RoundManager.RoundState.ROLE_ASSIGNMENT:
			_transition_game_state(NetworkConfig.GameState.ROLE_ASSIGNMENT)
			assign_roles(true)
			if round_manager != null and round_manager.is_role_assignment():
				round_manager.transition_to(RoundManager.RoundState.PLAYING)

		RoundManager.RoundState.PLAYING:
			_transition_game_state(NetworkConfig.GameState.INITIAL_TASK_PHASE)

		RoundManager.RoundState.ENDING:
			if sabotage_manager != null and sabotage_manager.is_sabotage_active():
				resolve_sabotage("Round Ending")

		RoundManager.RoundState.RESULTS:
			pass

		RoundManager.RoundState.LOBBY:
			_transition_game_state(NetworkConfig.GameState.LOBBY)
			for p: PlayerConnectionData in connected_players.values():
				p.is_ready = false
				p.role = NetworkConfig.PlayerRole.NONE
			_broadcast_lobby_sync()

## Starts the round lifecycle (Development & test helper).
func start_round(allow_variable_players: bool = true, countdown: float = 0.0) -> bool:
	if not is_running or round_manager == null:
		return false
	if countdown > 0.0:
		return round_manager.start_round_countdown(countdown)
	else:
		if not round_manager.transition_to(RoundManager.RoundState.STARTING):
			return false
		return round_manager.transition_to(RoundManager.RoundState.ROLE_ASSIGNMENT)

## Ends the active round (Development & test helper).
func end_round(reason: String = "Test End of Round") -> bool:
	if round_manager == null:
		return false
	var ok = round_manager.end_round(reason)
	if ok:
		round_manager.transition_to(RoundManager.RoundState.RESULTS)
	return ok

## Resets the round state back to LOBBY (Development & test helper).
func reset_round() -> bool:
	if round_manager == null:
		return false
	return round_manager.reset_round()

## Authoritatively processes a Return to Lobby / Rematch request from a connected player.
## Cleans up all match subsystem data, resets player match state, and transitions back to LOBBY.
func process_return_to_lobby_request(peer_id: int) -> bool:
	if not is_running:
		return false

	if not connected_players.has(peer_id) and peer_id != 1:
		push_warning("[SERVER] Return to lobby request rejected: unknown peer %d." % peer_id)
		return false

	if current_game_state != NetworkConfig.GameState.GAME_OVER:
		push_warning("[SERVER] Return to lobby request rejected: match is in %s state (Expected: GAME_OVER)." % [
			NetworkConfig.get_game_state_name(current_game_state)
		])
		return false

	print("[SERVER] Processing Return to Lobby / Rematch request from Peer %d." % peer_id)

	# 1. Authoritative cleanup of all round/subsystem states
	if task_manager != null:
		task_manager.clear()
	if blackout_manager != null:
		blackout_manager.clear()
	if recovery_manager != null:
		recovery_manager.clear()
	if impostor_objective_manager != null:
		impostor_objective_manager.clear()
	if evidence_manager != null:
		evidence_manager.clear()
	if meeting_manager != null:
		meeting_manager.clear()
	if voting_manager != null:
		voting_manager.clear()
	if meltdown_manager != null:
		meltdown_manager.clear()
	if sabotage_manager != null:
		sabotage_manager.clear()
	is_impostor_eliminated = false
	active_corpses.clear()
	impostor_last_kill_time.clear()
	player_positions.clear()
	next_corpse_id = 1

	# 2. Reset connected player match data while preserving network connections and slots
	for p: PlayerConnectionData in connected_players.values():
		p.is_ready = false
		p.role = NetworkConfig.PlayerRole.NONE
		p.is_alive = true
		p.is_eliminated = false

	# 3. Reset round manager
	if round_manager != null:
		round_manager.reset_round()

	# 4. Authoritative state transition to LOBBY
	_transition_game_state(NetworkConfig.GameState.LOBBY)
	_broadcast_lobby_sync()

	returned_to_lobby.emit()
	print("[SERVER] Match reset to LOBBY complete. %d players ready for rematch." % connected_players.size())
	return true

func return_to_lobby() -> bool:
	return process_return_to_lobby_request(1)



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

## Updates tracked authoritative position for a connected peer.
func update_player_position(peer_id: int, pos: Vector2, _vel: Vector2, _facing: Vector2) -> void:
	player_positions[peer_id] = pos

## Returns the server-authoritative position of a connected player.
func get_player_authoritative_position(peer_id: int) -> Vector2:
	return player_positions.get(peer_id, Vector2.ZERO)

## Directly sets the authoritative position for a player (testing & spawning helper).
func set_player_position(peer_id: int, pos: Vector2) -> void:
	player_positions[peer_id] = pos

## Server-authoritative validation and execution of an Impostor proximity kill request.
func process_kill_request(killer_peer_id: int, target_peer_id: int) -> Dictionary:
	if not is_running:
		return {"success": false, "error": "Server not running"}

	# 1. Requesting peer is connected
	if not connected_players.has(killer_peer_id):
		return {"success": false, "error": "Killer is not a connected player"}

	var killer: PlayerConnectionData = connected_players[killer_peer_id]

	# 2. Requesting player is the Impostor
	var is_killer_imp = (killer.role == NetworkConfig.PlayerRole.IMPOSTOR) or (blackout_manager != null and killer_peer_id == blackout_manager.impostor_peer_id)
	if not is_killer_imp:
		return {"success": false, "error": "Only Impostors can initiate kill requests"}

	# 3. Requesting player is alive
	if not killer.is_alive or killer.is_eliminated:
		return {"success": false, "error": "Eliminated players cannot kill"}

	# 4. Target peer exists
	if not connected_players.has(target_peer_id):
		return {"success": false, "error": "Target player not found"}

	# 5. Target is not the requesting player (no self-kill)
	if target_peer_id == killer_peer_id:
		return {"success": false, "error": "Cannot kill self"}

	var target: PlayerConnectionData = connected_players[target_peer_id]

	# 6. Target is alive and not already eliminated
	if not target.is_alive or target.is_eliminated:
		return {"success": false, "error": "Target is already eliminated"}

	# 7. Target is a Crew player (no Impostor killing Impostor)
	var is_target_imp = (target.role == NetworkConfig.PlayerRole.IMPOSTOR) or (blackout_manager != null and target_peer_id == blackout_manager.impostor_peer_id)
	if is_target_imp:
		return {"success": false, "error": "Impostor cannot kill another Impostor"}

	# 8. Allowed game states for killing
	var allowed_states = [
		NetworkConfig.GameState.INITIAL_TASK_PHASE,
		NetworkConfig.GameState.BLACKOUT_AVAILABLE,
		NetworkConfig.GameState.BLACKOUT_ACTIVE,
		NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION,
		NetworkConfig.GameState.MELTDOWN
	]
	if not allowed_states.has(current_game_state):
		return {"success": false, "error": "Kill not permitted in match state %s" % NetworkConfig.get_game_state_name(current_game_state)}

	# 9. Not during an active meeting / voting
	if meeting_manager != null and meeting_manager.is_meeting_active:
		return {"success": false, "error": "Kill not permitted during active meeting"}

	# 10. Kill cooldown check
	var now = Time.get_ticks_msec() / 1000.0
	if impostor_last_kill_time.has(killer_peer_id):
		var elapsed = now - impostor_last_kill_time[killer_peer_id]
		if elapsed < KILL_COOLDOWN:
			return {"success": false, "error": "Kill ability on cooldown (%.1fs remaining)" % (KILL_COOLDOWN - elapsed)}

	# 11. Authoritative distance check
	var killer_pos = get_player_authoritative_position(killer_peer_id)
	var target_pos = get_player_authoritative_position(target_peer_id)
	if killer_pos != Vector2.ZERO and target_pos != Vector2.ZERO:
		var dist = killer_pos.distance_to(target_pos)
		if dist > KILL_RANGE:
			return {"success": false, "error": "Target out of kill range (%.1fpx > %.1fpx)" % [dist, KILL_RANGE]}

	# Execute authoritative kill
	impostor_last_kill_time[killer_peer_id] = now
	target.is_alive = false
	target.is_eliminated = true

	var c_id = next_corpse_id
	next_corpse_id += 1
	var victim_name = "Player %d" % target.player_slot
	var death_pos = target_pos if target_pos != Vector2.ZERO else killer_pos

	active_corpses[c_id] = {
		"corpse_id": c_id,
		"victim_peer_id": target_peer_id,
		"victim_name": victim_name,
		"position": death_pos,
		"is_reported": false
	}

	print("[SERVER] Impostor %d ELIMINATED Player %d (Slot %d) at %s! Corpse #%d spawned." % [
		killer_peer_id, target_peer_id, target.player_slot, str(death_pos), c_id
	])

	player_eliminated_on_server.emit(target_peer_id, false)
	player_killed_on_server.emit(killer_peer_id, target_peer_id, death_pos)
	corpse_spawned_on_server.emit(c_id, target_peer_id, death_pos)

	var net_mgr = get_parent()
	if net_mgr != null:
		if net_mgr.has_method("broadcast_player_eliminated"):
			net_mgr.broadcast_player_eliminated(target_peer_id, death_pos, connected_players.keys())
		if net_mgr.has_method("broadcast_corpse_spawn"):
			net_mgr.broadcast_corpse_spawn(c_id, target_peer_id, victim_name, death_pos, connected_players.keys())

	_check_crew_elimination_win_condition()

	return {"success": true, "corpse_id": c_id, "victim_peer_id": target_peer_id, "death_pos": death_pos}

## Server-authoritative validation and execution of a body report request.
func process_report_body_request(reporter_peer_id: int, corpse_id: int) -> Dictionary:
	if not is_running:
		return {"success": false, "error": "Server not running"}

	# 1. Reporting peer is connected
	if not connected_players.has(reporter_peer_id):
		return {"success": false, "error": "Reporter is not a connected player"}

	var reporter: PlayerConnectionData = connected_players[reporter_peer_id]

	# 2. Reporting player is alive
	if not reporter.is_alive or reporter.is_eliminated:
		return {"success": false, "error": "Eliminated players cannot report bodies"}

	# 3. Allowed match states for reporting bodies
	var allowed_states = [
		NetworkConfig.GameState.INITIAL_TASK_PHASE,
		NetworkConfig.GameState.BLACKOUT_AVAILABLE,
		NetworkConfig.GameState.BLACKOUT_ACTIVE,
		NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION,
		NetworkConfig.GameState.MELTDOWN
	]
	if not allowed_states.has(current_game_state):
		return {"success": false, "error": "Body reporting not permitted in match state %s" % NetworkConfig.get_game_state_name(current_game_state)}

	# 4. Not during an active meeting
	if meeting_manager != null and meeting_manager.is_meeting_active:
		return {"success": false, "error": "Meeting already in progress"}

	# 5. Corpse exists on server
	if not active_corpses.has(corpse_id):
		return {"success": false, "error": "Corpse #%d does not exist" % corpse_id}

	var corpse_data: Dictionary = active_corpses[corpse_id]

	# 6. Corpse has not already been reported
	if bool(corpse_data.get("is_reported", false)):
		return {"success": false, "error": "Corpse #%d has already been reported" % corpse_id}

	# 7. Reporting player is within authoritative report range
	var reporter_pos = get_player_authoritative_position(reporter_peer_id)
	var corpse_pos: Vector2 = corpse_data.get("position", Vector2.ZERO)
	if reporter_pos != Vector2.ZERO and corpse_pos != Vector2.ZERO:
		var dist = reporter_pos.distance_to(corpse_pos)
		if dist > REPORT_RANGE:
			return {"success": false, "error": "Reporter out of range (%.1fpx > %.1fpx)" % [dist, REPORT_RANGE]}

	# Execute authoritative report
	corpse_data["is_reported"] = true

	print("[SERVER] Player %d (Slot %d) REPORTED body #%d (Victim: %s)!" % [
		reporter_peer_id, reporter.player_slot, corpse_id, str(corpse_data.get("victim_name", ""))
	])

	corpse_reported_on_server.emit(corpse_id, reporter_peer_id)

	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_corpse_reported"):
		net_mgr.broadcast_corpse_reported(corpse_id, reporter_peer_id, connected_players.keys())

	# Initiate emergency meeting via existing MeetingManager
	if meeting_manager != null:
		meeting_manager.request_call_meeting(reporter_peer_id, current_game_state, connected_players, true)

	return {"success": true, "corpse_id": corpse_id, "reporter_peer_id": reporter_peer_id}

func _check_crew_elimination_win_condition() -> void:
	var alive_crew: int = 0
	var alive_impostor: int = 0
	for p: PlayerConnectionData in connected_players.values():
		if p.is_alive and not p.is_eliminated:
			if p.role == NetworkConfig.PlayerRole.IMPOSTOR or (blackout_manager != null and p.peer_id == blackout_manager.impostor_peer_id):
				alive_impostor += 1
			else:
				alive_crew += 1

	if alive_crew == 0 and alive_impostor > 0 and connected_players.size() > 1:
		print("[SERVER] All Crew members eliminated! Impostor victory!")
		if meltdown_manager != null:
			meltdown_manager._trigger_game_over(NetworkConfig.PlayerRole.IMPOSTOR, MeltdownConfig.GameOverReason.CREW_ELIMINATED)


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
	if round_manager != null and (round_manager.is_playing() or round_manager.is_ending()):
		round_manager.transition_to(RoundManager.RoundState.RESULTS)
	_transition_game_state(NetworkConfig.GameState.GAME_OVER)
	match_concluded.emit(winner_role, reason, result_data)
	var net_mgr = get_parent()
	if net_mgr != null and net_mgr.has_method("broadcast_game_over"):
		net_mgr.broadcast_game_over(winner_role, reason, result_data, connected_players.keys())

func _on_blackout_ended() -> void:
	if sabotage_manager != null and sabotage_manager.is_sabotage_active():
		sabotage_manager.resolve_sabotage("Authoritative Blackout duration ended.")
		var net_mgr_sab = get_parent()
		if net_mgr_sab != null and net_mgr_sab.has_method("broadcast_sabotage_state"):
			net_mgr_sab.broadcast_sabotage_state(SabotageManager.SabotageType.POWER_BLACKOUT, SabotageManager.SabotageState.RESOLVED, 0.0, connected_players.keys())

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

	if round_manager != null and round_manager.is_starting() and connected_players.size() < NetworkConfig.MAX_PLAYERS:
		round_manager.cancel_start("Player disconnected during countdown.")

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
