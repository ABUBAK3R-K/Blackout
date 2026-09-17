class_name BlackoutRecoveryConfig
extends RefCounted

## Centralized configuration for the Crew Blackout Recovery system.

const DEFAULT_TOTAL_RECOVERY_SYSTEMS: int = 4
const DEFAULT_REQUIRED_RECOVERY_SYSTEMS: int = 3

## Standard facility recovery subsystem catalog for MVP.
const RECOVERY_CATALOG: Array[Dictionary] = [
	{
		"system_id": "generator",
		"display_name": "Generator",
		"category": "power",
		"location_id": "generator_room"
	},
	{
		"system_id": "power_routing",
		"display_name": "Power Routing",
		"category": "electrical",
		"location_id": "power_room"
	},
	{
		"system_id": "security_relay",
		"display_name": "Security Relay",
		"category": "security",
		"location_id": "security_room"
	},
	{
		"system_id": "cooling",
		"display_name": "Cooling",
		"category": "life_support",
		"location_id": "cooling_hub"
	}
]
