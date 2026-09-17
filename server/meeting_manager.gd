class_name MeetingManager
extends RefCounted

## Server-authoritative Meeting Coordinator for BLACKOUT.
## Coordinates the discussion phase, transitions to voting, manages timers, and triggers vote resolution.

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")
const VotingManager = preload("res://server/voting_manager.gd")

signal meeting_started(caller_peer_id: int, discussion_duration: float)
signal discussion_tick(remaining_sec: float)
signal voting_phase_started(voting_duration: float)
signal voting_tick(remaining_sec: float)
signal meeting_completed(result: Dictionary)

var is_meeting_active: bool = false
var caller_peer_id: int = 0
var current_phase: MeetingConfig.MeetingPhase = MeetingConfig.MeetingPhase.NONE

var discussion_duration: float = MeetingConfig.DEFAULT_DISCUSSION_DURATION_SEC
var voting_duration: float = MeetingConfig.DEFAULT_VOTING_DURATION_SEC

var discussion_remaining: float = 0.0
var voting_remaining: float = 0.0

func clear() -> void:
	is_meeting_active = false
	caller_peer_id = 0
	current_phase = MeetingConfig.MeetingPhase.NONE
	discussion_remaining = 0.0
	voting_remaining = 0.0
	discussion_duration = MeetingConfig.DEFAULT_DISCUSSION_DURATION_SEC
	voting_duration = MeetingConfig.DEFAULT_VOTING_DURATION_SEC

func setup(
	p_discussion: float = MeetingConfig.DEFAULT_DISCUSSION_DURATION_SEC,
	p_voting: float = MeetingConfig.DEFAULT_VOTING_DURATION_SEC
) -> void:
	clear()
	discussion_duration = p_discussion
	voting_duration = p_voting

func can_call_meeting(
	peer_id: int,
	current_state: NetworkConfig.GameState,
	active_players: Dictionary
) -> Dictionary:
	if current_state != NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION:
		var msg = "Meeting call rejected: current match state is %s (Expected: POST_BLACKOUT_INVESTIGATION)." % NetworkConfig.get_game_state_name(current_state)
		return {"allowed": false, "reason": msg}

	if is_meeting_active:
		var msg = "Meeting call rejected: a meeting is already in progress."
		return {"allowed": false, "reason": msg}

	if not active_players.has(peer_id):
		var msg = "Meeting call rejected: caller %d is not a connected player." % peer_id
		return {"allowed": false, "reason": msg}

	var caller_data: PlayerConnectionData = active_players[peer_id]
	if not caller_data.is_alive or caller_data.is_eliminated:
		var msg = "Meeting call rejected: caller %d is eliminated/inactive." % peer_id
		return {"allowed": false, "reason": msg}

	return {"allowed": true, "reason": ""}

func request_call_meeting(
	peer_id: int,
	current_state: NetworkConfig.GameState,
	active_players: Dictionary
) -> Dictionary:
	var check = can_call_meeting(peer_id, current_state, active_players)
	if not check.allowed:
		push_warning("[MeetingManager] %s" % check.reason)
		return {"success": false, "error": check.reason}

	is_meeting_active = true
	caller_peer_id = peer_id
	current_phase = MeetingConfig.MeetingPhase.DISCUSSION
	discussion_remaining = discussion_duration

	print("[MeetingManager] Meeting called by Player %d. Starting discussion phase (%.1fs)..." % [
		peer_id, discussion_duration
	])

	meeting_started.emit(peer_id, discussion_duration)
	return {"success": true, "caller_peer_id": peer_id, "discussion_duration": discussion_duration}

## Authoritative timer tick processing for discussion and voting.
func tick(
	delta: float,
	active_players: Dictionary,
	impostor_peer_id: int,
	voting_manager: VotingManager
) -> void:
	if not is_meeting_active:
		return

	if current_phase == MeetingConfig.MeetingPhase.DISCUSSION:
		discussion_remaining -= delta
		discussion_tick.emit(max(0.0, discussion_remaining))

		if discussion_remaining <= 0.0:
			_start_voting_phase(voting_manager)

	elif current_phase == MeetingConfig.MeetingPhase.VOTING:
		voting_remaining -= delta
		voting_tick.emit(max(0.0, voting_remaining))

		var all_voted: bool = voting_manager != null and voting_manager.have_all_active_voted(active_players)
		if voting_remaining <= 0.0 or all_voted:
			_resolve_meeting_and_voting(active_players, impostor_peer_id, voting_manager)

func _start_voting_phase(voting_manager: VotingManager) -> void:
	current_phase = MeetingConfig.MeetingPhase.VOTING
	voting_remaining = voting_duration
	if voting_manager != null:
		voting_manager.start_voting_session()

	print("[MeetingManager] Discussion concluded. Transitioning to VOTING phase (%.1fs)..." % voting_duration)
	voting_phase_started.emit(voting_duration)

func _resolve_meeting_and_voting(
	active_players: Dictionary,
	impostor_peer_id: int,
	voting_manager: VotingManager
) -> void:
	current_phase = MeetingConfig.MeetingPhase.RESULTS
	is_meeting_active = false

	var result: Dictionary = {}
	if voting_manager != null:
		result = voting_manager.calculate_results(active_players, impostor_peer_id)

	print("[MeetingManager] Meeting and Voting resolved. Result: %s." % str(result))
	meeting_completed.emit(result)

func handle_player_disconnect(peer_id: int) -> void:
	if peer_id == caller_peer_id:
		print("[MeetingManager] Meeting caller (Peer %d) disconnected. Meeting continues." % peer_id)
