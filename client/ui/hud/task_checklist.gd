class_name TaskChecklistUI
extends Control

## TaskChecklistUI — Member 5 (UI/UX Frontend)
## Minimal, unobtrusive in-game task checklist HUD for BLACKOUT.
##
## Styled with the unified dark slate / charcoal sci-fi design system:
## - Dark slate container with 1px border and 8px corner radius
## - Red accent pill header with right-aligned progress counter
## - Clean task status rows with green checkmarks and subtle card hierarchy

const NetworkConfig = preload("res://shared/network_config.gd")
const TaskConfig = preload("res://shared/task_config.gd")

## Styling constants
const COLOR_TITLE: Color = Color(0.95, 0.95, 0.98, 1.0)              # Header white
const COLOR_PROGRESS_DONE: Color = Color(0.20, 0.85, 0.40, 1.0)       # Progress complete green
const COLOR_PROGRESS_PENDING: Color = Color(0.65, 0.68, 0.75, 0.85)   # Progress pending slate
const COLOR_TASK_INCOMPLETE: Color = Color(0.92, 0.94, 0.96, 0.95)   # Incomplete task text
const COLOR_TASK_COMPLETED: Color = Color(0.48, 0.52, 0.58, 0.70)    # Completed task text
const COLOR_CHECK_DONE: Color = Color(0.20, 0.85, 0.40, 1.0)         # Green check
const COLOR_CHECK_PENDING: Color = Color(0.45, 0.48, 0.55, 0.75)     # Neutral circle

## Node references
@onready var panel_container: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var progress_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/ProgressLabel
@onready var task_list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/TaskListContainer

## Task state storage (Array of Dictionaries)
var _tasks: Array = []
var _is_connected_to_network: bool = false

func _ready() -> void:
	_ensure_node_references()
	_connect_to_network_events()
	
	if not _is_connected_to_server() and _tasks.is_empty():
		_populate_offline_preview()

func _ensure_node_references() -> void:
	if panel_container == null and has_node("PanelContainer"):
		panel_container = get_node("PanelContainer")
	if title_label == null and has_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel"):
		title_label = get_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel")
	if progress_label == null and has_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/ProgressLabel"):
		progress_label = get_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/ProgressLabel")
	if task_list_container == null and has_node("PanelContainer/MarginContainer/VBoxContainer/TaskListContainer"):
		task_list_container = get_node("PanelContainer/MarginContainer/VBoxContainer/TaskListContainer")

func _unhandled_input(event: InputEvent) -> void:
	if not _is_connected_to_server() and event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_toggle_next_offline_task()
		elif event.keycode == KEY_R:
			_populate_offline_preview()

func _is_connected_to_server() -> bool:
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			return net_mgr.client.is_connected_to_server()
	return false

func _connect_to_network_events() -> void:
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			var client = net_mgr.client
			if client.has_signal("task_list_received") and not client.task_list_received.is_connected(_on_task_list_received):
				client.task_list_received.connect(_on_task_list_received)
			if client.has_signal("task_completed_locally") and not client.task_completed_locally.is_connected(_on_task_completed_locally):
				client.task_completed_locally.connect(_on_task_completed_locally)
			if client.has_signal("game_state_changed") and not client.game_state_changed.is_connected(_on_game_state_changed):
				client.game_state_changed.connect(_on_game_state_changed)
			_is_connected_to_network = true
			
			if not client.assigned_tasks.is_empty():
				set_tasks(client.assigned_tasks)

func _on_task_list_received(tasks: Array) -> void:
	set_tasks(tasks)

func _on_task_completed_locally(task_id: String) -> void:
	update_task_status(task_id, true)

