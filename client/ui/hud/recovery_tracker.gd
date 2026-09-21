class_name RecoveryTrackerUI
extends Control

## RecoveryTrackerUI — Member 5 (UI/UX Frontend)
## Compact, unobtrusive Recovery X/Y Progress Tracker for the BLACKOUT in-game HUD.
##
## Styled with the unified dark slate / charcoal sci-fi design system:
## - Dark slate container with 1px border and 8px corner radius
## - Red accent pill header with numeric indicator and glowing progress pips

const NetworkConfig = preload("res://shared/network_config.gd")

## Styling constants
const COLOR_TITLE: Color = Color(0.95, 0.95, 0.98, 1.0)              # Header white
const COLOR_PROGRESS_DONE: Color = Color(0.20, 0.85, 0.40, 1.0)       # Success green (#33D966)
const COLOR_PROGRESS_PENDING: Color = Color(0.65, 0.68, 0.75, 0.85)   # Muted slate
const COLOR_PIP_COMPLETED: Color = Color(0.0, 0.90, 1.0, 0.95)      # Cyan active
const COLOR_PIP_COMPLETED_ALL: Color = Color(0.20, 0.85, 0.40, 1.0) # Green all done
const COLOR_PIP_INCOMPLETE: Color = Color(0.35, 0.38, 0.45, 0.65)   # Muted circle

## Node references
@onready var panel_container: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var progress_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/ProgressLabel
@onready var pips_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/PipsContainer

## State
var _completed_count: int = 0
var _total_count: int = 4
var _is_connected_to_network: bool = false

func _ready() -> void:
	_ensure_node_references()
	_connect_to_network_events()
	
	if not _is_connected_to_server():
		visible = true
		_populate_offline_preview()

func _ensure_node_references() -> void:
	if panel_container == null and has_node("PanelContainer"):
		panel_container = get_node("PanelContainer")
	if title_label == null and has_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel"):
		title_label = get_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel")
	if progress_label == null and has_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/ProgressLabel"):
		progress_label = get_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/ProgressLabel")
	if pips_container == null and has_node("PanelContainer/MarginContainer/VBoxContainer/PipsContainer"):
		pips_container = get_node("PanelContainer/MarginContainer/VBoxContainer/PipsContainer")

func _unhandled_input(event: InputEvent) -> void:
	if not _is_connected_to_server() and event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_T:
			_cycle_offline_progress()
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
			if client.has_signal("recovery_systems_initialized") and not client.recovery_systems_initialized.is_connected(_on_recovery_systems_initialized):
				client.recovery_systems_initialized.connect(_on_recovery_systems_initialized)
			if client.has_signal("recovery_system_updated") and not client.recovery_system_updated.is_connected(_on_recovery_system_updated):
				client.recovery_system_updated.connect(_on_recovery_system_updated)
			if client.has_signal("blackout_started") and not client.blackout_started.is_connected(_on_blackout_started):
				client.blackout_started.connect(_on_blackout_started)
			if client.has_signal("blackout_ended") and not client.blackout_ended.is_connected(_on_blackout_ended):
				client.blackout_ended.connect(_on_blackout_ended)
			if client.has_signal("game_state_changed") and not client.game_state_changed.is_connected(_on_game_state_changed):
				client.game_state_changed.connect(_on_game_state_changed)
			_is_connected_to_network = true
			
			if _is_connected_to_server():
				if client.is_blackout_active:
					visible = true
					var total = client.active_recovery_systems.size() if not client.active_recovery_systems.is_empty() else (client.required_recovery_count if client.required_recovery_count > 0 else 4)
					set_recovery_progress(client.completed_recovery_count, total)
				else:
					visible = (client.current_game_state == NetworkConfig.GameState.BLACKOUT_ACTIVE)
			else:
				visible = true

func _on_recovery_systems_initialized(required_count: int, systems: Array) -> void:
	visible = true
	var total = systems.size() if not systems.is_empty() else required_count
	set_recovery_progress(0, total)

func _on_recovery_system_updated(_system_id: String, _is_completed: bool, completed_count: int, required_count: int) -> void:
	set_recovery_progress(completed_count, required_count)

func _on_blackout_started(_duration: float) -> void:
	visible = true

func _on_blackout_ended() -> void:
	visible = false

func _on_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	if new_state == NetworkConfig.GameState.BLACKOUT_ACTIVE:
		visible = true
	elif new_state != NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION:
		visible = false

## Public API to update recovery progress (completed = X, total = Y)
func set_recovery_progress(completed: int, total: int) -> void:
	_total_count = max(1, total)
	_completed_count = clamp(completed, 0, _total_count)
	_rebuild_ui()

func get_completed_count() -> int:
	return _completed_count

func get_total_count() -> int:
	return _total_count

## Rebuilds the numeric text and the indicator pips
func _rebuild_ui() -> void:
	_ensure_node_references()
	
	if progress_label != null:
		progress_label.text = "%d / %d" % [_completed_count, _total_count]
		if _completed_count >= _total_count:
			progress_label.add_theme_color_override("font_color", COLOR_PROGRESS_DONE)
		else:
			progress_label.add_theme_color_override("font_color", COLOR_PROGRESS_PENDING)
			
	if pips_container == null:
		return
		
	for child in pips_container.get_children():
		pips_container.remove_child(child)
		child.queue_free()
		
	var all_done = (_completed_count >= _total_count)
	for i in range(_total_count):
		var is_filled = (i < _completed_count)
		var pip = _create_pip_label(is_filled, all_done)
		pips_container.add_child(pip)

## Creates a single pip indicator Label
func _create_pip_label(is_filled: bool, all_completed: bool) -> Label:
	var lbl = Label.new()
	lbl.text = "●" if is_filled else "○"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	
	var color: Color
	if is_filled:
		color = COLOR_PIP_COMPLETED_ALL if all_completed else COLOR_PIP_COMPLETED
	else:
		color = COLOR_PIP_INCOMPLETE
		
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl

func _populate_offline_preview() -> void:
	set_recovery_progress(2, 4)

func _cycle_offline_progress() -> void:
	var next_val = (_completed_count + 1) % (_total_count + 1)
	set_recovery_progress(next_val, _total_count)
