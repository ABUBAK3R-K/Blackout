extends Node

## Central NetworkManager Autoload for BLACKOUT.
## Coordinates between authoritative server and client networking layers.
## Registered in project.godot as Autoload: "/root/NetworkManager"

const NetworkConfig = preload("res://shared/network_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

enum NetworkMode {
	OFFLINE,
	SERVER,
	CLIENT
}

var current_mode: NetworkMode = NetworkMode.OFFLINE

var server: ServerNetworkManager = null
var client: ClientNetworkManager = null

func _ready() -> void:
	server = ServerNetworkManager.new()
	server.name = "Server"
	add_child(server)

	client = ClientNetworkManager.new()
	client.name = "Client"
	add_child(client)

	print("[NetworkManager] Initialized in OFFLINE mode.")

func start_server(port: int = NetworkConfig.DEFAULT_PORT, max_players: int = NetworkConfig.MAX_PLAYERS) -> Error:
	if current_mode != NetworkMode.OFFLINE:
		stop_network()

	var err: Error = server.start_server(port, max_players)
	if err == OK:
		current_mode = NetworkMode.SERVER
	return err

func start_host(port: int = NetworkConfig.DEFAULT_PORT, max_players: int = NetworkConfig.MAX_PLAYERS) -> Error:
	return start_server(port, max_players)

func connect_client(host: String = NetworkConfig.DEFAULT_HOST, port: int = NetworkConfig.DEFAULT_PORT) -> Error:
	if current_mode != NetworkMode.OFFLINE:
		stop_network()

	var err: Error = client.connect_to_server(host, port)
	if err == OK:
		current_mode = NetworkMode.CLIENT
	return err

func start_client(host: String = NetworkConfig.DEFAULT_HOST, port: int = NetworkConfig.DEFAULT_PORT) -> Error:
	return connect_client(host, port)

func stop_network() -> void:
	if current_mode == NetworkMode.SERVER:
		server.stop_server()
	elif current_mode == NetworkMode.CLIENT:
		client.disconnect_from_server()
	current_mode = NetworkMode.OFFLINE

func is_server() -> bool:
	return current_mode == NetworkMode.SERVER and server.is_server_active()

func is_client() -> bool:
	return current_mode == NetworkMode.CLIENT and client.is_connected_to_server()

func get_game_state() -> NetworkConfig.GameState:
	if is_server():
		return server.current_game_state
	elif is_client():
		return client.current_game_state
	return NetworkConfig.GameState.LOBBY

func get_player_role() -> NetworkConfig.PlayerRole:
	if is_client():
		return client.assigned_role
	return NetworkConfig.PlayerRole.NONE

func set_ready(ready_status: bool) -> void:
	if is_client():
		client.set_ready(ready_status)
	elif is_server():
		push_warning("[NetworkManager] Dedicated server instance cannot set client ready state directly.")

func complete_task(task_id: String) -> void:
	if is_client():
		client.request_complete_task(task_id)
	elif is_server():
		push_warning("[NetworkManager] Dedicated server instance cannot complete tasks directly as a client.")

func activate_blackout() -> void:
	if is_client():
		client.request_activate_blackout()
	elif is_server():
		push_warning("[NetworkManager] Dedicated server instance cannot initiate Blackout directly without Impostor client request.")

func recover_system(system_id: String) -> void:
	if is_client():
		client.request_recover_system(system_id)
	elif is_server():
		push_warning("[NetworkManager] Dedicated server instance cannot recover systems directly as a client.")

func complete_impostor_objective(objective_id: String) -> void:
	if is_client():
		client.request_complete_impostor_objective(objective_id)
	elif is_server():
		push_warning("[NetworkManager] Dedicated server instance cannot complete Impostor objectives directly as a client.")

func call_meeting() -> void:
	if is_client():
		client.request_call_meeting()
	elif is_server():
		push_warning("[NetworkManager] Dedicated server instance cannot call meetings directly without client request.")

func cast_vote(target_peer_id: int) -> void:
	if is_client():
		client.request_cast_vote(target_peer_id)
	elif is_server():
		push_warning("[NetworkManager] Dedicated server instance cannot cast votes directly as a client.")

func complete_emergency_system(system_id: String) -> void:
	if is_client():
		client.request_complete_emergency_system(system_id)
	elif is_server():
		push_warning("[NetworkManager] Dedicated server instance cannot complete emergency systems directly as a client.")

# --- Client-to-Server RPC Dispatch Helpers ---

func request_set_ready(ready_status: bool) -> void:
	rpc_request_set_ready.rpc_id(1, ready_status)

func request_complete_task(task_id: String) -> void:
	rpc_request_complete_task.rpc_id(1, task_id)

func request_activate_blackout() -> void:
	rpc_request_activate_blackout.rpc_id(1)

func request_recover_system(system_id: String) -> void:
	rpc_request_recover_system.rpc_id(1, system_id)

func request_complete_impostor_objective(objective_id: String) -> void:
	rpc_request_complete_impostor_objective.rpc_id(1, objective_id)

func request_call_meeting() -> void:
	rpc_request_call_meeting.rpc_id(1)

func request_cast_vote(target_peer_id: int) -> void:
	rpc_request_cast_vote.rpc_id(1, target_peer_id)

func request_complete_emergency_system(system_id: String) -> void:
	rpc_request_complete_emergency_system.rpc_id(1, system_id)

# --- Server-side RPC Dispatch Helpers ---

func send_player_assignment(peer_id: int, slot: int, total_players: int) -> void:
	rpc_receive_player_assignment.rpc_id(peer_id, peer_id, slot, total_players)

func send_connection_rejection(peer_id: int, reason: String) -> void:
	rpc_connection_rejected.rpc_id(peer_id, reason)

func send_private_role(peer_id: int, role: int) -> void:
	rpc_receive_private_role.rpc_id(peer_id, role)

func send_private_task_list(peer_id: int, tasks_data: Array) -> void:
	rpc_receive_task_list.rpc_id(peer_id, tasks_data)

func send_task_update(peer_id: int, task_id: String, is_completed: bool) -> void:
	rpc_receive_task_update.rpc_id(peer_id, task_id, is_completed)

func notify_blackout_unlocked(peer_id: int) -> void:
	rpc_notify_blackout_unlocked.rpc_id(peer_id)

func broadcast_blackout_countdown(duration: float, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_blackout_countdown.rpc_id(pid, duration)

func broadcast_blackout_countdown_cancelled(reason: String, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_blackout_countdown_cancelled.rpc_id(pid, reason)

func broadcast_blackout_started(duration: float, recipients: Array) -> void:
	for pid in recipients:
		rpc_notify_blackout_started.rpc_id(pid, duration)

func broadcast_blackout_ended(recipients: Array) -> void:
	for pid in recipients:
		rpc_notify_blackout_ended.rpc_id(pid)

func broadcast_recovery_initialization(required_count: int, systems_data: Array, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_recovery_initialization.rpc_id(pid, required_count, systems_data)

func broadcast_recovery_update(system_id: String, is_completed: bool, completed_count: int, required_count: int, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_recovery_update.rpc_id(pid, system_id, is_completed, completed_count, required_count)

func send_private_objective_list(peer_id: int, objectives_data: Array) -> void:
	rpc_receive_private_objective_list.rpc_id(peer_id, objectives_data)

func send_private_objective_update(peer_id: int, objective_id: String, is_completed: bool) -> void:
	rpc_receive_private_objective_update.rpc_id(peer_id, objective_id, is_completed)

func broadcast_lobby_sync(state: int, player_count: int, ready_count: int, players_info: Array, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_lobby_state.rpc_id(pid, state, player_count, ready_count, players_info)

func broadcast_game_state(new_state: int, recipients: Array) -> void:
	for pid in recipients:
		rpc_game_state_changed.rpc_id(pid, new_state)

func broadcast_investigation_started(recipients: Array) -> void:
	for pid in recipients:
		rpc_notify_investigation_started.rpc_id(pid)

func broadcast_investigation_evidence(evidence_list: Array, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_investigation_evidence.rpc_id(pid, evidence_list)

func broadcast_meeting_started(caller_peer_id: int, discussion_duration: float, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_meeting_started.rpc_id(pid, caller_peer_id, discussion_duration)

func broadcast_voting_started(voting_duration: float, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_voting_started.rpc_id(pid, voting_duration)

func broadcast_player_voted(voter_peer_id: int, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_player_voted.rpc_id(pid, voter_peer_id)

func broadcast_vote_result(result_data: Dictionary, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_vote_result.rpc_id(pid, result_data)

func broadcast_meltdown_started(duration: float, impostor_alive: bool, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_meltdown_started.rpc_id(pid, duration, impostor_alive)

func broadcast_emergency_system_completed(system_id: String, completed_systems: Array, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_emergency_system_completed.rpc_id(pid, system_id, completed_systems)

func broadcast_game_over(winner_role: int, reason: int, result_data: Dictionary, recipients: Array) -> void:
	for pid in recipients:
		rpc_sync_game_over.rpc_id(pid, winner_role, reason, result_data)

func broadcast_player_joined(peer_id: int, slot: int, recipients: Array) -> void:
	for pid in recipients:
		if pid != peer_id:
			rpc_notify_player_connected.rpc_id(pid, peer_id, slot)

func broadcast_player_left(peer_id: int, recipients: Array) -> void:
	for pid in recipients:
		rpc_notify_player_disconnected.rpc_id(pid, peer_id)

# --- Client-to-Server RPC Endpoints ---

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_set_ready(is_ready: bool) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if is_server():
		server.set_player_ready(sender_id, is_ready)
	else:
		push_warning("[NetworkManager] Received ready request on non-server node from peer %d." % sender_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_complete_task(task_id: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if is_server():
		server.process_task_completion_request(sender_id, task_id)
	else:
		push_warning("[NetworkManager] Received task completion request on non-server node from peer %d." % sender_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_activate_blackout() -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if is_server():
		server.process_blackout_activation_request(sender_id)
	else:
		push_warning("[NetworkManager] Received blackout activation request on non-server node from peer %d." % sender_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_recover_system(system_id: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if is_server():
		server.process_recovery_request(sender_id, system_id)
	else:
		push_warning("[NetworkManager] Received recovery request on non-server node from peer %d." % sender_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_complete_impostor_objective(objective_id: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if is_server():
		server.process_impostor_objective_completion_request(sender_id, objective_id)
	else:
		push_warning("[NetworkManager] Received objective completion request on non-server node from peer %d." % sender_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_call_meeting() -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if is_server():
		server.process_call_meeting_request(sender_id)
	else:
		push_warning("[NetworkManager] Received meeting call request on non-server node from peer %d." % sender_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_cast_vote(target_peer_id: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if is_server():
		server.process_cast_vote_request(sender_id, target_peer_id)
	else:
		push_warning("[NetworkManager] Received vote request on non-server node from peer %d." % sender_id)

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_complete_emergency_system(system_id: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if is_server():
		server.process_emergency_system_completion_request(sender_id, system_id)
	else:
		push_warning("[NetworkManager] Received emergency system completion request on non-server node from peer %d." % sender_id)

# --- Server-Authoritative RPC Definitions ---
# Only the authority (Server, peer ID 1) can call these remote methods.

@rpc("authority", "call_remote", "reliable")
func rpc_receive_player_assignment(assigned_id: int, slot: int, total_players: int) -> void:
	if client != null:
		client.handle_assignment(assigned_id, slot, total_players)

@rpc("authority", "call_remote", "reliable")
func rpc_connection_rejected(reason: String) -> void:
	if client != null:
		client.handle_rejection(reason)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_private_role(role: int) -> void:
	if client != null:
		client.handle_private_role_assignment(role)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_task_list(tasks_data: Array) -> void:
	if client != null:
		client.handle_private_task_list(tasks_data)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_task_update(task_id: String, is_completed: bool) -> void:
	if client != null:
		client.handle_task_update(task_id, is_completed)

@rpc("authority", "call_remote", "reliable")
func rpc_notify_blackout_unlocked() -> void:
	if client != null:
		client.handle_blackout_unlocked()

@rpc("authority", "call_remote", "reliable")
func rpc_sync_blackout_countdown(duration: float) -> void:
	if client != null:
		client.handle_blackout_countdown_started(duration)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_blackout_countdown_cancelled(reason: String) -> void:
	if client != null:
		client.handle_blackout_countdown_cancelled(reason)

@rpc("authority", "call_remote", "reliable")
func rpc_notify_blackout_started(duration: float) -> void:
	if client != null:
		client.handle_blackout_started(duration)

@rpc("authority", "call_remote", "reliable")
func rpc_notify_blackout_ended() -> void:
	if client != null:
		client.handle_blackout_ended()

@rpc("authority", "call_remote", "reliable")
func rpc_sync_recovery_initialization(required_count: int, systems_data: Array) -> void:
	if client != null:
		client.handle_recovery_initialization(required_count, systems_data)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_recovery_update(system_id: String, is_completed: bool, completed_count: int, required_count: int) -> void:
	if client != null:
		client.handle_recovery_update(system_id, is_completed, completed_count, required_count)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_private_objective_list(objectives_data: Array) -> void:
	if client != null:
		client.handle_private_objective_list(objectives_data)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_private_objective_update(objective_id: String, is_completed: bool) -> void:
	if client != null:
		client.handle_private_objective_update(objective_id, is_completed)

@rpc("authority", "call_remote", "reliable")
func rpc_notify_investigation_started() -> void:
	if client != null:
		client.handle_investigation_started()

@rpc("authority", "call_remote", "reliable")
func rpc_sync_investigation_evidence(evidence_list: Array) -> void:
	if client != null:
		client.handle_investigation_evidence(evidence_list)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_meeting_started(caller_peer_id: int, discussion_duration: float) -> void:
	if client != null:
		client.handle_meeting_started(caller_peer_id, discussion_duration)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_voting_started(voting_duration: float) -> void:
	if client != null:
		client.handle_voting_started(voting_duration)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_player_voted(voter_peer_id: int) -> void:
	if client != null:
		client.handle_player_voted(voter_peer_id)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_vote_result(result_data: Dictionary) -> void:
	if client != null:
		client.handle_vote_result(result_data)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_meltdown_started(duration: float, impostor_alive: bool) -> void:
	if client != null:
		client.handle_meltdown_started(duration, impostor_alive)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_emergency_system_completed(system_id: String, completed_systems: Array) -> void:
	if client != null:
		client.handle_emergency_system_completed(system_id, completed_systems)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_game_over(winner_role: int, reason: int, result_data: Dictionary) -> void:
	if client != null:
		client.handle_game_over(winner_role, reason, result_data)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_lobby_state(state: int, player_count: int, ready_count: int, players_info: Array) -> void:
	if client != null:
		client.handle_lobby_sync(state, player_count, ready_count, players_info)

@rpc("authority", "call_remote", "reliable")
func rpc_game_state_changed(new_state: int) -> void:
	if client != null:
		client.handle_game_state_changed(new_state)

@rpc("authority", "call_remote", "reliable")
func rpc_notify_player_connected(p_peer_id: int, p_slot: int) -> void:
	if client != null:
		client.handle_player_joined(p_peer_id, p_slot)

@rpc("authority", "call_remote", "reliable")
func rpc_notify_player_disconnected(p_peer_id: int) -> void:
	if client != null:
		client.handle_player_left(p_peer_id)
