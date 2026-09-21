class_name ObjectiveInteractable
extends Node2D

## Reusable Task Objective & Multi-Step Mini-Game Foundation for BLACKOUT.
## Integrates facility devices (Junction Boxes, Life Support Valves, Terminals, Consoles)
## with the existing InteractableTrigger proximity detection and InteractionAudio feedback.
## Supports arbitrary sequential TaskSteps (Step 1 -> Step 2 -> ... -> Completed)
## and preserves 100% backward compatibility for single-step objectives.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

const TaskStep = preload("res://client/objectives/task_step.gd")
const InteractableTrigger = preload("res://client/environment/interactable_trigger.gd")
const InteractionAudio = preload("res://client/environment/interaction_audio.gd")

enum ObjectiveState {
	AVAILABLE,
	IN_PROGRESS,
	COMPLETED,
	LOCKED
}

signal objective_started(player: Node2D)
signal objective_completed(player: Node2D)
signal objective_state_changed(new_state: ObjectiveState)
signal objective_failed(player: Node2D)

## Signals emitted for multi-step task progression
signal task_step_started(step_index: int, step_data: Dictionary, player: Node2D)
signal task_step_completed(step_index: int, step_data: Dictionary, player: Node2D)
signal task_step_changed(current_step: int, total_steps: int, step_data: Dictionary)

@export_group("Objective Metadata")
## Unique identifier for this objective instance (e.g. 'electrical_junction_01').
@export var objective_id: String = "electrical_junction_01"

## Task catalog type identifier (e.g. 'repair_power', 'server_calibration', 'stabilize_orion').
## Defaults to objective_id if left empty.
@export var task_type_id: String = ""

## Human-readable title displayed in prompts and UI feedback.
@export var objective_name: String = "Electrical Junction"

## Detailed description of the task requirements.
@export_multiline var objective_description: String = "Restore power to the facility junction."

## Facility subsystem category (e.g. 'electrical', 'orion_core', 'security', 'tech').
@export var category: String = "electrical"

## Facility room or physical location for HUD navigation and tracking.
@export var room_location: String = "Generator Room"

@export_group("Multi-Step Task Progression")
## Array of TaskStep data resources for sequential multi-step tasks (empty for single-step).
@export var task_steps: Array[Resource] = []

## Current active step index (0-indexed).
@export var current_step_index: int = 0

@export_group("State & Interaction Configuration")
## Current lifecycle state of the objective.
@export var current_state: ObjectiveState = ObjectiveState.AVAILABLE

## When true, single-step tasks complete immediately on interaction, and multi-step tasks advance 1 step per E press.
@export var auto_complete_on_interact: bool = true

## Duration in seconds required for timed or channeled interactions (0.0 = instant).
@export var progress_duration: float = 0.0

@export_group("Contextual Prompt Overrides")
@export var prompt_text_available: String = "Press E to repair Electrical Junction"
@export var prompt_text_in_progress: String = "Repairing..."
@export var prompt_text_completed: String = "Electrical Junction (Repaired)"
@export var prompt_text_locked: String = "Objective Locked"

@onready var trigger: InteractableTrigger = get_node_or_null("InteractableTrigger")
@onready var status_label: Label = get_node_or_null("StatusLabel")
@onready var indicator_light: Polygon2D = get_node_or_null("Visual/IndicatorLight")
@onready var interaction_audio: InteractionAudio = get_node_or_null("InteractionAudio")

func _ready() -> void:
	add_to_group("objective_interactable")

	# Ensure task steps are populated with proper TaskStep instances
	if has_steps():
		for i in range(task_steps.size()):
			var s = task_steps[i]
			if s == null or not ("step_name" in s) or s.step_name == "":
				match i:
					0: task_steps[i] = TaskStep.new("step_open_panel", "Open Junction Panel", "Open the junction maintenance panel.", 0, "Press E to Open Junction Panel")
					1: task_steps[i] = TaskStep.new("step_inspect_circuit", "Inspect Electrical Circuit", "Inspect the electrical wiring and fuses.", 1, "Press E to Inspect Circuit")
					2: task_steps[i] = TaskStep.new("step_restore_power", "Restore Power", "Switch breakers and restore auxiliary power.", 2, "Press E to Restore Power")
					3: task_steps[i] = TaskStep.new("step_close_panel", "Close Junction Panel", "Close and secure the junction panel.", 3, "Press E to Close Junction Panel")

	if trigger != null:
		trigger.interactable_id = objective_id
		trigger.interacted.connect(_on_interacted)

	_update_visuals_and_prompts()

