class_name ObjectiveTracker
extends PanelContainer

## In-Game Objective Tracker HUD Component for BLACKOUT.
## Displays the local player's active facility tasks, room locations, sequential step progress,
## and overall completion counter.
## Connects event-driven to ObjectiveInteractable state and step change signals without polling.
## Features a clean dark sci-fi glassmorphic styling suitable for Asterion Research Facility.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

const ObjectiveInteractable = preload("res://client/objectives/objective_interactable.gd")

## Array of actively tracked ObjectiveInteractable instances.
var tracked_objectives: Array[ObjectiveInteractable] = []

## UI element cache mapping: { objective_id: String -> Dictionary of UI node references }
var task_row_nodes: Dictionary = {}

@onready var task_list_container: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/TaskListContainer")
@onready var progress_label: Label = get_node_or_null("MarginContainer/VBoxContainer/FooterContainer/ProgressLabel")
@onready var empty_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TaskListContainer/EmptyLabel")

func _ready() -> void:
	_ensure_ui_structure()
	_auto_discover_objectives()
	update_tracker()

## Automatically discovers all ObjectiveInteractable instances in the active scene tree.
func _auto_discover_objectives() -> void:
	if not is_inside_tree():
		return

	var objectives = get_tree().get_nodes_in_group("objective_interactable")
	for node in objectives:
		if node is ObjectiveInteractable:
			register_objective(node)

	# If no objectives were discovered via group (e.g. before ready completes on descendants),
	# perform a fallback recursive search from the root scene.
	if tracked_objectives.is_empty():
		var root = get_tree().current_scene if get_tree().current_scene != null else get_parent()
		if root != null:
			_discover_recursive(root)

## Helper to search for ObjectiveInteractable nodes recursively.
func _discover_recursive(node: Node) -> void:
	if node is ObjectiveInteractable:
		register_objective(node)
	for child in node.get_children():
		_discover_recursive(child)

## Registers a new ObjectiveInteractable instance to be tracked on the HUD.
func register_objective(obj: ObjectiveInteractable) -> void:
	if obj == null or tracked_objectives.has(obj):
		return

	tracked_objectives.append(obj)

	# Connect event-driven state and step change signals
	if not obj.objective_state_changed.is_connected(_on_objective_state_changed):
		obj.objective_state_changed.connect(_on_objective_state_changed.bind(obj))
	if not obj.task_step_changed.is_connected(_on_task_step_changed):
		obj.task_step_changed.connect(_on_task_step_changed.bind(obj))
	if not obj.task_step_completed.is_connected(_on_task_step_completed):
		obj.task_step_completed.connect(_on_task_step_completed.bind(obj))

	_create_or_update_task_row(obj)
	_update_progress_summary()

## Unregisters an ObjectiveInteractable instance from tracking.
func unregister_objective(obj: ObjectiveInteractable) -> void:
	if obj == null or not tracked_objectives.has(obj):
		return

	if obj.objective_state_changed.is_connected(_on_objective_state_changed):
		obj.objective_state_changed.disconnect(_on_objective_state_changed)
	if obj.task_step_changed.is_connected(_on_task_step_changed):
		obj.task_step_changed.disconnect(_on_task_step_changed)
	if obj.task_step_completed.is_connected(_on_task_step_completed):
		obj.task_step_completed.disconnect(_on_task_step_completed)

	tracked_objectives.erase(obj)

	if task_row_nodes.has(obj.objective_id):
		var row = task_row_nodes[obj.objective_id].get("root")
		if is_instance_valid(row):
			row.queue_free()
		task_row_nodes.erase(obj.objective_id)

	_update_progress_summary()

## Clears all tracked objectives from the HUD.
func clear_objectives() -> void:
	for obj in tracked_objectives:
		if is_instance_valid(obj):
			if obj.objective_state_changed.is_connected(_on_objective_state_changed):
				obj.objective_state_changed.disconnect(_on_objective_state_changed)
			if obj.task_step_changed.is_connected(_on_task_step_changed):
				obj.task_step_changed.disconnect(_on_task_step_changed)
			if obj.task_step_completed.is_connected(_on_task_step_completed):
				obj.task_step_completed.disconnect(_on_task_step_completed)

	tracked_objectives.clear()
	for row_data in task_row_nodes.values():
		var row = row_data.get("root")
		if is_instance_valid(row):
			row.queue_free()
	task_row_nodes.clear()

	_update_progress_summary()

## Event-driven callback fired when any tracked ObjectiveInteractable changes lifecycle state.
func _on_objective_state_changed(_new_state: ObjectiveInteractable.ObjectiveState, obj: ObjectiveInteractable) -> void:
	if obj != null:
		_create_or_update_task_row(obj)
		_update_progress_summary()

