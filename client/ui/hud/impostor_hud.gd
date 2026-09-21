class_name ImpostorHUD
extends Control

## ImpostorHUD — Member 5 (UI/UX Frontend)
## Impostor-exclusive HUD overlay for BLACKOUT.
##
## Includes:
## 1. 'BLACKOUT READY [ACTIVATE]' remote trigger control
## 2. Hidden Objective Checklist
## 3. Interactive Sabotage Action Wheel
##
## STRICT RULE: Only visible to the Impostor. Hidden completely for Crew players.

const NetworkConfig = preload("res://shared/network_config.gd")
const BlackoutObjectiveConfig = preload("res://shared/blackout_objective_config.gd")

## Styling constants
const COLOR_IMPOSTOR_RED: Color = Color(1.0, 0.28, 0.30, 1.0)       # Impostor crimson (#FF474D)
const COLOR_IMPOSTOR_DIM: Color = Color(0.48, 0.52, 0.58, 0.70)       # Completed slate
const COLOR_OBJECTIVE_DONE: Color = Color(0.20, 0.85, 0.40, 1.0)     # Green check (#33D966)
const COLOR_OBJECTIVE_TODO: Color = Color(0.92, 0.94, 0.96, 0.95)     # Crisp objective white
const COLOR_DISABLED: Color = Color(0.55, 0.58, 0.65, 0.60)           # Disabled button state
const COLOR_HOVER: Color = Color(1.0, 0.45, 0.45, 1.0)                # Interactive hover

## Node references
@onready var objectives_panel: PanelContainer = $ObjectivesPanel
@onready var objectives_list_container: VBoxContainer = $ObjectivesPanel/MarginContainer/VBoxContainer/ObjectivesListContainer
@onready var objectives_progress_label: Label = $ObjectivesPanel/MarginContainer/VBoxContainer/HeaderContainer/ProgressLabel

@onready var blackout_trigger_panel: PanelContainer = $BlackoutTriggerPanel
@onready var blackout_status_label: Label = $BlackoutTriggerPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var activate_button: Button = $BlackoutTriggerPanel/MarginContainer/VBoxContainer/ActivateButton

@onready var sabotage_button: Button = $SabotageButton
@onready var sabotage_wheel: Control = $SabotageWheel
@onready var wheel_options_container: Control = $SabotageWheel/WheelCenter

## Internal state
var _is_impostor: bool = false
var _is_blackout_unlocked: bool = false
var _is_blackout_active: bool = false
var _objectives: Array = []
var _sabotage_actions: Array = []
var _is_wheel_open: bool = false
var _is_connected_to_network: bool = false

func _ready() -> void:
	_ensure_node_references()
	_init_sabotage_catalog()
	_connect_to_network_events()
	
	if activate_button != null:
		activate_button.pressed.connect(_on_activate_button_pressed)
	if sabotage_button != null:
		sabotage_button.pressed.connect(toggle_sabotage_wheel)
		
	# Check initial role visibility
	_update_role_visibility()
	
	if not _is_connected_to_server():
		# Standalone preview: simulate Impostor role with preview data
		_populate_offline_preview()

func _ensure_node_references() -> void:
	if objectives_panel == null:
		objectives_panel = get_node_or_null("ObjectivesPanel")
	if objectives_list_container == null:
		objectives_list_container = get_node_or_null("ObjectivesPanel/MarginContainer/VBoxContainer/ObjectivesListContainer")
	if objectives_progress_label == null:
		objectives_progress_label = get_node_or_null("ObjectivesPanel/MarginContainer/VBoxContainer/HeaderContainer/ProgressLabel")
	if blackout_trigger_panel == null:
		blackout_trigger_panel = get_node_or_null("BlackoutTriggerPanel")
	if blackout_status_label == null:
		blackout_status_label = get_node_or_null("BlackoutTriggerPanel/MarginContainer/VBoxContainer/StatusLabel")
	if activate_button == null:
		activate_button = get_node_or_null("BlackoutTriggerPanel/MarginContainer/VBoxContainer/ActivateButton")
	if sabotage_button == null:
		sabotage_button = get_node_or_null("SabotageButton")
	if sabotage_wheel == null:
		sabotage_wheel = get_node_or_null("SabotageWheel")
	if wheel_options_container == null:
		wheel_options_container = get_node_or_null("SabotageWheel/WheelCenter")