## Returns true if this objective contains multiple sequential task steps.
func has_steps() -> bool:
	return not task_steps.is_empty()

## Returns the total number of steps in this objective.
func get_total_steps() -> int:
	return task_steps.size()

## Returns the current active TaskStep resource, or null if none.
func get_current_step() -> Resource:
	if has_steps() and current_step_index >= 0 and current_step_index < task_steps.size():
		return task_steps[current_step_index]
	return null

## Returns a dictionary of the active step's data.
func get_current_step_data() -> Dictionary:
	var step = get_current_step()
	return step.to_dict() if step != null else {}

## Programmatically appends a step to the objective's step list.
func add_step(p_id: String, p_name: String, p_desc: String = "", p_prompt: String = "") -> TaskStep:
	var step = TaskStep.new(p_id, p_name, p_desc, task_steps.size(), p_prompt)
	task_steps.append(step)
	_update_visuals_and_prompts()
	return step

## Returns the effective task type identifier (defaults to objective_id if task_type_id is empty).
func get_effective_task_type_id() -> String:
	return task_type_id if not task_type_id.is_empty() else objective_id

## Handles interaction event emitted by the child InteractableTrigger.
func _on_interacted(player: Node2D) -> void:
	if player != null and player.get("is_eliminated") == true:
		print("[ObjectiveInteractable] '%s' interaction rejected: player is eliminated." % objective_id)
		return

	match current_state:
		ObjectiveState.AVAILABLE:
			start_objective(player)
		ObjectiveState.IN_PROGRESS:
			if has_steps():
				advance_task_step(player)
			elif auto_complete_on_interact:
				complete_objective(player)
			else:
				print("[ObjectiveInteractable] '%s' already in progress." % objective_id)
		ObjectiveState.COMPLETED:
			print("[ObjectiveInteractable] '%s' is already COMPLETED. Ignoring repeat interaction." % objective_id)
		ObjectiveState.LOCKED:
			print("[ObjectiveInteractable] '%s' is LOCKED. Interaction rejected." % objective_id)

## Transitions objective to IN_PROGRESS state and initiates progression.
func start_objective(player: Node2D) -> bool:
	if current_state != ObjectiveState.AVAILABLE:
		return false

	current_state = ObjectiveState.IN_PROGRESS
	current_step_index = 0
	print("[ObjectiveInteractable] Started objective '%s' (%s) by %s." % [
		objective_id, objective_name, player.name if player != null else "LocalPlayer"
	])

	objective_started.emit(player)
	objective_state_changed.emit(current_state)

	if has_steps():
		var step = get_current_step()
		task_step_started.emit(0, step.to_dict() if step != null else {}, player)
		task_step_changed.emit(0, get_total_steps(), step.to_dict() if step != null else {})

		if auto_complete_on_interact:
			advance_task_step(player) # Completes step 0 on first interaction
		else:
			_update_visuals_and_prompts()
	else:
		if auto_complete_on_interact:
			complete_objective(player)
		else:
			_update_visuals_and_prompts()

	return true

## Advances to the next sequential step. Completes the objective if final step is finished.
func advance_task_step(player: Node2D) -> bool:
	if current_state != ObjectiveState.IN_PROGRESS or not has_steps():
		return false

	if current_step_index < 0 or current_step_index >= task_steps.size():
		return false

	var completed_step = task_steps[current_step_index]
	if completed_step != null:
		if "is_completed" in completed_step:
			completed_step.is_completed = true
		var s_name = completed_step.step_name if "step_name" in completed_step else ""
		print("[ObjectiveInteractable] Step %d/%d ('%s') COMPLETED on '%s'." % [
			current_step_index + 1, get_total_steps(), s_name, objective_id
		])
		var s_dict = completed_step.to_dict() if completed_step.has_method("to_dict") else {}
		task_step_completed.emit(current_step_index, s_dict, player)

	current_step_index += 1

	# Check if all steps have been completed
	if current_step_index >= task_steps.size():
		task_step_changed.emit(current_step_index, get_total_steps(), {})
		complete_objective(player)
		return true

	# Next step becomes available
	var next_step = task_steps[current_step_index]
	if next_step != null:
		var n_name = next_step.step_name if "step_name" in next_step else ""
		print("[ObjectiveInteractable] Step %d/%d ('%s') now ACTIVE on '%s'." % [
			current_step_index + 1, get_total_steps(), n_name, objective_id
		])
		var n_dict = next_step.to_dict() if next_step.has_method("to_dict") else {}
		task_step_started.emit(current_step_index, n_dict, player)
		task_step_changed.emit(current_step_index, get_total_steps(), n_dict)

	_update_visuals_and_prompts()
	return true