## Event-driven callback fired when a multi-step task step changes.
func _on_task_step_changed(_curr_step: int, _total_steps: int, _step_data: Dictionary, obj: ObjectiveInteractable) -> void:
	if obj != null:
		_create_or_update_task_row(obj)
		_update_progress_summary()

## Event-driven callback fired when an individual task step is completed.
func _on_task_step_completed(_step_idx: int, _step_data: Dictionary, _player: Node2D, obj: ObjectiveInteractable) -> void:
	if obj != null:
		_create_or_update_task_row(obj)
		_update_progress_summary()

## Refreshes all active task rows and progress counters.
func update_tracker() -> void:
	_ensure_ui_structure()

	for obj in tracked_objectives:
		if is_instance_valid(obj):
			_create_or_update_task_row(obj)

	_update_progress_summary()

## Creates or updates the UI row for an individual objective.
func _create_or_update_task_row(obj: ObjectiveInteractable) -> void:
	if task_list_container == null or obj == null:
		return

	var row_info: Dictionary
	if task_row_nodes.has(obj.objective_id) and is_instance_valid(task_row_nodes[obj.objective_id].get("root")):
		row_info = task_row_nodes[obj.objective_id]
	else:
		row_info = _build_task_row_ui(obj)
		task_row_nodes[obj.objective_id] = row_info
		task_list_container.add_child(row_info["root"])

	var icon_label: Label = row_info["icon_label"]
	var name_label: Label = row_info["name_label"]
	var loc_label: Label = row_info["loc_label"]

	var base_loc = obj.room_location if not obj.room_location.is_empty() else "Facility"

	# Format state icon, text, and colors based on current objective state and step progression
	match obj.current_state:
		ObjectiveInteractable.ObjectiveState.AVAILABLE:
			icon_label.text = "☐"
			icon_label.set("theme_override_colors/font_color", Color(0.9, 0.93, 0.96, 1.0))
			name_label.text = obj.objective_name
			name_label.set("theme_override_colors/font_color", Color(0.9, 0.93, 0.96, 1.0))
			if obj.has_steps():
				loc_label.text = "%s (Step 1/%d)" % [base_loc, obj.get_total_steps()]
			else:
				loc_label.text = base_loc
			loc_label.set("theme_override_colors/font_color", Color(0.65, 0.72, 0.8, 0.85))

		ObjectiveInteractable.ObjectiveState.IN_PROGRESS:
			icon_label.text = "◐"
			icon_label.set("theme_override_colors/font_color", Color(0.3, 0.85, 1.0, 1.0))
			name_label.text = obj.objective_name
			name_label.set("theme_override_colors/font_color", Color(0.3, 0.85, 1.0, 1.0))
			if obj.has_steps():
				var curr_step = obj.get_current_step()
				var step_num = obj.current_step_index + 1
				var step_name_str = curr_step.step_name if curr_step != null else "Progress"
				loc_label.text = "%s — Step %d/%d: %s" % [base_loc, step_num, obj.get_total_steps(), step_name_str]
			else:
				loc_label.text = "%s (In Progress)" % base_loc
			loc_label.set("theme_override_colors/font_color", Color(0.5, 0.8, 0.9, 0.85))

		ObjectiveInteractable.ObjectiveState.COMPLETED:
			icon_label.text = "☑"
			icon_label.set("theme_override_colors/font_color", Color(0.25, 0.9, 0.45, 1.0))
			name_label.text = obj.objective_name
			name_label.set("theme_override_colors/font_color", Color(0.55, 0.78, 0.62, 0.9))
			loc_label.text = "%s — Repaired" % base_loc
			loc_label.set("theme_override_colors/font_color", Color(0.4, 0.65, 0.48, 0.75))

		ObjectiveInteractable.ObjectiveState.LOCKED:
			icon_label.text = "🔒"
			icon_label.set("theme_override_colors/font_color", Color(0.85, 0.35, 0.35, 1.0))
			name_label.text = obj.objective_name
			name_label.set("theme_override_colors/font_color", Color(0.75, 0.45, 0.45, 0.85))
			loc_label.text = "%s (Locked)" % base_loc
			loc_label.set("theme_override_colors/font_color", Color(0.65, 0.4, 0.4, 0.75))

## Updates the completion progress footer (e.g. 'Completed: 1/3').
## Note: Progress count strictly reflects completed whole objectives, not intermediate steps.
func _update_progress_summary() -> void:
	var total_count: int = tracked_objectives.size()
	var completed_count: int = 0

	for obj in tracked_objectives:
		if is_instance_valid(obj) and obj.current_state == ObjectiveInteractable.ObjectiveState.COMPLETED:
			completed_count += 1

	if empty_label != null:
		empty_label.visible = (total_count == 0)

	if progress_label != null:
		progress_label.text = "Completed: %d/%d" % [completed_count, total_count]
		if total_count > 0 and completed_count == total_count:
			progress_label.set("theme_override_colors/font_color", Color(0.25, 0.9, 0.45, 1.0))
		else:
			progress_label.set("theme_override_colors/font_color", Color(0.7, 0.8, 0.9, 0.85))