func _init_sabotage_catalog() -> void:
	# Standard facility sabotage targets matching game design
	_sabotage_actions = [
		{"id": "sabotage_generator", "name": "Generator", "icon": "⚡", "location": "Generator Room", "cooldown": 0.0},
		{"id": "extract_orion_core_data", "name": "ORION Core", "icon": "⚛", "location": "ORION Core", "cooldown": 0.0},
		{"id": "tamper_security", "name": "Security Cameras", "icon": "👁", "location": "Security Room", "cooldown": 0.0},
		{"id": "disable_orion_containment", "name": "Containment", "icon": "☣", "location": "Containment Hub", "cooldown": 0.0},
		{"id": "steal_confidential_files", "name": "Classified Files", "icon": "📁", "location": "Executive Office", "cooldown": 0.0}
	]
	_build_sabotage_wheel()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _is_impostor:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB or event.keycode == KEY_E:
			toggle_sabotage_wheel()
		elif event.keycode == KEY_ESCAPE and _is_wheel_open:
			close_sabotage_wheel()
		elif not _is_connected_to_server():
			# Offline preview hotkeys
			if event.keycode == KEY_O:
				_cycle_offline_objectives()
			elif event.keycode == KEY_K:
				_toggle_offline_blackout_ready()

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
			if client.has_signal("role_assigned") and not client.role_assigned.is_connected(_on_role_assigned):
				client.role_assigned.connect(_on_role_assigned)
			if client.has_signal("blackout_unlocked_for_impostor") and not client.blackout_unlocked_for_impostor.is_connected(_on_blackout_unlocked):
				client.blackout_unlocked_for_impostor.connect(_on_blackout_unlocked)
			if client.has_signal("blackout_started") and not client.blackout_started.is_connected(_on_blackout_started):
				client.blackout_started.connect(_on_blackout_started)
			if client.has_signal("blackout_ended") and not client.blackout_ended.is_connected(_on_blackout_ended):
				client.blackout_ended.connect(_on_blackout_ended)
			if client.has_signal("impostor_objective_list_received") and not client.impostor_objective_list_received.is_connected(_on_impostor_objective_list_received):
				client.impostor_objective_list_received.connect(_on_impostor_objective_list_received)
			if client.has_signal("impostor_objective_updated") and not client.impostor_objective_updated.is_connected(_on_impostor_objective_updated):
				client.impostor_objective_updated.connect(_on_impostor_objective_updated)
			if client.has_signal("game_state_changed") and not client.game_state_changed.is_connected(_on_game_state_changed):
				client.game_state_changed.connect(_on_game_state_changed)
			_is_connected_to_network = true
			
			if _is_connected_to_server():
				_is_impostor = (client.assigned_role == NetworkConfig.PlayerRole.IMPOSTOR)
				_is_blackout_unlocked = client.is_blackout_unlocked
				_is_blackout_active = client.is_blackout_active
				if not client.assigned_blackout_objectives.is_empty():
					set_objectives(client.assigned_blackout_objectives)
				_update_role_visibility()
				_update_blackout_trigger_ui()

func _on_role_assigned(role: NetworkConfig.PlayerRole) -> void:
	_is_impostor = (role == NetworkConfig.PlayerRole.IMPOSTOR)
	_update_role_visibility()

func _on_blackout_unlocked() -> void:
	_is_blackout_unlocked = true
	_update_blackout_trigger_ui()

func _on_blackout_started(_duration: float) -> void:
	_is_blackout_active = true
	_is_blackout_unlocked = false
	_update_blackout_trigger_ui()

func _on_blackout_ended() -> void:
	_is_blackout_active = false
	_update_blackout_trigger_ui()

func _on_impostor_objective_list_received(objectives_data: Array) -> void:
	set_objectives(objectives_data)

func _on_impostor_objective_updated(objective_id: String, is_completed: bool) -> void:
	update_objective_status(objective_id, is_completed)

func _on_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	if new_state == NetworkConfig.GameState.BLACKOUT_AVAILABLE:
		_is_blackout_unlocked = true
	elif new_state == NetworkConfig.GameState.BLACKOUT_ACTIVE:
		_is_blackout_active = true
		_is_blackout_unlocked = false
	elif new_state == NetworkConfig.GameState.LOBBY or new_state == NetworkConfig.GameState.ROLE_ASSIGNMENT:
		_is_blackout_unlocked = false
		_is_blackout_active = false
	_update_blackout_trigger_ui()