## Transitions objective to COMPLETED state, triggers audio/visual feedback, and emits signal.
func complete_objective(player: Node2D = null) -> bool:
	if current_state == ObjectiveState.COMPLETED or current_state == ObjectiveState.LOCKED:
		return false

	current_state = ObjectiveState.COMPLETED
	print("[ObjectiveInteractable] Objective '%s' (%s) COMPLETED by %s." % [
		objective_id, objective_name, player.name if player != null else "System"
	])

	# Check if NetworkManager is present and player is local in a multiplayer session
	var is_local: bool = true
	if player != null and "is_local_player" in player:
		is_local = bool(player.is_local_player)

	if is_local and is_inside_tree():
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr != null and net_mgr.has_method("is_client") and net_mgr.is_client():
			var client_obj = net_mgr.get("client")
			if client_obj != null and "assigned_tasks" in client_obj:
				var eff_type = get_effective_task_type_id()
				for t in client_obj.assigned_tasks:
					if not bool(t.get("is_completed", false)):
						var t_type = str(t.get("task_type_id", ""))
						var t_id = str(t.get("task_id", ""))
						if t_type == eff_type or t_type == objective_id or t_id == objective_id:
							print("[ObjectiveInteractable] Dispatching server completion request for task: %s (%s)" % [t_id, t_type])
							net_mgr.complete_task(t_id)
							break

	if interaction_audio != null:
		interaction_audio.play_objective_complete()

	_update_visuals_and_prompts()
	objective_completed.emit(player)
	objective_state_changed.emit(current_state)
	return true

## Locks the objective to prevent player interaction.
func lock_objective() -> void:
	if current_state == ObjectiveState.LOCKED:
		return
	current_state = ObjectiveState.LOCKED
	_update_visuals_and_prompts()
	objective_state_changed.emit(current_state)

## Unlocks a locked objective back to AVAILABLE state.
func unlock_objective() -> void:
	if current_state != ObjectiveState.LOCKED:
		return
	current_state = ObjectiveState.AVAILABLE
	_update_visuals_and_prompts()
	objective_state_changed.emit(current_state)

## Resets the objective and all its steps back to initial AVAILABLE state.
func reset_objective() -> void:
	current_state = ObjectiveState.AVAILABLE
	current_step_index = 0
	for step in task_steps:
		if step != null and "is_completed" in step:
			step.is_completed = false
	_update_visuals_and_prompts()
	objective_state_changed.emit(current_state)

