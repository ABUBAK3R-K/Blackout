class_name TaskStep
extends Resource

## Reusable model representing a sequential step within a multi-step facility task or mini-game.
## Supports step ordering, completion tracking, contextual action prompts, and serialization.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

@export_group("Step Identification")
## Unique identifier for this step within the parent objective.
@export var step_id: String = ""

## Human-readable name of the step (e.g. 'Open Junction Panel').
@export var step_name: String = ""

## Detailed description of the step action.
@export_multiline var step_description: String = ""

## Zero-indexed progression order of this step.
@export var step_index: int = 0

@export_group("Step State")
## Whether this step has been completed.
@export var is_completed: bool = false

## Contextual action prompt shown when this step is active (e.g. 'Press E to Open Panel').
@export var action_prompt: String = ""

func _init(
	p_id: String = "",
	p_name: String = "",
	p_desc: String = "",
	p_index: int = 0,
	p_prompt: String = ""
) -> void:
	step_id = p_id
	step_name = p_name
	step_description = p_desc
	step_index = p_index
	action_prompt = p_prompt
	is_completed = false

## Returns structured dictionary representation for serialization and signal dispatches.
func to_dict() -> Dictionary:
	return {
		"step_id": step_id,
		"step_name": step_name,
		"step_description": step_description,
		"step_index": step_index,
		"is_completed": is_completed,
		"action_prompt": action_prompt
	}

## Creates a new TaskStep instance from a dictionary representation.
static func from_dict(d: Dictionary) -> Resource:
	var script = load("res://client/objectives/task_step.gd") as GDScript
	var step = script.new(
		str(d.get("step_id", "")),
		str(d.get("step_name", "")),
		str(d.get("step_description", "")),
		int(d.get("step_index", 0)),
		str(d.get("action_prompt", ""))
	)
	step.is_completed = bool(d.get("is_completed", false))
	return step
