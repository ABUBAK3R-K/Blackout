class_name WinConditionManager
extends RefCounted

## Server-authoritative Win Condition Manager for BLACKOUT (Member 2 Deliverable).
## Evaluates match victory conditions, formats end-of-match summaries,
## and enforces post-game lockdown contracts.

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")

signal match_finalized(winner_role: NetworkConfig.PlayerRole, reason: MeltdownConfig.GameOverReason, match_summary: Dictionary)

var is_match_concluded: bool = false
var winner: NetworkConfig.PlayerRole = NetworkConfig.PlayerRole.NONE
var victory_reason: MeltdownConfig.GameOverReason = MeltdownConfig.GameOverReason.NONE
var match_summary: Dictionary = {}

func clear() -> void:
	is_match_concluded = false
	winner = NetworkConfig.PlayerRole.NONE
	victory_reason = MeltdownConfig.GameOverReason.NONE
	match_summary.clear()

## Evaluates whether Crew has achieved victory by restoring all 3 emergency systems.
func check_crew_victory(completed_systems: Array) -> bool:
	if completed_systems.size() < MeltdownConfig.MANDATORY_EMERGENCY_SYSTEMS_COUNT:
		return false
	for sys_id in MeltdownConfig.ALL_EMERGENCY_SYSTEMS:
		if not completed_systems.has(sys_id):
			return false
	return true

## Evaluates whether Impostor has achieved victory by running down the Meltdown timer.
func check_impostor_victory(remaining_meltdown_time: float) -> bool:
	return remaining_meltdown_time <= 0.0

## Assembles the final authoritative match summary for all clients.
func assemble_match_summary(
	p_winner: NetworkConfig.PlayerRole,
	p_reason: MeltdownConfig.GameOverReason,
	completed_systems: Array,
	remaining_time: float,
	impostor_was_alive: bool,
	connected_players: Dictionary = {}
) -> Dictionary:
	is_match_concluded = true
	winner = p_winner
	victory_reason = p_reason

	var player_roster: Array = []
	for pid in connected_players.keys():
		var p: PlayerConnectionData = connected_players[pid]
		player_roster.append({
			"peer_id": pid,
			"player_slot": p.player_slot,
			"role": p.role,
			"role_name": NetworkConfig.get_role_name(p.role),
			"is_alive": p.is_alive,
			"is_eliminated": p.is_eliminated
		})

	match_summary = {
		"winner_role": p_winner,
		"winner_role_name": NetworkConfig.get_role_name(p_winner),
		"reason": p_reason,
		"reason_name": MeltdownConfig.get_game_over_reason_name(p_reason),
		"completed_emergency_systems": completed_systems.duplicate(),
		"remaining_meltdown_time": max(0.0, remaining_time),
		"impostor_was_alive": impostor_was_alive,
		"finalized_at": Time.get_unix_time_from_system(),
		"player_roster": player_roster
	}

	print("[WinConditionManager] Match Finalized — Winner: %s | Reason: %s" % [
		NetworkConfig.get_role_name(p_winner),
		MeltdownConfig.get_game_over_reason_name(p_reason)
	])

	match_finalized.emit(p_winner, p_reason, match_summary)
	return match_summary
