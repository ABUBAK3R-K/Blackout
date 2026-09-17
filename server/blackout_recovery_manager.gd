class_name BlackoutRecoveryManager
extends RefCounted

## Server-authoritative manager for the Crew Blackout Recovery system during BLACKOUT_ACTIVE.

const NetworkConfig = preload("res://shared/network_config.gd")
const BlackoutRecoveryConfig = preload("res://shared/blackout_recovery_config.gd")
const BlackoutRecoveryDefinition = preload("res://shared/blackout_recovery_definition.gd")

signal recovery_systems_initialized(systems: Array, required_count: int)
signal recovery_system_completed(peer_id: int, system_id: String, completed_count: int, required_count: int)
signal recovery_threshold_reached(completed_count: int, required_count: int)

var recovery_systems: Dictionary = {} # system_id (String) -> BlackoutRecoveryDefinition
var total_recovery_systems_count: int = BlackoutRecoveryConfig.DEFAULT_TOTAL_RECOVERY_SYSTEMS
var required_recovery_systems_count: int = BlackoutRecoveryConfig.DEFAULT_REQUIRED_RECOVERY_SYSTEMS
var is_threshold_reached: bool = false

func clear() -> void:
	recovery_systems.clear()
	total_recovery_systems_count = BlackoutRecoveryConfig.DEFAULT_TOTAL_RECOVERY_SYSTEMS
	required_recovery_systems_count = BlackoutRecoveryConfig.DEFAULT_REQUIRED_RECOVERY_SYSTEMS
	is_threshold_reached = false

## Sets up custom counts or catalog if desired for testing or balancing.
func setup(
	p_required_count: int = BlackoutRecoveryConfig.DEFAULT_REQUIRED_RECOVERY_SYSTEMS,
	p_total_count: int = BlackoutRecoveryConfig.DEFAULT_TOTAL_RECOVERY_SYSTEMS
) -> void:
	clear()
	required_recovery_systems_count = p_required_count
	total_recovery_systems_count = p_total_count

## Initializes all recovery systems to incomplete state when BLACKOUT_ACTIVE starts.
func initialize_systems(custom_catalog: Array = []) -> void:
	recovery_systems.clear()
	is_threshold_reached = false

	var catalog: Array = custom_catalog if custom_catalog.size() > 0 else BlackoutRecoveryConfig.RECOVERY_CATALOG
	var limit: int = min(catalog.size(), total_recovery_systems_count)

	for i in range(limit):
		var item: Dictionary = catalog[i]
		var system_id: String = str(item.get("system_id", ""))
		var display_name: String = str(item.get("display_name", ""))
		var category: String = str(item.get("category", "power"))
		var location_id: String = str(item.get("location_id", ""))

		var rec = BlackoutRecoveryDefinition.new(system_id, display_name, category, location_id)
		recovery_systems[system_id] = rec

	print("[BlackoutRecoveryManager] Initialized %d recovery subsystems (Required threshold: %d/%d)." % [
		recovery_systems.size(), required_recovery_systems_count, recovery_systems.size()
	])

	recovery_systems_initialized.emit(get_all_systems_serialized(), required_recovery_systems_count)

func get_completed_count() -> int:
	var count: int = 0
	for rec: BlackoutRecoveryDefinition in recovery_systems.values():
		if rec.is_completed:
			count += 1
	return count

func get_system(system_id: String) -> BlackoutRecoveryDefinition:
	return recovery_systems.get(system_id, null)

func get_all_systems_serialized() -> Array:
	var list: Array = []
	for rec: BlackoutRecoveryDefinition in recovery_systems.values():
		list.append(rec.to_dict())
	return list

func can_recover_system(
	peer_id: int,
	system_id: String,
	current_state: NetworkConfig.GameState,
	is_crew: bool
) -> Dictionary:
	if current_state != NetworkConfig.GameState.BLACKOUT_ACTIVE:
		var msg = "Recovery request rejected: current match state is %s (Expected: BLACKOUT_ACTIVE)." % NetworkConfig.get_game_state_name(current_state)
		return {"allowed": false, "reason": msg}

	if not is_crew:
		var msg = "Recovery request rejected: player %d is not a Crew member (Impostor cannot recover systems)." % peer_id
		return {"allowed": false, "reason": msg}

	if not recovery_systems.has(system_id):
		var msg = "Recovery request rejected: unknown recovery system ID '%s'." % system_id
		return {"allowed": false, "reason": msg}

	var rec: BlackoutRecoveryDefinition = recovery_systems[system_id]
	if rec.is_completed:
		var msg = "Recovery request rejected: system '%s' is already completed." % system_id
		return {"allowed": false, "reason": msg}

	return {"allowed": true, "reason": ""}

func request_recover_system(
	peer_id: int,
	system_id: String,
	current_state: NetworkConfig.GameState,
	is_crew: bool
) -> Dictionary:
	var check = can_recover_system(peer_id, system_id, current_state, is_crew)
	if not check.allowed:
		push_warning("[BlackoutRecoveryManager] %s" % check.reason)
		return {"success": false, "error": check.reason}

	var rec: BlackoutRecoveryDefinition = recovery_systems[system_id]
	rec.is_completed = true
	rec.completed_by_peer_id = peer_id
	rec.completed_at = Time.get_unix_time_from_system()

	var completed_count = get_completed_count()
	print("[BlackoutRecoveryManager] Recovery system '%s' completed by Crew peer %d. Progress: %d/%d (Required: %d)." % [
		rec.display_name, peer_id, completed_count, recovery_systems.size(), required_recovery_systems_count
	])

	recovery_system_completed.emit(peer_id, system_id, completed_count, required_recovery_systems_count)

	if completed_count >= required_recovery_systems_count and not is_threshold_reached:
		is_threshold_reached = true
		print("[BlackoutRecoveryManager] RECOVERY THRESHOLD REACHED (%d/%d systems restored)! Triggering early Blackout termination." % [
			completed_count, required_recovery_systems_count
		])
		recovery_threshold_reached.emit(completed_count, required_recovery_systems_count)

	return {
		"success": true,
		"system_id": system_id,
		"completed_count": completed_count,
		"required_count": required_recovery_systems_count,
		"threshold_reached": is_threshold_reached
	}

func handle_player_disconnect(peer_id: int) -> void:
	# Recovery state remains completely intact even if a player disconnects
	pass
