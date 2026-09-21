class_name SabotageManager
extends RefCounted

## Central Sabotage Management Foundation for BLACKOUT.
## Handles sabotage data representation, state transitions, validation of role permissions,
## duplicate activation protection, and sabotage lifecycle timing.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

const NetworkConfig = preload("res://shared/network_config.gd")

## Reusable Sabotage Type enumeration.
## Extensible for future sabotage types (e.g. OXYGEN_DEPLETION, COMMUNICATIONS_JAM).
enum SabotageType {
	NONE = 0,
	POWER_BLACKOUT = 1
}

## Sabotage lifecycle state.
enum SabotageState {
	INACTIVE = 0,
	ACTIVE = 1,
	RESOLVED = 2
}

signal sabotage_started(type: SabotageType, duration: float)
signal sabotage_resolved(type: SabotageType, reason: String)
signal sabotage_state_changed(type: SabotageType, state: SabotageState)

var current_sabotage_type: SabotageType = SabotageType.NONE
var current_sabotage_state: SabotageState = SabotageState.INACTIVE

var sabotage_start_time: float = 0.0
var sabotage_duration: float = 0.0
var active_initiator_peer_id: int = 0

## Cooldown configuration (seconds between sabotages)
var cooldown_duration: float = 20.0
var last_resolution_time: float = -999.0

func clear() -> void:
	current_sabotage_type = SabotageType.NONE
	current_sabotage_state = SabotageState.INACTIVE
	sabotage_start_time = 0.0
	sabotage_duration = 0.0
	active_initiator_peer_id = 0
	last_resolution_time = -999.0

## Validates whether a player with the given role can trigger the requested sabotage.
## Server strictly calls this using authoritative role data.
func can_trigger_sabotage(requesting_peer_id: int, role: NetworkConfig.PlayerRole, sabotage_type: SabotageType) -> Dictionary:
	# 1. Authoritative Role Security: Strictly only IMPOSTOR can trigger sabotage
	if role != NetworkConfig.PlayerRole.IMPOSTOR:
		var msg = "Sabotage request rejected: Peer %d has role %s (Expected: IMPOSTOR)." % [
			requesting_peer_id, NetworkConfig.get_role_name(role)
		]
		return {"allowed": false, "reason": msg}

	# 2. Duplicate / Active State Protection: Cannot trigger if a sabotage is already active
	if is_sabotage_active():
		var msg = "Sabotage request rejected: Sabotage %s is already ACTIVE." % get_sabotage_name(current_sabotage_type)
		return {"allowed": false, "reason": msg}

	# 3. Type Validation: Ensure requested type is valid and supported
	if sabotage_type == SabotageType.NONE or sabotage_type != SabotageType.POWER_BLACKOUT:
		var msg = "Sabotage request rejected: Invalid or unsupported sabotage type (%d)." % sabotage_type
		return {"allowed": false, "reason": msg}

	return {"allowed": true, "reason": ""}

## Starts the specified sabotage.
func start_sabotage(type: SabotageType, duration: float = 0.0, initiator_peer_id: int = 0) -> Dictionary:
	current_sabotage_type = type
	current_sabotage_state = SabotageState.ACTIVE
	sabotage_duration = duration
	sabotage_start_time = Time.get_unix_time_from_system()
	active_initiator_peer_id = initiator_peer_id

	print("[SabotageManager] Sabotage STARTED: %s (Initiator Peer: %d | Duration: %.1fs)." % [
		get_sabotage_display_name(type), initiator_peer_id, duration
	])

	sabotage_started.emit(type, duration)
	sabotage_state_changed.emit(type, current_sabotage_state)

	return {
		"success": true,
		"sabotage_type": type,
		"state": current_sabotage_state,
		"duration": duration
	}

## Resolves the current active sabotage.
func resolve_sabotage(reason: String = "") -> Dictionary:
	if not is_sabotage_active() and current_sabotage_state != SabotageState.ACTIVE:
		return {"success": false, "reason": "No active sabotage to resolve."}

	var prev_type = current_sabotage_type
	current_sabotage_state = SabotageState.RESOLVED
	last_resolution_time = Time.get_unix_time_from_system()

	var msg = "Sabotage RESOLVED: %s" % get_sabotage_display_name(prev_type)
	if not reason.is_empty():
		msg += " (Reason: %s)" % reason
	print("[SabotageManager] %s" % msg)

	sabotage_resolved.emit(prev_type, reason)
	sabotage_state_changed.emit(prev_type, current_sabotage_state)

	# Reset active type to NONE and state to INACTIVE for subsequent cycles
	current_sabotage_type = SabotageType.NONE
	current_sabotage_state = SabotageState.INACTIVE
	active_initiator_peer_id = 0

	return {
		"success": true,
		"resolved_type": prev_type,
		"reason": reason
	}

## Optional per-frame tick for time tracking
func tick(_delta: float) -> void:
	if is_sabotage_active() and sabotage_duration > 0.0:
		var elapsed = Time.get_unix_time_from_system() - sabotage_start_time
		if elapsed >= sabotage_duration:
			resolve_sabotage("Sabotage duration expired.")

## Returns true if a sabotage is currently active.
func is_sabotage_active() -> bool:
	return current_sabotage_state == SabotageState.ACTIVE and current_sabotage_type != SabotageType.NONE

## Returns the currently active sabotage type enum.
func get_active_sabotage_type() -> SabotageType:
	return current_sabotage_type

## Returns the current sabotage state enum.
func get_current_state() -> SabotageState:
	return current_sabotage_state

## Returns the string identifier of a sabotage type.
static func get_sabotage_name(type: SabotageType) -> String:
	match type:
		SabotageType.NONE:
			return "NONE"
		SabotageType.POWER_BLACKOUT:
			return "POWER_BLACKOUT"
		_:
			return "UNKNOWN"

## Returns a user-friendly display name of a sabotage type.
static func get_sabotage_display_name(type: SabotageType) -> String:
	match type:
		SabotageType.NONE:
			return "None"
		SabotageType.POWER_BLACKOUT:
			return "Power Blackout"
		_:
			return "Unknown Sabotage"

## Returns the string representation of a sabotage state.
static func get_state_name(state: SabotageState) -> String:
	match state:
		SabotageState.INACTIVE:
			return "INACTIVE"
		SabotageState.ACTIVE:
			return "ACTIVE"
		SabotageState.RESOLVED:
			return "RESOLVED"
		_:
			return "UNKNOWN"