## Constructs the UI sub-nodes for a single objective row.
func _build_task_row_ui(obj: ObjectiveInteractable) -> Dictionary:
	var row_vbox := VBoxContainer.new()
	row_vbox.name = "Row_%s" % obj.objective_id
	row_vbox.add_theme_constant_override("separation", 2)

	# Top line: [Icon] [Name]
	var top_hbox := HBoxContainer.new()
	top_hbox.name = "TopLine"
	top_hbox.add_theme_constant_override("separation", 6)
	row_vbox.add_child(top_hbox)

	var icon_label := Label.new()
	icon_label.name = "IconLabel"
	icon_label.text = "☐"
	icon_label.add_theme_font_size_override("font_size", 13)
	top_hbox.add_child(icon_label)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = obj.objective_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(name_label)

	# Bottom line: [Indentation] [Room Location & Step Details]
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.name = "BottomLine"
	bottom_hbox.add_theme_constant_override("separation", 6)
	row_vbox.add_child(bottom_hbox)

	var indent_spacer := Control.new()
	indent_spacer.custom_minimum_size = Vector2(16, 0)
	bottom_hbox.add_child(indent_spacer)

	var loc_label := Label.new()
	loc_label.name = "LocLabel"
	loc_label.text = obj.room_location if not obj.room_location.is_empty() else "Facility"
	loc_label.add_theme_font_size_override("font_size", 11)
	bottom_hbox.add_child(loc_label)

	return {
		"root": row_vbox,
		"icon_label": icon_label,
		"name_label": name_label,
		"loc_label": loc_label
	}

## Ensures the base UI hierarchy and styles are present.
func _ensure_ui_structure() -> void:
	if task_list_container == null:
		var margin = get_node_or_null("MarginContainer")
		if margin == null:
			margin = MarginContainer.new()
			margin.name = "MarginContainer"
			margin.add_theme_constant_override("margin_left", 12)
			margin.add_theme_constant_override("margin_top", 10)
			margin.add_theme_constant_override("margin_right", 12)
			margin.add_theme_constant_override("margin_bottom", 10)
			add_child(margin)

		var main_vbox = margin.get_node_or_null("VBoxContainer")
		if main_vbox == null:
			main_vbox = VBoxContainer.new()
			main_vbox.name = "VBoxContainer"
			main_vbox.add_theme_constant_override("separation", 8)
			margin.add_child(main_vbox)

		var header_label = main_vbox.get_node_or_null("HeaderLabel")
		if header_label == null:
			header_label = Label.new()
			header_label.name = "HeaderLabel"
			header_label.text = "TASKS"
			header_label.add_theme_font_size_override("font_size", 14)
			header_label.set("theme_override_colors/font_color", Color(0.3, 0.85, 1.0, 1.0))
			main_vbox.add_child(header_label)

		var sep_top = HSeparator.new()
		main_vbox.add_child(sep_top)

		task_list_container = main_vbox.get_node_or_null("TaskListContainer")
		if task_list_container == null:
			task_list_container = VBoxContainer.new()
			task_list_container.name = "TaskListContainer"
			task_list_container.add_theme_constant_override("separation", 6)
			main_vbox.add_child(task_list_container)

		if empty_label == null:
			empty_label = Label.new()
			empty_label.name = "EmptyLabel"
			empty_label.text = "No active objectives."
			empty_label.add_theme_font_size_override("font_size", 11)
			empty_label.set("theme_override_colors/font_color", Color(0.6, 0.65, 0.7, 0.7))
			empty_label.visible = false
			task_list_container.add_child(empty_label)

		var sep_bottom = HSeparator.new()
		main_vbox.add_child(sep_bottom)

		var footer = main_vbox.get_node_or_null("FooterContainer")
		if footer == null:
			footer = VBoxContainer.new()
			footer.name = "FooterContainer"
			main_vbox.add_child(footer)

		progress_label = footer.get_node_or_null("ProgressLabel")
		if progress_label == null:
			progress_label = Label.new()
			progress_label.name = "ProgressLabel"
			progress_label.text = "Completed: 0/0"
			progress_label.add_theme_font_size_override("font_size", 12)
			progress_label.set("theme_override_colors/font_color", Color(0.7, 0.8, 0.9, 0.85))
			footer.add_child(progress_label)
