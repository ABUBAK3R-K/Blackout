class_name BlackoutRecoveryDefinition
extends RefCounted

## Authoritative data structure representing a Blackout recovery subsystem instance.

var system_id: String = ""              # Unique subsystem identifier (e.g. "generator", "power_routing")
var display_name: String = ""           # Human-readable title (e.g. "Generator", "Power Routing")
var category: String = "power"          # Subsystem category
var location_id: String = ""            # Location identifier for future map integration
var is_completed: bool = false          # Authoritative completion state
var completed_by_peer_id: int = 0       # Peer ID of the Crew player who completed this subsystem
var completed_at: float = 0.0           # Unix timestamp when completed

func _init(
	p_id: String = "",
	p_name: String = "",
	p_category: String = "power",
	p_location: String = ""
) -> void:
	system_id = p_id
	display_name = p_name
	category = p_category
	location_id = p_location
	is_completed = false
	completed_by_peer_id = 0
	completed_at = 0.0

func to_dict() -> Dictionary:
	return {
		"system_id": system_id,
		"display_name": display_name,
		"category": category,
		"location_id": location_id,
		"is_completed": is_completed,
		"completed_by_peer_id": completed_by_peer_id,
		"completed_at": completed_at
	}

static func from_dict(d: Dictionary) -> RefCounted:
	var rec = load("res://shared/blackout_recovery_definition.gd").new(
		str(d.get("system_id", "")),
		str(d.get("display_name", "")),
		str(d.get("category", "power")),
		str(d.get("location_id", ""))
	)
	rec.is_completed = bool(d.get("is_completed", false))
	rec.completed_by_peer_id = int(d.get("completed_by_peer_id", 0))
	rec.completed_at = float(d.get("completed_at", 0.0))
	return rec
