class_name MeltdownConfig
extends RefCounted

## Centralized configuration and constants for the Authoritative Meltdown & Endgame System (Step 10).

## Authoritative duration for the Meltdown emergency phase in seconds (5 minutes).
const DEFAULT_MELTDOWN_DURATION_SEC: float = 300.0

## Emergency system identifiers
const SYSTEM_RESTORE_POWER: String = "restore_power"
const SYSTEM_RESTORE_COOLING: String = "restore_cooling"
const SYSTEM_STABILIZE_ORION: String = "stabilize_orion"

const ALL_EMERGENCY_SYSTEMS: Array[String] = [
	SYSTEM_RESTORE_POWER,
	SYSTEM_RESTORE_COOLING,
	SYSTEM_STABILIZE_ORION
]

enum GameOverReason {
	NONE,
	CREW_EMERGENCY_SYSTEMS_COMPLETE,
	IMPOSTOR_MELTDOWN_TIMER_EXPIRED
}

static func get_game_over_reason_name(reason: GameOverReason) -> String:
	match reason:
		GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE:
			return "CREW_EMERGENCY_SYSTEMS_COMPLETE"
		GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED:
			return "IMPOSTOR_MELTDOWN_TIMER_EXPIRED"
		_:
			return "NONE"

static func get_emergency_system_name(system_id: String) -> String:
	match system_id:
		SYSTEM_RESTORE_POWER:
			return "Restore Power"
		SYSTEM_RESTORE_COOLING:
			return "Restore Cooling"
		SYSTEM_STABILIZE_ORION:
			return "Stabilize ORION"
		_:
			return "Unknown Emergency System"

static func is_valid_emergency_system(system_id: String) -> bool:
	return ALL_EMERGENCY_SYSTEMS.has(system_id)