## Sets the state explicitly (useful for server-authoritative synchronization).
func set_objective_state(new_state: ObjectiveState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	_update_visuals_and_prompts()
	objective_state_changed.emit(current_state)

## Returns structured metadata dictionary for the objective instance.
func get_objective_data() -> Dictionary:
	return {
		"objective_id": objective_id,
		"task_type_id": get_effective_task_type_id(),
		"objective_name": objective_name,
		"objective_description": objective_description,
		"category": category,
		"room_location": room_location,
		"state": current_state,
		"state_name": get_state_string(),
		"is_completed": current_state == ObjectiveState.COMPLETED,
		"is_locked": current_state == ObjectiveState.LOCKED,
		"has_steps": has_steps(),
		"current_step_index": current_step_index,
		"total_steps": get_total_steps(),
		"current_step": get_current_step_data()
	}

## Returns string name of the current objective state.
func get_state_string() -> String:
	match current_state:
		ObjectiveState.AVAILABLE:
			return "AVAILABLE"
		ObjectiveState.IN_PROGRESS:
			return "IN_PROGRESS"
		ObjectiveState.COMPLETED:
			return "COMPLETED"
		ObjectiveState.LOCKED:
			return "LOCKED"
		_:
			return "UNKNOWN"

## Updates prompt strings, trigger interactivity, status label, and LED colors.
func _update_visuals_and_prompts() -> void:
	var total_s = get_total_steps()

	# 1. Update InteractableTrigger prompt text and active state
	if trigger != null:
		match current_state:
			ObjectiveState.AVAILABLE:
				if has_steps():
					var s0 = task_steps[0]
					var s0_name = s0.step_name if s0 != null and "step_name" in s0 else ""
					var prompt = "Step 1/%d: %s [Press E]" % [total_s, s0_name]
					trigger.prompt_text = prompt
					trigger.set_prompt(prompt)
				else:
					trigger.prompt_text = prompt_text_available
					trigger.set_prompt(prompt_text_available)
				trigger.set_interactive(true)

			ObjectiveState.IN_PROGRESS:
				if has_steps():
					var curr = get_current_step()
					var curr_name = curr.step_name if curr != null and "step_name" in curr else ""
					var prompt = "Step %d/%d: %s [Press E]" % [current_step_index + 1, total_s, curr_name]
					trigger.prompt_text = prompt
					trigger.set_prompt(prompt)
				else:
					trigger.prompt_text = prompt_text_in_progress
					trigger.set_prompt(prompt_text_in_progress)
				trigger.set_interactive(true)

			ObjectiveState.COMPLETED:
				trigger.prompt_text = prompt_text_completed
				trigger.set_prompt(prompt_text_completed)
				trigger.set_interactive(false)

			ObjectiveState.LOCKED:
				trigger.prompt_text = prompt_text_locked
				trigger.set_prompt(prompt_text_locked)
				trigger.set_interactive(false)

	# 2. Update Status Label
	if status_label != null:
		match current_state:
			ObjectiveState.AVAILABLE:
				if has_steps():
					var s0 = task_steps[0] as TaskStep
					var s0_name = s0.step_name if s0 != null else ""
					status_label.text = "OBJECTIVE: %s\nSTATUS: AVAILABLE (Step 1/%d: %s)" % [objective_name, total_s, s0_name]
				else:
					status_label.text = "OBJECTIVE: %s\nSTATUS: AVAILABLE" % objective_name
				status_label.set("theme_override_colors/font_color", Color(0.95, 0.75, 0.2, 1.0))

			ObjectiveState.IN_PROGRESS:
				if has_steps():
					var curr = get_current_step()
					var curr_name = curr.step_name if curr != null else ""
					status_label.text = "OBJECTIVE: %s\nSTATUS: IN PROGRESS (Step %d/%d: %s)" % [objective_name, current_step_index + 1, total_s, curr_name]
				else:
					status_label.text = "OBJECTIVE: %s\nSTATUS: IN PROGRESS" % objective_name
				status_label.set("theme_override_colors/font_color", Color(0.3, 0.8, 1.0, 1.0))

			ObjectiveState.COMPLETED:
				status_label.text = "OBJECTIVE: %s\nSTATUS: COMPLETED" % objective_name
				status_label.set("theme_override_colors/font_color", Color(0.2, 0.9, 0.4, 1.0))

			ObjectiveState.LOCKED:
				status_label.text = "OBJECTIVE: %s\nSTATUS: LOCKED" % objective_name
				status_label.set("theme_override_colors/font_color", Color(0.85, 0.3, 0.3, 1.0))

	# 3. Update Visual Indicator Light
	if indicator_light != null:
		match current_state:
			ObjectiveState.AVAILABLE:
				indicator_light.color = Color(0.95, 0.7, 0.15, 1.0) # Amber standby
			ObjectiveState.IN_PROGRESS:
				indicator_light.color = Color(0.2, 0.75, 1.0, 1.0) # Active cyan
			ObjectiveState.COMPLETED:
				indicator_light.color = Color(0.18, 0.88, 0.38, 1.0) # Confirmed green
			ObjectiveState.LOCKED:
				indicator_light.color = Color(0.88, 0.22, 0.22, 1.0) # Locked red
