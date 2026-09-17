class_name VotingManager
extends RefCounted

## Server-authoritative Voting Manager for BLACKOUT.
## Manages vote submission, validation, storage, and plurality resolution.

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")

signal vote_recorded(voter_peer_id: int)
signal voting_resolved(result: Dictionary)

## Storage: voter_peer_id (int) -> target_peer_id (int) (where target can be VOTE_SKIP = -1)
var votes: Dictionary = {}
var is_voting_active: bool = false
var last_result: Dictionary = {}

func clear() -> void:
	votes.clear()
	is_voting_active = false
	last_result.clear()

func start_voting_session() -> void:
	votes.clear()
	is_voting_active = true
	last_result.clear()
	print("[VotingManager] Authoritative voting session started.")

func can_cast_vote(
	voter_peer_id: int,
	target_peer_id: int,
	current_state: NetworkConfig.GameState,
	active_players: Dictionary
) -> Dictionary:
	if current_state != NetworkConfig.GameState.VOTING or not is_voting_active:
		var msg = "Vote rejected: current match state is %s (Expected: VOTING)." % NetworkConfig.get_game_state_name(current_state)
		return {"allowed": false, "reason": msg}

	if not active_players.has(voter_peer_id):
		var msg = "Vote rejected: voter %d is not a connected player." % voter_peer_id
		return {"allowed": false, "reason": msg}

	var voter_data: PlayerConnectionData = active_players[voter_peer_id]
	if not voter_data.is_alive or voter_data.is_eliminated:
		var msg = "Vote rejected: voter %d is eliminated/inactive and cannot vote." % voter_peer_id
		return {"allowed": false, "reason": msg}

	if votes.has(voter_peer_id):
		var msg = "Vote rejected: voter %d has already submitted a vote this round." % voter_peer_id
		return {"allowed": false, "reason": msg}

	# Target validation: Skip (-1) or valid active player
	if target_peer_id == MeetingConfig.VOTE_SKIP:
		return {"allowed": true, "reason": ""}

	if not active_players.has(target_peer_id):
		var msg = "Vote rejected: target %d is not a connected player." % target_peer_id
		return {"allowed": false, "reason": msg}

	var target_data: PlayerConnectionData = active_players[target_peer_id]
	if not target_data.is_alive or target_data.is_eliminated:
		var msg = "Vote rejected: target %d is already eliminated." % target_peer_id
		return {"allowed": false, "reason": msg}

	return {"allowed": true, "reason": ""}

func cast_vote(
	voter_peer_id: int,
	target_peer_id: int,
	current_state: NetworkConfig.GameState,
	active_players: Dictionary
) -> Dictionary:
	var check = can_cast_vote(voter_peer_id, target_peer_id, current_state, active_players)
	if not check.allowed:
		push_warning("[VotingManager] %s" % check.reason)
		return {"success": false, "error": check.reason}

	votes[voter_peer_id] = target_peer_id
	var target_name = "SKIP" if target_peer_id == MeetingConfig.VOTE_SKIP else "Player %d" % target_peer_id
	print("[VotingManager] Valid vote cast by Player %d (Target: %s). Total votes: %d." % [
		voter_peer_id, target_name, votes.size()
	])

	vote_recorded.emit(voter_peer_id)
	return {"success": true, "voter_peer_id": voter_peer_id, "total_votes": votes.size()}

func have_all_active_voted(active_players: Dictionary) -> bool:
	var eligible_count: int = 0
	for p: PlayerConnectionData in active_players.values():
		if p.is_alive and not p.is_eliminated:
			eligible_count += 1

	return votes.size() >= eligible_count and eligible_count > 0

## Calculates the plurality voting result deterministically.
## Rule:
## - The candidate with the highest vote count is selected.
## - If SKIP has the plurality, no one is eliminated.
## - If there is a tie for the top vote count, no one is eliminated.
## - If a single player has the top vote count, that player is eliminated.
func calculate_results(active_players: Dictionary, impostor_peer_id: int) -> Dictionary:
	is_voting_active = false
	var votes_per_target: Dictionary = {} # target_peer_id (int) -> count (int)
	var skip_votes: int = 0
	var total_votes: int = votes.size()

	for voter_id in votes.keys():
		var target_id = votes[voter_id]
		if target_id == MeetingConfig.VOTE_SKIP:
			skip_votes += 1
		else:
			votes_per_target[target_id] = votes_per_target.get(target_id, 0) + 1

	# Determine plurality
	var highest_votes: int = skip_votes
	var top_candidates: Array = []
	var skip_is_top: bool = false

	if skip_votes > 0:
		skip_is_top = true

	for target_id in votes_per_target.keys():
		var count: int = votes_per_target[target_id]
		if count > highest_votes:
			highest_votes = count
			top_candidates = [target_id]
			skip_is_top = false
		elif count == highest_votes and count > 0:
			if skip_is_top:
				top_candidates.append(target_id)
			else:
				top_candidates.append(target_id)

	var eliminated_peer_id: int = 0
	var is_tie: bool = false
	var is_skip: bool = false
	var was_impostor: bool = false

	if highest_votes == 0 or total_votes == 0:
		# No votes cast at all
		is_skip = true
	elif skip_is_top and top_candidates.is_empty():
		# Skip won outright
		is_skip = true
	elif top_candidates.size() > 1 or (skip_is_top and not top_candidates.is_empty()):
		# Tie condition (either multiple players tied, or a player tied with Skip)
		is_tie = true
	elif top_candidates.size() == 1:
		# Single player plurality
		eliminated_peer_id = top_candidates[0]
		was_impostor = (eliminated_peer_id == impostor_peer_id)

	last_result = {
		"eliminated_peer_id": eliminated_peer_id,
		"was_impostor": was_impostor,
		"is_tie": is_tie,
		"is_skip": is_skip,
		"votes_per_target": votes_per_target,
		"skip_count": skip_votes,
		"total_votes_cast": total_votes
	}

	print("[VotingManager] Voting Results — Total Votes: %d (Skip: %d) | Eliminated: %d | Was Impostor: %s | Tie: %s | Skip Plurality: %s" % [
		total_votes, skip_votes, eliminated_peer_id, was_impostor, is_tie, is_skip
	])

	voting_resolved.emit(last_result)
	return last_result

func handle_player_disconnect(peer_id: int) -> void:
	# Existing votes from disconnected players remain valid in the tally.
	pass