func _update_role_visibility() -> void:
	# STRICT SECURITY: Hide entire Impostor HUD if player is Crew
	visible = _is_impostor
	if not _is_impostor:
		close_sabotage_wheel()

## Public API to populate/update hidden objectives
func set_objectives(objectives_array: Array) -> void:
	_objectives.clear()
	for obj in objectives_array:
		if obj is Dictionary:
			_objectives.append(obj.duplicate())
		elif obj != null and obj.has_method("to_dict"):
			_objectives.append(obj.to_dict())
	_rebuild_objectives_ui()

## Public API to update status of a single objective
func update_objective_status(objective_id: String, is_completed: bool) -> void:
	for obj in _objectives:
		if str(obj.get("objective_id", "")) == objective_id:
			obj["is_completed"] = is_completed
			break
	_rebuild_objectives_ui()

## Public API to set Blackout unlock state
func set_blackout_unlocked(is_unlocked: bool) -> void:
	_is_blackout_unlocked = is_unlocked
	_update_blackout_trigger_ui()

## Rebuilds the hidden objectives checklist rows
func _rebuild_objectives_ui() -> void:
	_ensure_node_references()
	if objectives_list_container == null:
		return
		
	for child in objectives_list_container.get_children():
		objectives_list_container.remove_child(child)
		child.queue_free()
		
	var completed_count: int = 0
	var total_count: int = _objectives.size()
	
	for obj in _objectives:
		var is_done = bool(obj.get("is_completed", false))
		if is_done:
			completed_count += 1
		var name_text = str(obj.get("display_name", ""))
		if name_text.is_empty():
			name_text = str(obj.get("objective_id", "Unknown Objective")).capitalize()
			
		var row = _create_objective_row(name_text, is_done)
		objectives_list_container.add_child(row)
		
	if objectives_progress_label != null:
		if total_count > 0:
			objectives_progress_label.text = "%d/%d" % [completed_count, total_count]
			if completed_count >= total_count:
				objectives_progress_label.add_theme_color_override("font_color", COLOR_OBJECTIVE_DONE)
			else:
				objectives_progress_label.add_theme_color_override("font_color", COLOR_IMPOSTOR_RED)
		else:
			objectives_progress_label.text = ""

