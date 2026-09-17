class_name MeltdownManager
extends RefCounted

## Server-authoritative Meltdown Manager for BLACKOUT (Step 10).
## Controls the 5-minute (300.0s) emergency phase, emergency subsystem completions,
## Crew victory (all 3 mandatory systems restored), Impostor victory (timer expiration),
## and transition to GAME_OVER.

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")

signal meltdown_started(duration: float, impostor_alive: bool)
signal meltdown_tick(remaining_time: float)
signal emergency_system_completed(system_id: String, completed_systems: Array)
signal game_over_triggered(winner_role: NetworkConfig.PlayerRole, reason: MeltdownConfig.GameOverReason, result_data: Dictionary)

var is_meltdown_active: bool = false
var duration: float = MeltdownConfig.DEFAULT_MELTDOWN_DURATION_SEC
var remaining_time: float = 0.0
var start_timestamp: float = 0.0
var impostor_alive_at_meltdown: bool = true

## System completion tracking: system_id (String) -> bool
var emergency_systems: Dictionary = {}

var is_game_over: bool = false
var winner_role: NetworkConfig.PlayerRole = NetworkConfig.PlayerRole.NONE
var victory_reason: MeltdownConfig.GameOverReason = MeltdownConfig.GameOverReason.NONE
var last_game_over_result: Dictionary = {}

func clear() -> void:
	is_meltdown_active = false
	duration = MeltdownConfig.DEFAULT_MELTDOWN_DURATION_SEC
	remaining_time = 0.0
	start_timestamp = 0.0
	impostor_alive_at_meltdown = true
	emergency_systems.clear()
	is_game_over = false
	winner_role = NetworkConfig.PlayerRole.NONE
	victory_reason = MeltdownConfig.GameOverReason.NONE
	last_game_over_result.clear()

func setup(p_duration: float = MeltdownConfig.DEFAULT_MELTDOWN_DURATION_SEC) -> void:
	clear()
	duration = p_duration

func start_meltdown(is_impostor_alive: bool) -> void:
	is_meltdown_active = true
	is_game_over = false
	remaining_time = duration
	start_timestamp = Time.get_unix_time_from_system()
	impostor_alive_at_meltdown = is_impostor_alive
	winner_role = NetworkConfig.PlayerRole.NONE
	victory_reason = MeltdownConfig.GameOverReason.NONE
	last_game_over_result.clear()

	emergency_systems.clear()
	for sys_id in MeltdownConfig.ALL_EMERGENCY_SYSTEMS:
		emergency_systems[sys_id] = false

	print("[MeltdownManager] MELTDOWN STARTED! Duration: %.1f seconds (Impostor Alive: %s)." % [
		duration, str(is_impostor_alive)
	])
	print("[MeltdownManager] Mandatory Emergency Systems initialized: %s." % str(MeltdownConfig.ALL_EMERGENCY_SYSTEMS))

	meltdown_started.emit(duration, is_impostor_alive)

## Authoritative server timing tick driven by server _process().
func tick(delta: float) -> void:
	if not is_meltdown_active or is_game_over:
		return

	remaining_time -= delta
	meltdown_tick.emit(max(0.0, remaining_time))

	if remaining_time <= 0.0:
		remaining_time = 0.0
		print("[MeltdownManager] MELTDOWN TIMER EXPIRED (0.0s remaining)! Station core overwhelmed.")
		_trigger_game_over(NetworkConfig.PlayerRole.IMPOSTOR, MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED)

