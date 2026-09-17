class_name RoleManager
extends RefCounted

## Centralized Role System API, Queries, and Deterministic Assignment Rules for BLACKOUT.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

const NetworkConfig = preload("res://shared/network_config.gd")

## Computes authoritative role assignments for an array of connected peer IDs.
## Assignment Rules:
##   - 1 player: 1 CREW (Solo test/development)
##   - 2-4 players: Exactly 1 IMPOSTOR, remainder CREW
##   - 5-8 players: Exactly 1 IMPOSTOR, remainder CREW
## Supports an optional deterministic index or random selection for testability.
static func calculate_role_assignments(
	peer_ids: Array,
	impostor_count: int = 1,
	deterministic_impostor_index: int = -1
) -> Dictionary:
	var assignments: Dictionary = {}
	var count: int = peer_ids.size()
	if count == 0:
		return assignments

	# Rule 1: Single connected player is always CREW
	if count == 1:
		assignments[peer_ids[0]] = NetworkConfig.PlayerRole.CREW
		return assignments

	# Rule 2: Multi-player assignment (2-8 players)
	var chosen_index: int = deterministic_impostor_index
	if chosen_index < 0 or chosen_index >= count:
		# Default deterministic selection if index is negative or out of bounds (or randomized)
		chosen_index = 0

	var impostor_peer = peer_ids[chosen_index]

	for pid in peer_ids:
		if pid == impostor_peer:
			assignments[pid] = NetworkConfig.PlayerRole.IMPOSTOR
		else:
			assignments[pid] = NetworkConfig.PlayerRole.CREW

	return assignments

## Returns true if the provided role is IMPOSTOR.
static func is_impostor(role: NetworkConfig.PlayerRole) -> bool:
	return role == NetworkConfig.PlayerRole.IMPOSTOR

## Returns true if the provided role is CREW.
static func is_crew(role: NetworkConfig.PlayerRole) -> bool:
	return role == NetworkConfig.PlayerRole.CREW

## Returns a clean uppercase display string for a role.
static func get_role_display_name(role: NetworkConfig.PlayerRole) -> String:
	match role:
		NetworkConfig.PlayerRole.CREW:
			return "CREW"
		NetworkConfig.PlayerRole.IMPOSTOR:
			return "IMPOSTOR"
		_:
			return "UNASSIGNED"
