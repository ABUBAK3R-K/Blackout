class_name EvidenceDefinition
extends RefCounted

## Authoritative data structure representing a discoverable evidence record in BLACKOUT.
## Contains factual observations of events that occurred during Blackout.

var evidence_id: String = ""                   # Unique evidence record identifier (e.g. "ev_classified_files_missing_1")
var evidence_type: String = ""                 # Categorical type key (e.g. "classified_files_missing")
var display_name: String = ""                  # Human-readable title (e.g. "Classified Files Missing")
var description: String = ""                   # Objective, factual description of what occurred
var source_system: String = ""                 # System or facility area involved
var location_id: String = ""                   # Location identifier where evidence was discovered
var timestamp: float = 0.0                     # Authoritative server unix timestamp
var severity: String = "info"                  # Severity level ("critical", "high", "medium", "info")
var category: String = "general"               # Functional category ("espionage", "data_theft", "sabotage", "recovery", etc.)
var related_objective_id: String = ""          # Associated objective ID if applicable
var related_recovery_system_id: String = ""    # Associated recovery subsystem ID if applicable

## Server-internal attribution (never exposed in public client serialization)
var _internal_actor_peer_id: int = 0

func _init(
	p_id: String = "",
	p_type: String = "",
	p_name: String = "",
	p_desc: String = "",
	p_source: String = "",
	p_loc: String = "",
	p_time: float = 0.0,
	p_severity: String = "info",
	p_category: String = "general",
	p_obj_id: String = "",
	p_rec_id: String = "",
	p_internal_actor: int = 0
) -> void:
	evidence_id = p_id
	evidence_type = p_type
	display_name = p_name
	description = p_desc
	source_system = p_source
	location_id = p_loc
	timestamp = p_time if p_time > 0.0 else Time.get_unix_time_from_system()
	severity = p_severity
	category = p_category
	related_objective_id = p_obj_id
	related_recovery_system_id = p_rec_id
	_internal_actor_peer_id = p_internal_actor

## Serializes factual evidence for public network broadcast to all players.
## Guaranteed: Contains zero player identity, role, or hidden attribution data.
func to_public_dict() -> Dictionary:
	return {
		"evidence_id": evidence_id,
		"evidence_type": evidence_type,
		"display_name": display_name,
		"description": description,
		"source_system": source_system,
		"location_id": location_id,
		"timestamp": timestamp,
		"severity": severity,
		"category": category,
		"related_objective_id": related_objective_id,
		"related_recovery_system_id": related_recovery_system_id
	}

static func from_dict(d: Dictionary) -> RefCounted:
	var ev = load("res://shared/evidence_definition.gd").new(
		str(d.get("evidence_id", "")),
		str(d.get("evidence_type", "")),
		str(d.get("display_name", "")),
		str(d.get("description", "")),
		str(d.get("source_system", "")),
		str(d.get("location_id", "")),
		float(d.get("timestamp", 0.0)),
		str(d.get("severity", "info")),
		str(d.get("category", "general")),
		str(d.get("related_objective_id", "")),
		str(d.get("related_recovery_system_id", ""))
	)
	return ev
