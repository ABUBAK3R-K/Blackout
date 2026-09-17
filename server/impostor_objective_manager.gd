class_name ImpostorObjectiveManager
extends RefCounted

## Server-authoritative manager for Impostor secret Blackout objectives during BLACKOUT_ACTIVE.

const NetworkConfig = preload("res://shared/network_config.gd")
const BlackoutObjectiveConfig = preload("res://shared/blackout_objective_config.gd")
const BlackoutObjectiveDefinition = preload("res://shared/blackout_objective_definition.gd")

signal objectives_assigned(impostor_peer_id: int, objectives_data: Array)
signal objective_completed(peer_id: int, objective_id: String)

var impostor_peer_id: int = 0
var assigned_objectives: Dictionary = {} # objective_id (String) -> BlackoutObjectiveDefinition
var objective_count_limit: int = BlackoutObjectiveConfig.DEFAULT_IMPOSTOR_OBJECTIVE_COUNT

func clear() -> void:
	impostor_peer_id = 0
	assigned_objectives.clear()
	objective_count_limit = BlackoutObjectiveConfig.DEFAULT_IMPOSTOR_OBJECTIVE_COUNT

func setup(p_limit: int = BlackoutObjectiveConfig.DEFAULT_IMPOSTOR_OBJECTIVE_COUNT) -> void:
	clear()
	objective_count_limit = p_limit

func assign_objectives(
	p_impostor_peer: int,
	custom_catalog: Array = [],
	p_count: int = -1
) -> Array:
	clear()
	impostor_peer_id = p_impostor_peer
	var count: int = p_count if p_count > 0 else objective_count_limit

	var catalog: Array = custom_catalog if custom_catalog.size() > 0 else BlackoutObjectiveConfig.OBJECTIVE_CATALOG
	var shuffled_catalog = catalog.duplicate()
	shuffled_catalog.shuffle()

	var limit: int = min(shuffled_catalog.size(), count)
	for i in range(limit):
		var item: Dictionary = shuffled_catalog[i]
		var obj_id: String = str(item.get("objective_id", ""))
		var display_name: String = str(item.get("display_name", ""))
		var category: String = str(item.get("category", "sabotage"))
		var location_id: String = str(item.get("location_id", ""))
		var evidence_flag_id: String = str(item.get("evidence_flag_id", ""))

		var obj = BlackoutObjectiveDefinition.new(
			obj_id,
			display_name,
			category,
			location_id,
			evidence_flag_id,
			impostor_peer_id
		)
		assigned_objectives[obj_id] = obj

	print("[ImpostorObjectiveManager] Assigned %d secret objectives to Impostor (Peer %d)." % [
		assigned_objectives.size(), impostor_peer_id
	])

	var serialized_list: Array = get_assigned_objectives_serialized()
	objectives_assigned.emit(impostor_peer_id, serialized_list)
	return serialized_list

func get_objective(objective_id: String) -> BlackoutObjectiveDefinition:
	return assigned_objectives.get(objective_id, null)

func get_assigned_objectives_serialized() -> Array:
	var list: Array = []
	for obj: BlackoutObjectiveDefinition in assigned_objectives.values():
		list.append(obj.to_dict())
	return list

func get_completed_objectives_count() -> int:
	var count: int = 0
	for obj: BlackoutObjectiveDefinition in assigned_objectives.values():
		if obj.is_completed:
			count += 1
	return count

func can_complete_objective(
	peer_id: int,
	objective_id: String,
	current_state: NetworkConfig.GameState,
	is_impostor: bool
) -> Dictionary:
	if current_state != NetworkConfig.GameState.BLACKOUT_ACTIVE:
		var msg = "Objective completion rejected: current match state is %s (Expected: BLACKOUT_ACTIVE)." % NetworkConfig.get_game_state_name(current_state)
		return {"allowed": false, "reason": msg}

	if not is_impostor or peer_id != impostor_peer_id:
		var msg = "Objective completion rejected: player %d is not the authorized Impostor." % peer_id
		return {"allowed": false, "reason": msg}

	if not assigned_objectives.has(objective_id):
		var msg = "Objective completion rejected: unknown objective ID '%s'." % objective_id
		return {"allowed": false, "reason": msg}

	var obj: BlackoutObjectiveDefinition = assigned_objectives[objective_id]
	if obj.assigned_peer_id != peer_id:
		var msg = "Objective completion rejected: objective '%s' does not belong to player %d." % [objective_id, peer_id]
		return {"allowed": false, "reason": msg}

	if obj.is_completed:
		var msg = "Objective completion rejected: objective '%s' is already completed." % objective_id
		return {"allowed": false, "reason": msg}

	return {"allowed": true, "reason": ""}

func request_complete_objective(
	peer_id: int,
	objective_id: String,
	current_state: NetworkConfig.GameState,
	is_impostor: bool
) -> Dictionary:
	var check = can_complete_objective(peer_id, objective_id, current_state, is_impostor)
	if not check.allowed:
		push_warning("[ImpostorObjectiveManager] %s" % check.reason)
		return {"success": false, "error": check.reason}

	var obj: BlackoutObjectiveDefinition = assigned_objectives[objective_id]
	obj.is_completed = true
	obj.completed_at = Time.get_unix_time_from_system()

	var completed_count = get_completed_objectives_count()
	print("[ImpostorObjectiveManager] Impostor objective '%s' completed by player %d. Total completed: %d/%d." % [
		obj.display_name, peer_id, completed_count, assigned_objectives.size()
	])

	objective_completed.emit(peer_id, objective_id)

	return {
		"success": true,
		"objective_id": objective_id,
		"completed_count": completed_count,
		"total_count": assigned_objectives.size()
	}

func handle_player_disconnect(peer_id: int) -> void:
	# Keep historical records and state intact even if Impostor disconnects
	pass
