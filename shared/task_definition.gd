class_name TaskDefinition
extends RefCounted

## Authoritative data structure representing a task instance in BLACKOUT.

var task_id: String = ""              # Unique instance identifier (e.g. "task_repair_power_p1_0")
var task_type_id: String = ""         # Catalog key (e.g. "repair_power")
var display_name: String = ""         # Human-readable title (e.g. "Repair Power")
var category: String = "general"      # Subsystem (e.g. "electrical", "orion", "security")
var assigned_peer_id: int = 0         # Peer ID of the player who owns this task
var is_completed: bool = false        # Authoritative completion state
var is_impostor_prerequisite: bool = false # True if this task counts towards unlocking Blackout
var completed_at: float = 0.0         # Unix timestamp when completed

func _init(
	p_id: String = "",
	p_type: String = "",
	p_name: String = "",
	p_category: String = "general",
	p_peer: int = 0,
	p_is_prereq: bool = false
) -> void:
	task_id = p_id
	task_type_id = p_type
	display_name = p_name
	category = p_category
	assigned_peer_id = p_peer
	is_completed = false
	is_impostor_prerequisite = p_is_prereq
	completed_at = 0.0

## Serializes task data for private network transmission to the assigned player.
func to_dict() -> Dictionary:
	return {
		"task_id": task_id,
		"task_type_id": task_type_id,
		"display_name": display_name,
		"category": category,
		"is_completed": is_completed,
		"is_impostor_prerequisite": is_impostor_prerequisite,
		"completed_at": completed_at
	}

static func from_dict(d: Dictionary) -> RefCounted:
	var task = load("res://shared/task_definition.gd").new(
		str(d.get("task_id", "")),
		str(d.get("task_type_id", "")),
		str(d.get("display_name", "")),
		str(d.get("category", "general")),
		int(d.get("assigned_peer_id", 0)),
		bool(d.get("is_impostor_prerequisite", false))
	)
	task.is_completed = bool(d.get("is_completed", false))
	task.completed_at = float(d.get("completed_at", 0.0))
	return task