func can_complete_emergency_system(
	peer_id: int,
	system_id: String,
	current_state: NetworkConfig.GameState,
	active_players: Dictionary
) -> Dictionary:
	if is_game_over or not is_meltdown_active:
		var msg = "Emergency system completion rejected: Meltdown is not active or match has ended."
		return {"allowed": false, "reason": msg}

	if current_state != NetworkConfig.GameState.MELTDOWN:
		var msg = "Emergency system completion rejected: match is in %s (Expected: MELTDOWN)." % NetworkConfig.get_game_state_name(current_state)
		return {"allowed": false, "reason": msg}

	if remaining_time <= 0.0:
		var msg = "Emergency system completion rejected: Meltdown timer has expired."
		return {"allowed": false, "reason": msg}

	if not active_players.has(peer_id):
		var msg = "Emergency system completion rejected: player %d is not a connected peer." % peer_id
		return {"allowed": false, "reason": msg}

	var player_data: PlayerConnectionData = active_players[peer_id]
	if not player_data.is_alive or player_data.is_eliminated:
		var msg = "Emergency system completion rejected: player %d is eliminated/inactive." % peer_id
		return {"allowed": false, "reason": msg}

	if player_data.role != NetworkConfig.PlayerRole.CREW:
		var msg = "Emergency system completion rejected: player %d has role %s (Only Crew can complete emergency systems)." % [
			peer_id, NetworkConfig.get_role_name(player_data.role)
		]
		return {"allowed": false, "reason": msg}

	if not MeltdownConfig.is_valid_emergency_system(system_id):
		var msg = "Emergency system completion rejected: unknown emergency system '%s'." % system_id
		return {"allowed": false, "reason": msg}

	if emergency_systems.get(system_id, false):
		var msg = "Emergency system completion rejected: system '%s' is already completed." % system_id
		return {"allowed": false, "reason": msg}

	return {"allowed": true, "reason": ""}

func complete_emergency_system(
	peer_id: int,
	system_id: String,
	current_state: NetworkConfig.GameState,
	active_players: Dictionary
) -> Dictionary:
	var check = can_complete_emergency_system(peer_id, system_id, current_state, active_players)
	if not check.allowed:
		push_warning("[MeltdownManager] %s" % check.reason)
		return {"success": false, "error": check.reason}

	emergency_systems[system_id] = true
	var completed_list = get_completed_systems()
	var total_required = MeltdownConfig.ALL_EMERGENCY_SYSTEMS.size()

	print("[MeltdownManager] Emergency system '%s' (%s) COMPLETED by Crew peer %d. Progress: %d/%d." % [
		MeltdownConfig.get_emergency_system_name(system_id),
		system_id,
		peer_id,
		completed_list.size(),
		total_required
	])

	emergency_system_completed.emit(system_id, completed_list)

	# Check Crew victory: All 3 systems must be complete!
	if are_all_emergency_systems_completed():
		print("[MeltdownManager] ALL %d EMERGENCY SYSTEMS RESTORED! Station stabilized." % total_required)
		_trigger_game_over(NetworkConfig.PlayerRole.CREW, MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE)

	return {
		"success": true,
		"system_id": system_id,
		"completed_systems": completed_list,
		"total_completed": completed_list.size(),
		"total_required": total_required,
		"is_crew_win": are_all_emergency_systems_completed()
	}

func are_all_emergency_systems_completed() -> bool:
	for sys_id in MeltdownConfig.ALL_EMERGENCY_SYSTEMS:
		if not emergency_systems.get(sys_id, false):
			return false
	return true

func get_completed_systems() -> Array:
	var result: Array = []
	for sys_id in MeltdownConfig.ALL_EMERGENCY_SYSTEMS:
		if emergency_systems.get(sys_id, false):
			result.append(sys_id)
	return result

func get_completed_count() -> int:
	return get_completed_systems().size()

func _trigger_game_over(p_winner: NetworkConfig.PlayerRole, p_reason: MeltdownConfig.GameOverReason) -> void:
	is_meltdown_active = false
	is_game_over = true
	winner_role = p_winner
	victory_reason = p_reason

	last_game_over_result = {
		"winner_role": p_winner,
		"winner_role_name": NetworkConfig.get_role_name(p_winner),
		"reason": p_reason,
		"reason_name": MeltdownConfig.get_game_over_reason_name(p_reason),
		"completed_systems": get_completed_systems(),
		"remaining_time": max(0.0, remaining_time),
		"impostor_was_alive": impostor_alive_at_meltdown
	}

	print("[MeltdownManager] *** GAME OVER *** Winner: %s | Reason: %s | Remaining Time: %.1fs" % [
		NetworkConfig.get_role_name(p_winner),
		MeltdownConfig.get_game_over_reason_name(p_reason),
		remaining_time
	])

	game_over_triggered.emit(p_winner, p_reason, last_game_over_result)

func handle_player_disconnect(peer_id: int) -> void:
	# Disconnecting players do not erase or alter completed emergency subsystems.
	pass
