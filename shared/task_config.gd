class_name TaskConfig
extends RefCounted

## Centralized task configuration and catalog for BLACKOUT.

## Number of tasks assigned to each Crew member for the match.
const DEFAULT_CREW_TASK_COUNT: int = 4

## Number of prerequisite tasks the Impostor must complete to unlock Blackout.
## Configured to be fewer than the normal Crew task count.
const DEFAULT_IMPOSTOR_PREREQUISITE_COUNT: int = 2

## Task catalog containing representative facility tasks based on the design specification.
const TASK_CATALOG: Dictionary = {
	"repair_power": {
		"display_name": "Repair Power",
		"category": "electrical"
	},
	"stabilize_orion": {
		"display_name": "Stabilize ORION",
		"category": "orion_core"
	},
	"server_calibration": {
		"display_name": "Server Calibration",
		"category": "tech"
	},
	"security_repair": {
		"display_name": "Security Repair",
		"category": "security"
	},
	"medical_supply_check": {
		"display_name": "Medical Supply Check",
		"category": "medbay"
	},
	"data_transfer": {
		"display_name": "Data Transfer",
		"category": "comms"
	},
	"door_repair": {
		"display_name": "Door Repair",
		"category": "maintenance"
	},
	"coolant_system": {
		"display_name": "Coolant System",
		"category": "engineering"
	},
	"laboratory_org": {
		"display_name": "Laboratory Organization",
		"category": "lab"
	},
	"backup_power": {
		"display_name": "Backup Power",
		"category": "electrical"
	}
}

static func get_catalog() -> Dictionary:
	return TASK_CATALOG.duplicate()

static func get_task_info(type_id: String) -> Dictionary:
	return TASK_CATALOG.get(type_id, {})

static func get_all_task_types() -> Array:
	return TASK_CATALOG.keys()