func _on_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	match new_state:
		NetworkConfig.GameState.INITIAL_TASK_PHASE, \
		NetworkConfig.GameState.BLACKOUT_AVAILABLE, \
		NetworkConfig.GameState.BLACKOUT_ACTIVE, \
		NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION, \
		NetworkConfig.GameState.MELTDOWN:
			visible = true
		NetworkConfig.GameState.LOBBY, \
		NetworkConfig.GameState.ROLE_ASSIGNMENT, \
		NetworkConfig.GameState.MEETING, \
		NetworkConfig.GameState.VOTING, \
		NetworkConfig.GameState.GAME_OVER:
			visible = true

## Public API to populate/replace the task list
func set_tasks(task_array: Array) -> void:
	_tasks.clear()
	for t in task_array:
		if t is Dictionary:
			_tasks.append(t.duplicate())
		elif t != null and t.has_method("to_dict"):
			_tasks.append(t.to_dict())
	_rebuild_ui()

## Public API to update a single task's completion status
func update_task_status(task_id: String, is_completed: bool) -> void:
	var found = false
	for t in _tasks:
		if str(t.get("task_id", "")) == task_id:
			t["is_completed"] = is_completed
			found = true
			break
	if found:
		_rebuild_ui()

## Clears all tasks from the checklist
func clear_tasks() -> void:
	_tasks.clear()
	_rebuild_ui()

## Rebuilds the UI rows and updates the progress indicator
func _rebuild_ui() -> void:
	_ensure_node_references()
	if task_list_container == null:
		return
		
	for child in task_list_container.get_children():
		task_list_container.remove_child(child)
		child.queue_free()
		
	var completed_count: int = 0
	var total_count: int = _tasks.size()
	
	for task in _tasks:
		var is_done = bool(task.get("is_completed", false))
		if is_done:
			completed_count += 1
			
		var name_text = str(task.get("display_name", ""))
		if name_text.is_empty():
			var type_id = str(task.get("task_type_id", ""))
			var info = TaskConfig.get_task_info(type_id)
			name_text = str(info.get("display_name", type_id.capitalize()))
			
		var row = _create_task_row(name_text, is_done)
		task_list_container.add_child(row)
		
	if progress_label != null:
		if total_count > 0:
			progress_label.text = "%d / %d" % [completed_count, total_count]
			if completed_count >= total_count:
				progress_label.add_theme_color_override("font_color", COLOR_PROGRESS_DONE)
			else:
				progress_label.add_theme_color_override("font_color", COLOR_PROGRESS_PENDING)
		else:
			progress_label.text = ""

## Creates a single task row item
func _create_task_row(task_name: String, is_completed: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	
	var bullet_label = Label.new()
	bullet_label.text = "✓" if is_completed else "○"
	bullet_label.custom_minimum_size = Vector2(16, 0)
	bullet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bullet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bullet_label.add_theme_font_size_override("font_size", 12)
	bullet_label.add_theme_color_override("font_color", COLOR_CHECK_DONE if is_completed else COLOR_CHECK_PENDING)
	bullet_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	bullet_label.add_theme_constant_override("shadow_offset_x", 1)
	bullet_label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(bullet_label)
	
	var name_label = Label.new()
	name_label.text = task_name
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", COLOR_TASK_COMPLETED if is_completed else COLOR_TASK_INCOMPLETE)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(name_label)
	
	return row

## Offline standalone sample data generator
func _populate_offline_preview() -> void:
	var sample_tasks = [
		{"task_id": "t1", "display_name": "Repair Power", "is_completed": true},
		{"task_id": "t2", "display_name": "Stabilize ORION Core", "is_completed": false},
		{"task_id": "t3", "display_name": "Server Calibration", "is_completed": false},
		{"task_id": "t4", "display_name": "Security Supply Check", "is_completed": false}
	]
	set_tasks(sample_tasks)

func _toggle_next_offline_task() -> void:
	for t in _tasks:
		if not bool(t.get("is_completed", false)):
			t["is_completed"] = true
			_rebuild_ui()
			return
	for t in _tasks:
		t["is_completed"] = false
	_rebuild_ui()