func _create_objective_row(objective_name: String, is_completed: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	
	var bullet_label = Label.new()
	bullet_label.text = "✓" if is_completed else "□"
	bullet_label.custom_minimum_size = Vector2(14, 0)
	bullet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bullet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bullet_label.add_theme_font_size_override("font_size", 12)
	bullet_label.add_theme_color_override("font_color", COLOR_OBJECTIVE_DONE if is_completed else COLOR_IMPOSTOR_RED)
	bullet_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	bullet_label.add_theme_constant_override("shadow_offset_x", 1)
	bullet_label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(bullet_label)
	
	var name_label = Label.new()
	name_label.text = objective_name
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", COLOR_IMPOSTOR_DIM if is_completed else COLOR_OBJECTIVE_TODO)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(name_label)
	
	return row

## Updates Blackout trigger button and status text
func _update_blackout_trigger_ui() -> void:
	_ensure_node_references()
	if blackout_status_label == null or activate_button == null:
		return
		
	if _is_blackout_active:
		blackout_status_label.text = "BLACKOUT IN PROGRESS"
		blackout_status_label.add_theme_color_override("font_color", COLOR_IMPOSTOR_RED)
		activate_button.disabled = true
		activate_button.text = "ACTIVE"
	elif _is_blackout_unlocked:
		blackout_status_label.text = "BLACKOUT READY"
		blackout_status_label.add_theme_color_override("font_color", COLOR_IMPOSTOR_RED)
		activate_button.disabled = false
		activate_button.text = "ACTIVATE"
	else:
		blackout_status_label.text = "BLACKOUT LOCKED"
		blackout_status_label.add_theme_color_override("font_color", COLOR_DISABLED)
		activate_button.disabled = true
		activate_button.text = "LOCKED"

func _on_activate_button_pressed() -> void:
	if not _is_impostor or not _is_blackout_unlocked or _is_blackout_active:
		return
		
	print("[IMPOSTOR HUD] Activate Blackout trigger clicked!")
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			net_mgr.client.request_activate_blackout()
			
	# Update local state immediately for instant feedback
	_is_blackout_unlocked = false
	_is_blackout_active = true
	_update_blackout_trigger_ui()

## -----------------------------------------------------------------------------
## Sabotage Action Wheel
## -----------------------------------------------------------------------------
func toggle_sabotage_wheel() -> void:
	if not _is_impostor:
		return
	if _is_wheel_open:
		close_sabotage_wheel()
	else:
		open_sabotage_wheel()

func open_sabotage_wheel() -> void:
	_ensure_node_references()
	if sabotage_wheel == null:
		return
	if wheel_options_container != null and wheel_options_container.get_child_count() == 0:
		_build_sabotage_wheel()
	_is_wheel_open = true
	sabotage_wheel.visible = true
	sabotage_wheel.modulate.a = 1.0

func close_sabotage_wheel() -> void:
	_is_wheel_open = false
	if sabotage_wheel != null:
		sabotage_wheel.visible = false

func _build_sabotage_wheel() -> void:
	_ensure_node_references()
	if wheel_options_container == null:
		return
		
	for child in wheel_options_container.get_children():
		wheel_options_container.remove_child(child)
		child.queue_free()
		
	if _sabotage_actions.is_empty():
		_init_sabotage_catalog()
		return
		
	var count = _sabotage_actions.size()
	var radius = 110.0
	
	for i in range(count):
		var action = _sabotage_actions[i]
		var angle = (float(i) / float(count)) * TAU - (PI * 0.5)
		var pos = Vector2(cos(angle), sin(angle)) * radius
		
		var btn = Button.new()
		btn.text = "%s\n%s" % [str(action.get("icon", "⚡")), str(action.get("name", ""))]
		btn.custom_minimum_size = Vector2(80, 52)
		btn.size = Vector2(80, 52)
		btn.position = pos - Vector2(40, 26)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Styling
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", COLOR_OBJECTIVE_TODO)
		btn.add_theme_color_override("font_hover_color", COLOR_HOVER)
		
		var wheel_btn_normal = StyleBoxFlat.new()
		wheel_btn_normal.bg_color = Color(0.08, 0.085, 0.10, 0.95)
		wheel_btn_normal.set_border_width_all(1)
		wheel_btn_normal.border_color = Color(1.0, 0.28, 0.28, 0.55)
		wheel_btn_normal.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", wheel_btn_normal)
		
		var wheel_btn_hover = StyleBoxFlat.new()
		wheel_btn_hover.bg_color = Color(0.22, 0.08, 0.09, 0.95)
		wheel_btn_hover.set_border_width_all(1)
		wheel_btn_hover.border_color = Color(1.0, 0.5, 0.5, 1.0)
		wheel_btn_hover.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("hover", wheel_btn_hover)
		
		var act_id = str(action.get("id", ""))
		btn.pressed.connect(func(): _on_sabotage_selected(act_id))
		wheel_options_container.add_child(btn)

func _on_sabotage_selected(action_id: String) -> void:
	print("[IMPOSTOR HUD] Sabotage action selected: %s" % action_id)
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			net_mgr.client.request_complete_impostor_objective(action_id)
			
	close_sabotage_wheel()

## Standalone preview helpers
func _populate_offline_preview() -> void:
	_is_impostor = true
	_is_blackout_unlocked = true
	_is_blackout_active = false
	visible = true
	
	var sample_objs = [
		{"objective_id": "steal_confidential_files", "display_name": "Steal Confidential Files", "is_completed": false},
		{"objective_id": "extract_orion_core_data", "display_name": "Extract ORION Core Data", "is_completed": true},
		{"objective_id": "sabotage_generator", "display_name": "Sabotage Generator", "is_completed": false}
	]
	set_objectives(sample_objs)
	_update_blackout_trigger_ui()

func _cycle_offline_objectives() -> void:
	for obj in _objectives:
		if not bool(obj.get("is_completed", false)):
			obj["is_completed"] = true
			_rebuild_objectives_ui()
			return
	for obj in _objectives:
		obj["is_completed"] = false
	_rebuild_objectives_ui()

func _toggle_offline_blackout_ready() -> void:
	_is_blackout_unlocked = not _is_blackout_unlocked
	_is_blackout_active = false
	_update_blackout_trigger_ui()
