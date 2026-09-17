class_name BlackoutObjectiveConfig
extends RefCounted

## Centralized configuration for Impostor secret Blackout objectives.

const DEFAULT_IMPOSTOR_OBJECTIVE_COUNT: int = 3

## Standard Impostor secret objective catalog for MVP (5 objectives).
const OBJECTIVE_CATALOG: Array[Dictionary] = [
	{
		"objective_id": "steal_confidential_files",
		"display_name": "Steal Confidential Files",
		"category": "espionage",
		"location_id": "executive_office",
		"evidence_flag_id": "file_cabinet_fingerprints"
	},
	{
		"objective_id": "extract_orion_core_data",
		"display_name": "Extract ORION Core Data",
		"category": "data_theft",
		"location_id": "orion_core",
		"evidence_flag_id": "data_terminal_tamper_log"
	},
	{
		"objective_id": "disable_orion_containment",
		"display_name": "Disable ORION Containment",
		"category": "containment",
		"location_id": "containment_hub",
		"evidence_flag_id": "containment_override_switch"
	},
	{
		"objective_id": "sabotage_generator",
		"display_name": "Sabotage Generator",
		"category": "sabotage",
		"location_id": "generator_room",
		"evidence_flag_id": "severed_power_cable"
	},
	{
		"objective_id": "tamper_security",
		"display_name": "Tamper With Security",
		"category": "security",
		"location_id": "security_room",
		"evidence_flag_id": "scrambled_camera_log"
	}
]
