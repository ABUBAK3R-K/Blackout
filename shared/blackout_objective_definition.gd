class_name BlackoutObjectiveDefinition
extends RefCounted

## Authoritative data structure representing an Impostor secret Blackout objective.

var objective_id: String = ""          # Unique identifier (e.g. "steal_confidential_files")
var display_name: String = ""          # Human-readable title (e.g. "Steal Confidential Files")
var category: String = "sabotage"      # Category (e.g. "espionage", "data_theft", "containment", "sabotage", "security")
var assigned_peer_id: int = 0          # Peer ID of the Impostor assigned to this objective
var location_id: String = ""           # Location identifier for future map integration
var evidence_flag_id: String = ""      # Evidence identifier for future Step 8 integration
var is_completed: bool = false         # Authoritative completion state
var completed_at: float = 0.0          # Unix timestamp when completed

func _init(
	p_id: String = "",
	p_name: String = "",
	p_category: String = "sabotage",
	p_location: String = "",
	p_evidence: String = "",
	p_peer: int = 0
) -> void:
	objective_id = p_id
	display_name = p_name
	category = p_category
	location_id = p_location
	evidence_flag_id = p_evidence
	assigned_peer_id = p_peer
	is_completed = false
	completed_at = 0.0

func to_dict() -> Dictionary:
	return {
		"objective_id": objective_id,
		"display_name": display_name,
		"category": category,
		"location_id": location_id,
		"evidence_flag_id": evidence_flag_id,
		"is_completed": is_completed,
		"completed_at": completed_at
	}

static func from_dict(d: Dictionary) -> RefCounted:
	var obj = load("res://shared/blackout_objective_definition.gd").new(
		str(d.get("objective_id", "")),
		str(d.get("display_name", "")),
		str(d.get("category", "sabotage")),
		str(d.get("location_id", "")),
		str(d.get("evidence_flag_id", "")),
		int(d.get("assigned_peer_id", 0))
	)
	obj.is_completed = bool(d.get("is_completed", false))
	obj.completed_at = float(d.get("completed_at", 0.0))
	return obj
